import Foundation

/// 앱의 의존성을 조립하고 앱 실행 동안 유지한다.
@MainActor
final class AppContainer {
    let apiClient: APIClient
    let tokenStore: any AuthTokenStore
    let currentUserStore: any CurrentUserStore
    let sessionEvents: SessionEvents

    init(
        configuration: APIConfiguration,
        tokenStore: any AuthTokenStore,
        currentUserStore: any CurrentUserStore,
        transport: @escaping APIClient.Transport
    ) {
        self.tokenStore = tokenStore
        self.currentUserStore = currentUserStore
        sessionEvents = SessionEvents()
        let refreshClient = APIClient(configuration: configuration, transport: transport)
        let authSession = AuthSession(
            tokenStore: tokenStore, currentUserStore: currentUserStore,
            refresher: AuthTokenRefresher(client: refreshClient), events: sessionEvents
        )
        apiClient = APIClient(configuration: configuration, authSession: authSession, transport: transport)
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
        let service = (bundle.bundleIdentifier ?? "com.moamap") + ".auth"
        self.init(
            configuration: configuration,
            tokenStore: KeychainAuthTokenStore(service: service),
            currentUserStore: KeychainCurrentUserStore(service: service)
        ) { request in
            try await session.data(for: request)
        }
    }
}
