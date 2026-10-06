import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKUser
import UIKit

/// 앱의 의존성을 조립하고 앱 실행 동안 유지한다.
@MainActor
final class AppContainer {
    let apiClient: APIClient
    let tokenStore: any AuthTokenStore
    let currentUserStore: any CurrentUserStore
    let sessionEvents: SessionEvents
    let authRepository: any AuthRepository
    let exploreRepository: any ExploreRepository
    let officialMapRepository: any OfficialMapRepository
    let footTrafficRepository: any FootTrafficRepository
    let restroomRepository: any RestroomRepository
    let mapDetailRepository: any MapDetailRepository
    let personalMapRepository: any PersonalMapRepository
    let placeReviewRepository: any PlaceReviewRepository
    let placeSearchRepository: any PlaceSearchRepository
    let placeAddRepository: any PlaceAddRepository
    let mapMemberRepository: any MapMemberRepository
    let mapActivityRepository: any MapActivityRepository
    let pendingPlaceRepository: any PendingPlaceRepository
    let userRepository: any UserRepository
    let locationProvider: any LocationProvider = DeviceLocationProvider()
    let collectionRepository: any CollectionRepository
    let placeImportRepository: any PlaceImportRepository

    init(
        configuration: APIConfiguration,
        tokenStore: any AuthTokenStore,
        currentUserStore: any CurrentUserStore,
        kakaoLogin: @escaping () async throws -> String = { throw LoginError.notConfigured },
        appleLogin: @escaping (String) async throws -> AppleLoginCredential = { _ in throw LoginError.notConfigured },
        kakaoLogout: @escaping () async throws -> Void = {},
        kakaoRestAPIKey: String = "",
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
        // 로그인 경로는 APIClient 가 인증 헤더를 붙이지 않는다. 로그아웃은 인증이 필요하다.
        authRepository = AuthRepositoryImpl(
            client: apiClient, kakaoLogin: kakaoLogin, appleLogin: appleLogin, kakaoLogout: kakaoLogout,
            tokenStore: tokenStore, currentUserStore: currentUserStore
        )
        exploreRepository = ExploreRepositoryImpl(client: apiClient)
        officialMapRepository = OfficialMapRepositoryImpl(client: apiClient)
        footTrafficRepository = FootTrafficRepositoryImpl(client: apiClient)
        restroomRepository = RestroomRepositoryImpl(client: apiClient)
        collectionRepository = CollectionRepositoryImpl(client: apiClient, uploader: PresignedImageUploader(transport: transport))
        mapDetailRepository = MapDetailRepositoryImpl(client: apiClient)
        personalMapRepository = PersonalMapRepositoryImpl(client: apiClient)
        mapMemberRepository = MapMemberRepositoryImpl(client: apiClient)
        mapActivityRepository = MapActivityRepositoryImpl(client: apiClient, timeZone: .current)
        pendingPlaceRepository = PendingPlaceRepositoryImpl(client: apiClient, timeZone: .current)
        placeAddRepository = PlaceAddRepositoryImpl(client: apiClient, uploader: PresignedImageUploader(transport: transport))
        placeImportRepository = PlaceImportRepositoryImpl(
            client: apiClient,
            captionExtractor: InstagramCaptionExtractor(transport: transport),
            photoUploader: placeAddRepository
        )
        // 카카오 로컬 API 는 우리 서버 인증을 붙이지 않는다.
        let kakaoLocalClient = APIClient(configuration: Self.kakaoLocalConfiguration, transport: transport)
        placeSearchRepository = KakaoPlaceSearchRepository(client: kakaoLocalClient, restAPIKey: kakaoRestAPIKey)
        placeReviewRepository = PlaceReviewRepositoryImpl(
            client: apiClient, uploader: PresignedImageUploader(transport: transport), timeZone: .current
        )
        userRepository = UserRepositoryImpl(client: apiClient, uploader: PresignedImageUploader(transport: transport))
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
        let restAPIKey = (bundle.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
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
        let appleClient = AppleAuthClient {
            guard let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .filter({ $0.activationState == .foregroundActive })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) else { throw LoginError.notConfigured }
            return SystemAppleAuthorizationSession(anchor: window)
        }
        self.init(
            configuration: configuration,
            tokenStore: KeychainAuthTokenStore(service: service),
            currentUserStore: KeychainCurrentUserStore(service: service),
            kakaoLogin: {
                guard isConfigured else { throw LoginError.notConfigured }
                return try await kakaoClient.login()
            },
            appleLogin: { nonce in try await appleClient.login(nonce: nonce) },
            kakaoLogout: {
                guard isConfigured else { return }
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    UserApi.shared.logout { error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
            },
            kakaoRestAPIKey: restAPIKey
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

    func makeCommunityMapListViewModel() -> CommunityMapListViewModel {
        CommunityMapListViewModel(repository: exploreRepository)
    }

    func makeOfficialMapListViewModel() -> OfficialMapListViewModel {
        OfficialMapListViewModel(repository: officialMapRepository)
    }

    func makeDensityMapViewModel() -> DensityMapViewModel {
        DensityMapViewModel(repository: footTrafficRepository)
    }

    func makeRestroomMapViewModel() -> RestroomMapViewModel {
        RestroomMapViewModel(repository: restroomRepository)
    }

    func makeMapIntroViewModel(mapID: Int64) -> MapIntroViewModel {
        MapIntroViewModel(mapID: mapID, repository: mapDetailRepository)
    }

    /// 참여·나가기만 하는 공식지도 전용 화면용. 지도 상세의 다른 ViewModel 은 만들지 않는다.
    func makeMapMembershipViewModel(mapID: Int64) -> MapDetailViewModel {
        MapDetailViewModel(mapID: mapID, repository: mapDetailRepository)
    }

    func makeMapDetailViewModels(mapID: Int64) -> MapDetailViewModels {
        MapDetailViewModels(
            main: MapDetailViewModel(mapID: mapID, repository: mapDetailRepository),
            personalMap: PersonalMapAddViewModel(repository: personalMapRepository),
            review: PlaceReviewViewModel(repository: placeReviewRepository, currentUserStore: currentUserStore, now: Date.init),
            addPlace: AddPlaceViewModel(
                mapID: mapID, searchRepository: placeSearchRepository, addRepository: placeAddRepository,
                sleep: { try await Task.sleep(for: $0) }
            ),
            member: MemberViewModel(mapID: mapID, repository: mapMemberRepository),
            activity: MapActivityViewModel(mapID: mapID, repository: mapActivityRepository, now: Date.init),
            pending: PendingRequestViewModel(mapID: mapID, repository: pendingPlaceRepository)
        )
    }

    func makeCollectionViewModel() -> CollectionViewModel {
        CollectionViewModel(repository: collectionRepository)
    }

    func makeCreateMapViewModel() -> CreateMapViewModel {
        CreateMapViewModel(repository: collectionRepository)
    }

    func makeProfileEditViewModel() -> ProfileEditViewModel {
        ProfileEditViewModel(repository: userRepository)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(repository: authRepository)
    }

    func handleOpenURL(_ url: URL) {
        if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
        }
    }

    // 고정 주소라 실패할 수 없다.
    private static let kakaoLocalConfiguration = try! APIConfiguration(infoDictionary: ["BASE_URL": "https://dapi.kakao.com/"])

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
