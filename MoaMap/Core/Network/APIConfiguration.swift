import Foundation

/// Info.plist에 주입된 서버 주소를 검증한다. 번들 선택은 앱 조립부에서 담당한다.
nonisolated struct APIConfiguration: Sendable {
    let baseURL: URL

    enum ConfigurationError: Error, Equatable {
        case missingBaseURL
        case invalidBaseURL
    }

    init(bundle: Bundle) throws {
        try self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) throws {
        guard let rawValue = infoDictionary["BASE_URL"] else {
            throw ConfigurationError.missingBaseURL
        }
        guard let value = rawValue as? String else {
            throw ConfigurationError.invalidBaseURL
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ConfigurationError.missingBaseURL
        }
        guard !trimmed.contains("$("),
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.port.map({ (1...65535).contains($0) }) ?? true,
              let url = components.url else {
            throw ConfigurationError.invalidBaseURL
        }
        baseURL = url
    }
}
