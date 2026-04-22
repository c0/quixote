import Foundation
import Security

enum KeychainAccessError: LocalizedError {
    case itemNotFound
    case interactionNotAllowed
    case authenticationFailed
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "No saved API key — set one in Settings."
        case .interactionNotAllowed:
            return "Could not access saved API key while the Mac is locked. Unlock the Mac and try again."
        case .authenticationFailed:
            return "Keychain access was denied or canceled."
        case .unhandledStatus:
            return "Could not access saved API key."
        }
    }
}

enum KeychainHelper {
    private static let service = "Quixote"
    private static let openAIAccount = "com.c0.quixote.api.openai"

    static func saveOpenAIKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return }

        SecItemDelete(baseOpenAIQuery() as CFDictionary)

        var item = baseOpenAIQuery()
        item[kSecValueData] = data
        item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlocked

        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw map(status)
        }
    }

    static func readOpenAIKey() throws -> String {
        var query = baseOpenAIQuery()
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw map(status)
        }
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainAccessError.unhandledStatus(errSecDecode)
        }
        return string
    }

    static func deleteOpenAIKey() throws {
        let status = SecItemDelete(baseOpenAIQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw map(status)
        }
    }

    private static func baseOpenAIQuery() -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: openAIAccount
        ]
    }

    private static func map(_ status: OSStatus) -> KeychainAccessError {
        #if DEBUG
        if status != errSecItemNotFound {
            print("Keychain OSStatus: \(status)")
        }
        #endif

        switch status {
        case errSecItemNotFound:
            return .itemNotFound
        case errSecInteractionNotAllowed:
            return .interactionNotAllowed
        case errSecAuthFailed:
            return .authenticationFailed
        default:
            return .unhandledStatus(status)
        }
    }
}
