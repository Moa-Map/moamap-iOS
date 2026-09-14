import Foundation

/// 앱의 의존성을 조립하고 앱 실행 동안 유지한다.
@MainActor
final class AppContainer {
    let apiClient: APIClient

    init(configuration: APIConfiguration, transport: @escaping APIClient.Transport) {
        apiClient = APIClient(configuration: configuration, transport: transport)
    }

    convenience init(bundle: Bundle) throws {
        let configuration = try APIConfiguration(bundle: bundle)
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.timeoutIntervalForRequest = 15
        sessionConfiguration.timeoutIntervalForResource = 60
        sessionConfiguration.urlCache = nil
        sessionConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        sessionConfiguration.httpShouldSetCookies = false
        let session = URLSession(configuration: sessionConfiguration)
        self.init(configuration: configuration) { request in
            try await session.data(for: request)
        }
    }
}
