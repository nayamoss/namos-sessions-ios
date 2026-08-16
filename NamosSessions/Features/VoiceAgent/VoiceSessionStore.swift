import Foundation

/// Response from `voiceStatus:status`.
struct VoiceSessionAvailability: Decodable {
    let available: Bool
    let reason: String?
}

/// Response from `voice:createSession`. When `unavailable` is true, `reason` explains
/// why there is no signed URL or agent ID.
struct VoiceSessionResponse: Decodable {
    let signedUrl: String?
    /// LiveKit conversation token minted server-side by `voice:createSession`. This —
    /// not `signedUrl` — is what the Swift SDK needs for hands-free voice; see the note
    /// at the bottom of this file.
    let conversationToken: String?
    let agentId: String?
    let unavailable: Bool?
    let reason: String?
}

/// Thin Convex plumbing for the ElevenLabs conversation bootstrap flow.
@MainActor
final class VoiceSessionStore {
    func availability(for eventId: ConvexId) async throws -> VoiceSessionAvailability {
        do {
            let response: VoiceSessionAvailability = try await ConvexClient.shared.query("voiceStatus:status", args: [
                "eventId": eventId,
            ])
            print("[VoiceSessionStore] voiceStatus:status response: available=\(response.available), reason=\(response.reason ?? "nil")")
            return response
        } catch {
            print("[VoiceSessionStore] voiceStatus:status failed: \(String(reflecting: error))")
            throw error
        }
    }

    func createSession(for eventId: ConvexId) async throws -> VoiceSessionResponse {
        do {
            let response: VoiceSessionResponse = try await ConvexClient.shared.action("voice:createSession", args: [
                "eventId": eventId,
            ])
            let unavailable = response.unavailable.map { $0 ? "true" : "false" } ?? "nil"
            // The token itself is a credential — log only whether one arrived.
            let hasToken = response.conversationToken.map { !$0.isEmpty } ?? false
            print("[VoiceSessionStore] voice:createSession response: signedUrl=\(response.signedUrl ?? "nil"), conversationToken=\(hasToken ? "present" : "missing"), agentId=\(response.agentId ?? "nil"), unavailable=\(unavailable), reason=\(response.reason ?? "nil")")
            return response
        } catch {
            print("[VoiceSessionStore] voice:createSession failed: \(String(reflecting: error))")
            throw error
        }
    }
}

// Why this flow uses a conversation token and not the signed URL
// ---------------------------------------------------------------
// Verified directly against the installed ElevenLabs Swift SDK 3.2.2 source, not docs:
//
//   TokenService.fetchConnectionDetails(configuration:)
//     case .signedWebSocketURL:
//       throw ConversationError.authenticationFailed(
//         "Signed WebSocket URLs are only supported for text-only conversations.")
//
// Voice conversations in this SDK run over LiveKit WebRTC (wss://livekit.rtc.elevenlabs.io),
// which authenticates with a LiveKit JWT — the room and participant identity are encoded
// in the token itself. A signed WebSocket URL carries none of that, so it is rejected
// during token resolution before any network call is made. That rejection, not a network
// or ATS problem, was the "WebSocket connection failure."
//
// `startConversation(signedWebSocketURL:)` is not an alternative either: that convenience
// overload forces `textOnly = true`, which defeats a hands-free UI.
//
// So `voice:createSession` mints the token server-side from
// GET https://api.elevenlabs.io/v1/convai/conversation/token?agent_id=… (returns
// {"token", "conversation_id"}) and this client passes it to
// `ElevenLabs.startConversation(conversationToken:config:)`. ELEVENLABS_API_KEY stays in
// the Convex environment and never reaches the device.
