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
            print("[VoiceSessionStore] voice:createSession response: signedUrl=\(response.signedUrl ?? "nil"), agentId=\(response.agentId ?? "nil"), unavailable=\(unavailable), reason=\(response.reason ?? "nil")")
            return response
        } catch {
            print("[VoiceSessionStore] voice:createSession failed: \(String(reflecting: error))")
            throw error
        }
    }
}

// ElevenLabs Swift SDK 3.2.2 advanced signed-URL entry point (verified in source):
//
// let auth = try ElevenLabsConfiguration.signedWebSocketURL(response.signedUrl)
// let conversation = try await ElevenLabs.startConversation(auth: auth, config: .init())
//
// `config: .init()` retains the default voice mode. The SDK's
// `startConversation(signedWebSocketURL:)` convenience overload explicitly forces
// `textOnly = true`, so it is not a valid replacement for this hands-free UI. Note that
// SDK 3.2.2's voice startup rejects signed WebSocket URLs during token resolution;
// connection failures are intentionally logged by VoiceConversationView until the
// backend can provide the voice conversation token that this SDK requires.
