import Foundation

/// Talks to the SAME Convex deployment the web app talks to — no new backend, no new
/// API surface. Convex's documented HTTP API (POST /api/query, /api/mutation, /api/action
/// on the deployment's .convex.cloud origin) is used directly rather than the unofficial
/// convex-swift client, so this scaffold has zero unverified SPM dependencies in the
/// data path. Swapping in convex-swift later for live (WebSocket) subscriptions is a
/// drop-in upgrade — the function names and args below don't change.
///
/// Every call is authenticated with the same Clerk "convex" JWT the web app uses, so it
/// hits the identical `assertEventOrganizerAccess` / `isEventOrganizer` checks defined in
/// convex/functions.ts. There is no separate mobile authorization path to build or audit.
enum ConvexError: Error, LocalizedError {
    case notConfigured
    case notAuthenticated
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "ConvexBaseURL is missing from build settings."
        case .notAuthenticated: return "Sign in to continue."
        case .server(let message): return message
        case .decoding: return "Couldn't read the server's response."
        }
    }
}

@MainActor
final class ConvexClient {
    static let shared = ConvexClient()

    private let baseURL: URL?
    private let session = URLSession(configuration: .default)

    private init() {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "ConvexBaseURL") as? String,
           let url = URL(string: raw), !raw.isEmpty {
            baseURL = url
        } else {
            baseURL = nil
            print("⚠️ ConvexBaseURL missing or empty — set CONVEX_BASE_URL in build settings.")
        }
    }

    /// Calls a Convex query function, e.g. "tasks:listForEvent".
    func query<T: Decodable>(_ path: String, args: [String: Any] = [:]) async throws -> T {
        try await call(kind: "query", path: path, args: args)
    }

    /// Calls a Convex mutation function, e.g. "tasks:update".
    func mutation<T: Decodable>(_ path: String, args: [String: Any] = [:]) async throws -> T {
        try await call(kind: "mutation", path: path, args: args)
    }

    /// Calls a Convex action function, e.g. "agentRuns:start" — used for anything that
    /// itself calls out to the agent runtime (convex/agentRuntime.ts, agentWorkflow.ts).
    func action<T: Decodable>(_ path: String, args: [String: Any] = [:]) async throws -> T {
        try await call(kind: "action", path: path, args: args)
    }

    private func call<T: Decodable>(kind: String, path: String, args: [String: Any]) async throws -> T {
        guard let baseURL else { throw ConvexError.notConfigured }
        guard let token = try await ClerkAuthManager.shared.convexAuthToken() else {
            throw ConvexError.notAuthenticated
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("api/\(kind)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "path": path,
            "args": args,
            "format": "json",
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ConvexErrorBody.self, from: data))?.errorMessage
            throw ConvexError.server(message ?? "Convex returned an unexpected status.")
        }

        let envelope = try JSONDecoder().decode(ConvexEnvelope<T>.self, from: data)
        switch envelope.status {
        case "success":
            guard let value = envelope.value else { throw ConvexError.decoding }
            return value
        default:
            throw ConvexError.server(envelope.errorMessage ?? "Convex call failed.")
        }
    }
}

private struct ConvexEnvelope<T: Decodable>: Decodable {
    let status: String
    let value: T?
    let errorMessage: String?
}

private struct ConvexErrorBody: Decodable {
    let errorMessage: String?
}
