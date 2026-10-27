import Foundation
import GoogleSignIn
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
    let mapPostRepository: any MapPostRepository
    let mapPostCommentRepository: any MapPostCommentRepository
    let userRepository: any UserRepository
    let termsRepository: any TermsRepository
    let noticeRepository: any NoticeRepository
    let inquiryRepository: any InquiryRepository
    let reportRepository: any ReportRepository
    let blockRepository: any BlockRepository
    let blockedUserStore: BlockedUserStore
    let locationProvider: any LocationProvider = DeviceLocationProvider()
    let collectionRepository: any CollectionRepository
    let placeImportRepository: any PlaceImportRepository
    let sharedLinkInbox = SharedLinkInbox()

    init(
        configuration: APIConfiguration,
        tokenStore: any AuthTokenStore,
        currentUserStore: any CurrentUserStore,
        loginProviderStore: any LoginProviderStore,
        kakaoLogin: @escaping () async throws -> String = { throw LoginError.notConfigured },
        appleLogin: @escaping (String) async throws -> AppleLoginCredential = { _ in throw LoginError.notConfigured },
        googleLogin: @escaping () async throws -> String = { throw LoginError.notConfigured },
        kakaoLogout: @escaping () async throws -> Void = {},
        kakaoUnlink: @escaping () async throws -> Void = {},
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
            client: apiClient, kakaoLogin: kakaoLogin, appleLogin: appleLogin, googleLogin: googleLogin,
            kakaoLogout: kakaoLogout, kakaoUnlink: kakaoUnlink,
            tokenStore: tokenStore, currentUserStore: currentUserStore,
            loginProviderStore: loginProviderStore
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
        mapPostRepository = MapPostRepositoryImpl(
            client: apiClient, uploader: PresignedImageUploader(transport: transport), timeZone: .current
        )
        mapPostCommentRepository = MapPostCommentRepositoryImpl(client: apiClient, timeZone: .current)
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
        termsRepository = TermsRepositoryImpl(client: apiClient)
        noticeRepository = NoticeRepositoryImpl(client: apiClient)
        inquiryRepository = InquiryRepositoryImpl(client: apiClient)
        reportRepository = ReportRepositoryImpl(client: apiClient)
        blockRepository = BlockRepositoryImpl(client: apiClient)
        blockedUserStore = BlockedUserStore(repository: blockRepository)
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
            },
            unlink: { completion in
                UserApi.shared.unlink { error in completion(Self.kakaoUnlinkResult(error: error)) }
            }
        )
        let appleClient = AppleAuthClient {
            guard let window = Self.keyWindow() else { throw LoginError.notConfigured }
            return SystemAppleAuthorizationSession(anchor: window)
        }
        let googleClientID = (bundle.object(forInfoDictionaryKey: "GOOGLE_CLIENT_ID") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // URL Scheme 이 빠진 채 로그인을 시작하면 SDK 가 앱을 멈춘다. 둘 다 있어야 켠다.
        let isGoogleConfigured = !googleClientID.isEmpty && !googleClientID.contains("$(")
            && Self.urlSchemes(in: bundle).contains(Self.googleURLScheme(clientID: googleClientID))
        if isGoogleConfigured {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: googleClientID)
        }
        self.init(
            configuration: configuration,
            tokenStore: KeychainAuthTokenStore(service: service),
            currentUserStore: KeychainCurrentUserStore(service: service),
            loginProviderStore: KeychainLoginProviderStore(service: service),
            kakaoLogin: {
                guard isConfigured else { throw LoginError.notConfigured }
                return try await kakaoClient.login()
            },
            appleLogin: { nonce in try await appleClient.login(nonce: nonce) },
            googleLogin: {
                guard isGoogleConfigured,
                      let presenter = Self.keyWindow()?.rootViewController else { throw LoginError.notConfigured }
                return try await Self.googleIDToken(presenting: presenter)
            },
            kakaoLogout: {
                guard isConfigured else { return }
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                    UserApi.shared.logout { error in
                        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                    }
                }
            },
            kakaoUnlink: {
                guard isConfigured else { return }
                try await kakaoClient.unlink()
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
        ExploreViewModel(repository: exploreRepository, officialMapRepository: officialMapRepository)
    }

    func makeCommunityMapListViewModel() -> CommunityMapListViewModel {
        CommunityMapListViewModel(repository: exploreRepository, sleep: { try await Task.sleep(for: $0) })
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
            member: MemberViewModel(mapID: mapID, repository: mapMemberRepository, currentUserStore: currentUserStore),
            activity: MapActivityViewModel(mapID: mapID, repository: mapActivityRepository, now: Date.init),
            pending: PendingRequestViewModel(mapID: mapID, repository: pendingPlaceRepository),
            posts: MapPostListViewModel(mapID: mapID, repository: mapPostRepository),
            postCalendar: MapPostCalendarViewModel(mapID: mapID, repository: mapPostRepository, timeZone: .current, now: Date.init),
            postCreate: MapPostCreateViewModel(mapID: mapID, repository: mapPostRepository),
            postDetail: MapPostDetailViewModel(
                mapID: mapID, repository: mapPostCommentRepository, currentUserStore: currentUserStore
            ),
            reviewModeration: makeModerationViewModel(),
            postModeration: makeModerationViewModel(),
            makeEditMap: makeEditMapViewModel(map:)
        )
    }

    func makeModerationViewModel() -> ModerationViewModel {
        ModerationViewModel(reportRepository: reportRepository, blockedUsers: blockedUserStore)
    }

    func makeCollectionViewModel() -> CollectionViewModel {
        CollectionViewModel(repository: collectionRepository, mapRepository: mapDetailRepository)
    }

    func makeCreateMapViewModel() -> CreateMapViewModel {
        CreateMapViewModel(repository: collectionRepository, importRepository: placeImportRepository)
    }

    func makeEditMapViewModel(map: MapDetail) -> EditMapViewModel {
        EditMapViewModel(map: map, repository: collectionRepository)
    }

    func makePlaceImportViewModel(source: PlaceImportSource, url: String) -> PlaceImportViewModel {
        PlaceImportViewModel(source: source, url: url, importRepository: placeImportRepository, collectionRepository: collectionRepository)
    }

    func makeProfileEditViewModel() -> ProfileEditViewModel {
        ProfileEditViewModel(repository: userRepository)
    }

    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(repository: authRepository, termsRepository: termsRepository)
    }

    func makeNoticeListViewModel() -> NoticeListViewModel {
        NoticeListViewModel(repository: noticeRepository, timeZone: .current)
    }

    func makeNoticeDetailViewModel(noticeID: Int64) -> NoticeDetailViewModel {
        NoticeDetailViewModel(noticeID: noticeID, repository: noticeRepository, timeZone: .current)
    }

    func makeInquiryViewModel() -> InquiryViewModel {
        InquiryViewModel(repository: inquiryRepository, userRepository: userRepository)
    }

    func makeTermsGateViewModel() -> TermsGateViewModel {
        TermsGateViewModel(repository: termsRepository, authRepository: authRepository)
    }

    func makeTermsAgreementViewModel() -> TermsAgreementViewModel {
        TermsAgreementViewModel(repository: termsRepository, authRepository: authRepository)
    }

    func makeTermDetailViewModel(termID: Int64) -> TermDetailViewModel {
        TermDetailViewModel(termID: termID, repository: termsRepository)
    }

    func handleOpenURL(_ url: URL) {
        if sharedLinkInbox.receive(url) { return }
        if AuthApi.isKakaoTalkLoginUrl(url) {
            _ = AuthController.handleOpenUrl(url: url)
            return
        }
        _ = GIDSignIn.sharedInstance.handle(url)
    }

    // 고정 주소라 실패할 수 없다.
    private static let kakaoLocalConfiguration = try! APIConfiguration(infoDictionary: ["BASE_URL": "https://dapi.kakao.com/"])

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }

    private static func urlSchemes(in bundle: Bundle) -> [String] {
        let types = bundle.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return types.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }
    }

    /// 구글 콜백 주소는 클라이언트 ID 를 점 단위로 뒤집은 것이다.
    private static func googleURLScheme(clientID: String) -> String {
        clientID.split(separator: ".").reversed().joined(separator: ".")
    }

    /// ID 토큰만 서버에 넘기고 구글 로그인 상태는 남기지 않는다. 다음 로그인 때 계정을 다시 고른다.
    private static func googleIDToken(presenting presenter: UIViewController) async throws -> String {
        // 시트가 떠 있으면 맨 위 화면에서 띄워야 한다.
        var top = presenter
        while let presented = top.presentedViewController { top = presented }
        let result: GIDSignInResult
        do {
            result = try await GIDSignIn.sharedInstance.signIn(withPresenting: top)
        } catch let error as NSError
            where error.domain == kGIDSignInErrorDomain && error.code == GIDSignInError.canceled.rawValue {
            throw LoginError.cancelled
        }
        GIDSignIn.sharedInstance.signOut()
        guard let idToken = result.user.idToken?.tokenString, !idToken.isEmpty else { throw LoginError.invalidResponse }
        return idToken
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

    /// 토큰 없음·토큰 무효·이 앱에 연결되지 않은 사용자는 끊을 연결이 없는 것으로 본다.
    private nonisolated static func kakaoUnlinkResult(error: (any Error)?) -> Result<Void, any Error> {
        guard let error else { return .success(()) }
        if let sdkError = error as? SdkError {
            if sdkError.isClientFailed, sdkError.getClientError().reason == .TokenNotFound {
                return .failure(KakaoUnlinkError.alreadyUnlinked)
            }
            if sdkError.isApiFailed, [.InvalidAccessToken, .NotSignedUpUser].contains(sdkError.getApiError().reason) {
                return .failure(KakaoUnlinkError.alreadyUnlinked)
            }
        }
        return .failure(error)
    }
}
