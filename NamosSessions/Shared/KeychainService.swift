import Foundation
import Security

class KeychainService {
    static let shared = KeychainService()

    private let service = "com.namos.sessions"
    
    private init() {}
    
    // MARK: - Save
    
    func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        
        // Delete any existing item first
        delete(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    // MARK: - Retrieve
    
    func retrieve(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    // MARK: - Delete
    
    @discardableResult
    func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Convenience Keys
    
    enum Key: String {
        // Clerk manages its own session storage internally via the SDK.
        // Reserved for any additional Clerk-related values if needed.
        case clerkSessionToken = "clerk_session_token"
        // Cached Convex auth token (short-lived Clerk "convex" JWT template),
        // refreshed by ConvexClient — never a long-lived secret.
        case convexAuthToken = "convex_auth_token"
        case lastSelectedEventId = "last_selected_event_id"
    }

    @discardableResult
    func saveLastSelectedEventId(_ id: String) -> Bool {
        save(key: Key.lastSelectedEventId.rawValue, value: id)
    }

    func getLastSelectedEventId() -> String? {
        retrieve(key: Key.lastSelectedEventId.rawValue)
    }
}
