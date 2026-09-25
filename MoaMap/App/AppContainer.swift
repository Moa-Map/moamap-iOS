import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser

/// 앱의 의존성을 조립하고 앱 실행 동안 유지한다.
@MainActor
final class AppContainer {
    let apiClient: APIClient
    let tokenStore: any AuthTokenStore
    let currentUserStore: any CurrentUserStore
    let sessionEvents: SessionEvents
    let authRepository: any AuthRepository
    let exploreRepository: any ExploreRepository

    init(
        configuration: APIConfiguration,
        tokenStore: any AuthTokenStore,
        currentUserStore: any CurrentUserStore,
        kakaoLogin: @escaping () async throws -> String = { throw LoginError.notConfigured },
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
        authRepository = AuthRepositoryImpl(
            client: refreshClient, kakaoLogin: kakaoLogin,
            tokenStore: tokenStore, currentUserStore: currentUserStore
        )
        exploreRepository = ExploreRepositoryImpl(client: apiClient)
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
        let appKey = (bundle.object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isConfigured = !appKey.isEmpty && !appKey.contains("$(")
        if isConfigured { KakaoSDK.initSDK(appKey: appKey) }
        let kakaoClient = KakaoAuthClient(
            isTalkAvailable: { UserApi.isKakaoTalkLoginAvailable() },
            talkLogin: { completion in
                UserApi.shared.loginWithKakaoTalk(launchMethod: .CustomScheme) { token, error in
                    completion(Self.kakaoResult(accessToken: token?.accessToken, error: error))
                }
            },
            accountLogin: { completion in
                UserApi.shared.loginWithKakaoAccount { token, error in
                    completion(Self.kakaoResult(accessToken: token?.accessToken, error: error))
                }
            }
        )
        self.init(
            configuration: configuration,
            tokenStore: KeychainAuthTokenStore(service: service),
            currentUserStore: KeychainCurrentUserStore(service: service),
            kakaoLogin: {
                guard isConfigured else { throw LoginError.notConfigured }
                return try await kakaoClient.login()
            }
        ) { request in
            try await session.data(for: request)
        }
    }

    func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(repository: authRepository)
    }

    func makeExploreViewModel() -> ExploreViewModel {
        ExploreViewModel(repository: exploreRepository)
    }

    func handleOpenURL(_ url: URL) {
        if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
        }
    }

    private nonisolated static func kakaoResult(accessToken: String?, error: (any Error)?) -> Result<String, any Error> {
        if let error {
            if let sdkError = error as? SdkError,
               sdkError.isClientFailed, sdkError.getClientError().reason == .Cancelled {
                return .failure(LoginError.cancelled)
            }
            return .failure(error)
        }
        guard let accessToken, !accessToken.isEmpty else { return .failure(LoginError.invalidResponse) }
        return .success(accessToken)
    }
}
