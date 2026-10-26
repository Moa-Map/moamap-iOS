import CoreLocation
import SwiftUI

private enum MainRoute: Hashable {
    case profileEdit
    case settings
    case termDetail(id: Int64, title: String)
    case mapAttribution
    case notices
    case noticeDetail(id: Int64)
    case inquiry
    case communityMaps
    case officialMaps
    case createMap
    case placeImport(PlaceImportStep)
    case mapIntro(mapID: Int64)
    case mapDetail(mapID: Int64, title: String)
    /// 장소 대신 전용 지도를 보여 주는 공식지도.
    case densityMap(mapID: Int64, title: String)
    case restroomMap(mapID: Int64, title: String)
}

struct MainTabView: View {
    @Environment(\.moaColors) private var colors
    @State private var selection: MainTab = .explore
    @State private var exploreViewModel: ExploreViewModel
    @State private var explorePath: [MainRoute] = []

    @State private var collectionViewModel: CollectionViewModel
    @State private var collectionPath: [MainRoute] = []
    /// 장소 가져오기 단계들이 함께 쓴다. 흐름을 벗어나면 비워 다음에 들어올 때 이전 입력이 남지 않는다.
    @State private var placeImportViewModel: PlaceImportViewModel?
    /// 새 지도 만들기에서 들어온 가져오기면 편집 결과를 받을 곳.
    @State private var placeImportHandOff: (([EditedPlace]) -> Void)?

    private let makeSettingsViewModel: () -> SettingsViewModel
    private let makeTermDetailViewModel: (Int64) -> TermDetailViewModel
    private let makeNoticeListViewModel: () -> NoticeListViewModel
    private let makeNoticeDetailViewModel: (Int64) -> NoticeDetailViewModel
    private let makeInquiryViewModel: () -> InquiryViewModel
    private let makeProfileEditViewModel: () -> ProfileEditViewModel
    private let makeCreateMapViewModel: () -> CreateMapViewModel
    private let makePlaceImportViewModel: (PlaceImportSource, String) -> PlaceImportViewModel
    private let sharedLinkInbox: SharedLinkInbox
    @State private var collectionNotice: String?
    /// 프라이빗 지도를 만들고 모음 탭으로 돌아와 띄우는 초대 코드 팝업. 장소 안내는 팝업을 닫은 뒤 보여준다.
    @State private var createdMapInvite: CreatedMapInvite?
    @State private var noticeAfterInvite: String?
    /// 스낵바가 하단 탭을 피해 뜨도록 잰다.
    @State private var bottomBarHeight: CGFloat = 0
    /// 하단 탭을 눌러 탭을 바꿨을 때 직전 탭. 새 탭의 하단 탭이 여기서 미끄러져 온다.
    @State private var bottomBarSlideFrom: MainTab?
    private let makeCommunityMapListViewModel: () -> CommunityMapListViewModel
    private let makeOfficialMapListViewModel: () -> OfficialMapListViewModel
    private let makeDensityMapViewModel: () -> DensityMapViewModel
    private let makeRestroomMapViewModel: () -> RestroomMapViewModel
    private let makeMapIntroViewModel: (Int64) -> MapIntroViewModel
    private let makeMapDetailViewModels: (Int64) -> MapDetailViewModels
    private let makeMapMembershipViewModel: (Int64) -> MapDetailViewModel
    private let locationProvider: any LocationProvider
    private let onLoggedOut: () -> Void

    init(
        exploreViewModel: ExploreViewModel,
        collectionViewModel: CollectionViewModel,
        makeSettingsViewModel: @escaping () -> SettingsViewModel,
        makeTermDetailViewModel: @escaping (Int64) -> TermDetailViewModel,
        makeNoticeListViewModel: @escaping () -> NoticeListViewModel,
        makeNoticeDetailViewModel: @escaping (Int64) -> NoticeDetailViewModel,
        makeInquiryViewModel: @escaping () -> InquiryViewModel,
        makeProfileEditViewModel: @escaping () -> ProfileEditViewModel,
        makeCreateMapViewModel: @escaping () -> CreateMapViewModel,
        makePlaceImportViewModel: @escaping (PlaceImportSource, String) -> PlaceImportViewModel,
        makeCommunityMapListViewModel: @escaping () -> CommunityMapListViewModel,
        makeOfficialMapListViewModel: @escaping () -> OfficialMapListViewModel,
        makeDensityMapViewModel: @escaping () -> DensityMapViewModel,
        makeRestroomMapViewModel: @escaping () -> RestroomMapViewModel,
        makeMapIntroViewModel: @escaping (Int64) -> MapIntroViewModel,
        makeMapDetailViewModels: @escaping (Int64) -> MapDetailViewModels,
        makeMapMembershipViewModel: @escaping (Int64) -> MapDetailViewModel,
        sharedLinkInbox: SharedLinkInbox,
        locationProvider: any LocationProvider,
        onLoggedOut: @escaping () -> Void
    ) {
        _collectionViewModel = State(initialValue: collectionViewModel)
        _exploreViewModel = State(initialValue: exploreViewModel)
        self.makeSettingsViewModel = makeSettingsViewModel
        self.makeTermDetailViewModel = makeTermDetailViewModel
        self.makeNoticeListViewModel = makeNoticeListViewModel
        self.makeNoticeDetailViewModel = makeNoticeDetailViewModel
        self.makeInquiryViewModel = makeInquiryViewModel
        self.makeProfileEditViewModel = makeProfileEditViewModel
        self.makeCreateMapViewModel = makeCreateMapViewModel
        self.makePlaceImportViewModel = makePlaceImportViewModel
        self.makeCommunityMapListViewModel = makeCommunityMapListViewModel
        self.makeOfficialMapListViewModel = makeOfficialMapListViewModel
        self.makeDensityMapViewModel = makeDensityMapViewModel
        self.makeRestroomMapViewModel = makeRestroomMapViewModel
        self.makeMapIntroViewModel = makeMapIntroViewModel
        self.makeMapDetailViewModels = makeMapDetailViewModels
        self.makeMapMembershipViewModel = makeMapMembershipViewModel
        self.sharedLinkInbox = sharedLinkInbox
        self.locationProvider = locationProvider
        self.onLoggedOut = onLoggedOut
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $explorePath) {
                ExploreView(
                    viewModel: exploreViewModel,
                    onProfileClick: { explorePath.append(.profileEdit) },
                    onSettingsClick: { explorePath.append(.settings) },
                    onSeeAllCommunityMapsClick: { explorePath.append(.communityMaps) },
                    onSeeAllOfficialMapsClick: { explorePath.append(.officialMaps) },
                    onMapClick: { explorePath.append(.map($0)) },
                    onOfficialMapClick: { explorePath.append(.map($0)) }
                )
                .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
                // 하단 탭이 키보드를 따라 올라오지 않게 한다. 하위 화면은 입력창이 키보드를 피해야 해 첫 화면에만 둔다.
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .navigationDestination(for: MainRoute.self) { destination($0, path: $explorePath) }
            }
            .tag(MainTab.explore)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack(path: $collectionPath) {
                CollectionView(
                    viewModel: collectionViewModel,
                    onHome: { selection = .explore },
                    onCreateMap: { collectionPath.append(.createMap) },
                    onImportPlaces: { startPlaceImport($0) },
                    // 모음에는 참여한 지도만 있어 소개를 건너뛴다.
                    onMapClick: { collectionPath.append(.detail(id: $0.id, title: $0.title, official: $0.official)) }
                )
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    // 편집 중에는 편집 바가 대신 뜬다.
                    if collectionViewModel.uiState.editing == nil { bottomBar }
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
                .navigationDestination(for: MainRoute.self) { destination($0, path: $collectionPath) }
            }
            .tag(MainTab.collection)
            .toolbar(.hidden, for: .tabBar)
        }
        // 공유·지도 생성 안내는 모음 탭에서 뜬다. 첫 화면이면 하단 탭이 탭 안쪽에 있어 그 높이만큼 올린다.
        .moaSnackbar($collectionNotice, bottomInset: showsCollectionBottomBar ? bottomBarHeight : 0)
        // 하단 탭까지 덮는다.
        .overlay {
            if let invite = createdMapInvite {
                MapInviteCodeDialog(
                    mapName: invite.mapName, inviteCode: invite.inviteCode, title: "프라이빗 지도가 만들어졌어요",
                    onDismiss: {
                        createdMapInvite = nil
                        collectionNotice = noticeAfterInvite
                        noticeAfterInvite = nil
                    }
                )
            }
        }
        // 간 탭에 하단 탭이 안 보이면 직전 탭을 비운다. 남겨 두면 나중에 첫 화면으로 돌아왔을 때 엉뚱하게 미끄러진다.
        .onChange(of: selection) {
            if !showsBottomBar { bottomBarSlideFrom = nil }
        }
        .onChange(of: collectionPath) { _, path in
            if !path.contains(where: \.isPlaceImport) {
                placeImportViewModel = nil
                placeImportHandOff = nil
            }
        }
        // 처음 뜰 때도 본다. 로그인 전에 받은 공유가 여기서 처리된다.
        .onChange(of: sharedLinkInbox.pending, initial: true) {
            if let link = sharedLinkInbox.take() { handleShare(link) }
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }

    /// 보고 있는 탭이 첫 화면인지. 하단 탭은 탭마다 첫 화면에 붙는다.
    private var isRoot: Bool { selection == .explore ? explorePath.isEmpty : collectionPath.isEmpty }

    /// 보고 있는 탭에 하단 탭이 보이는지. 모음 탭은 편집 중이면 편집 바가 대신 뜬다.
    private var showsBottomBar: Bool {
        isRoot && !(selection == .collection && collectionViewModel.uiState.editing != nil)
    }

    private var showsCollectionBottomBar: Bool {
        selection == .collection && collectionPath.isEmpty && collectionViewModel.uiState.editing == nil
    }

    /// 각 탭의 첫 화면에 붙인다. `TabView` 바깥에 붙이면 탭 안 스크롤 영역이 하단 탭 높이를 몰라
    /// 마지막 카드가 하단 탭 뒤에 깔린다. 하위 화면으로 가면 첫 화면과 함께 가려진다.
    private var bottomBar: some View {
        MoaMapBottomBar(selection: $selection, slideFrom: $bottomBarSlideFrom)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomBarHeight = $0 }
    }

    private func startPlaceImport(_ source: PlaceImportSource, url: String = "") {
        let viewModel = makePlaceImportViewModel(source, url)
        viewModel.loadTargetMaps()
        placeImportViewModel = viewModel
        placeImportHandOff = nil
        collectionPath.append(.placeImport(.url))
    }

    /// 지도 선택 없이 편집 결과를 새 지도 만들기로 돌려준다.
    private func startNewMapPlaceImport(path: Binding<[MainRoute]>, handOff: @escaping ([EditedPlace]) -> Void) {
        placeImportViewModel = makePlaceImportViewModel(.mapShare, "")
        placeImportHandOff = handOff
        path.wrappedValue.append(.placeImport(.url))
    }

    /// 보던 화면과 진행 중이던 가져오기는 버리고 새 링크로 시작한다.
    private func handleShare(_ link: SharedLink) {
        explorePath = []
        selection = .collection
        switch link {
        case .supported(let url, let source):
            collectionPath = []
            startPlaceImport(source, url: url)
        case .unsupported:
            collectionNotice = SharedLinkParser.unsupportedMessage
        }
    }

    private func placeImportNavigator(_ path: Binding<[MainRoute]>) -> PlaceImportNavigator {
        PlaceImportNavigator(
            steps: { path.wrappedValue.compactMap(\.placeImportStep) },
            // 흐름의 단계는 늘 스택 맨 위에 이어 쌓여 있다.
            setSteps: { steps in
                path.wrappedValue = path.wrappedValue.filter { !$0.isPlaceImport } + steps.map(MainRoute.placeImport)
            },
            handOff: placeImportHandOff,
            onSaved: { collectionNotice = $0 }
        )
    }

    @ViewBuilder
    private func destination(_ route: MainRoute, path: Binding<[MainRoute]>) -> some View {
        switch route {
        case .profileEdit:
            ProfileEditView(viewModel: makeProfileEditViewModel()) { _ in }
        case .settings:
            SettingsView(
                viewModel: makeSettingsViewModel(),
                onOpenNotices: { path.wrappedValue.append(.notices) },
                onOpenTerm: { path.wrappedValue.append(.termDetail(id: $0.id, title: $0.title)) },
                onOpenInquiry: { path.wrappedValue.append(.inquiry) },
                onOpenMapAttribution: { path.wrappedValue.append(.mapAttribution) },
                onLoggedOut: onLoggedOut
            )
        case .termDetail(let id, let title):
            TermDetailView(viewModel: makeTermDetailViewModel(id), title: title)
        case .mapAttribution:
            MapAttributionView()
        case .notices:
            NoticeListView(viewModel: makeNoticeListViewModel()) { path.wrappedValue.append(.noticeDetail(id: $0.id)) }
        case .noticeDetail(let id):
            NoticeDetailView(viewModel: makeNoticeDetailViewModel(id))
        case .inquiry:
            InquiryView(viewModel: makeInquiryViewModel())
        case .placeImport(let step):
            if let placeImportViewModel {
                PlaceImportDestination(step: step, viewModel: placeImportViewModel, navigator: placeImportNavigator(path))
            }
        case .createMap:
            // 만들기 화면을 남기면 뒤로가기로 돌아와 같은 지도를 또 만들 수 있다.
            CreateMapView(
                viewModel: makeCreateMapViewModel(),
                onImportPlaces: { startNewMapPlaceImport(path: path, handOff: $0) },
                onCreated: { notice, invite in
                    path.wrappedValue.removeLast()
                    guard let invite else {
                        collectionNotice = notice
                        return
                    }
                    noticeAfterInvite = notice
                    // 모음 탭으로 돌아가는 전환이 끝난 뒤 띄운다.
                    Task {
                        try? await Task.sleep(for: .milliseconds(350))
                        createdMapInvite = invite
                    }
                }
            )
        case .communityMaps:
            CommunityMapListView(viewModel: makeCommunityMapListViewModel()) { path.wrappedValue.append(.map($0)) }
        case .officialMaps:
            OfficialMapListView(viewModel: makeOfficialMapListViewModel()) { path.wrappedValue.append(.map($0)) }
        case .mapIntro(let mapID):
            MapIntroView(
                viewModel: makeMapIntroViewModel(mapID),
                // 미리보기는 소개를 남긴다. 뒤로 가면 다시 소개로 온다.
                onPreview: { title, official in
                    path.wrappedValue.append(.detail(id: mapID, title: title, official: official))
                },
                // 참여하고 나면 소개는 볼 일이 없다. 상세로 갈아 끼운다.
                onJoined: { title, official in
                    path.wrappedValue.removeLast()
                    path.wrappedValue.append(.detail(id: mapID, title: title, official: official))
                },
                restroomPreview: {
                    RestroomPreviewMap(viewModel: makeRestroomMapViewModel(), locationProvider: locationProvider)
                },
                locationProvider: locationProvider
            )
        case .mapDetail(let mapID, let title):
            MapDetailView(
                viewModels: makeMapDetailViewModels(mapID),
                locationProvider: locationProvider,
                initialTitle: title,
                onBack: { back(from: mapID, joinedHere: $0, path: path) }
            )
        case .densityMap(let mapID, let title):
            DensityMapView(
                viewModel: makeDensityMapViewModel(),
                membership: makeMapMembershipViewModel(mapID),
                title: title,
                locationProvider: locationProvider,
                onBack: { back(from: mapID, joinedHere: $0, path: path) }
            )
        case .restroomMap(let mapID, let title):
            RestroomMapView(
                viewModel: makeRestroomMapViewModel(),
                membership: makeMapMembershipViewModel(mapID),
                title: title,
                locationProvider: locationProvider,
                onBack: { back(from: mapID, joinedHere: $0, path: path) }
            )
        }
    }

    /// 미리보기를 거쳐 들어와 참여했으면 소개까지 함께 닫는다.
    private func back(from mapID: Int64, joinedHere: Bool, path: Binding<[MainRoute]>) {
        let fromIntro = path.wrappedValue.dropLast().last == .mapIntro(mapID: mapID)
        path.wrappedValue.removeLast(joinedHere && fromIntro ? 2 : 1)
    }
}

private extension MainRoute {
    var placeImportStep: PlaceImportStep? {
        if case .placeImport(let step) = self { step } else { nil }
    }

    var isPlaceImport: Bool { placeImportStep != nil }

    /// 커뮤니티 지도 목록에는 공식지도가 없다.
    static func map(_ map: MapSummary) -> MainRoute {
        .map(id: map.id, title: map.title, joined: map.joined, official: false)
    }

    static func map(_ map: OfficialMap) -> MainRoute {
        .map(id: map.id, title: map.title, joined: map.joined, official: true)
    }

    /// 참여한 지도는 소개를 다시 볼 이유가 없어 바로 상세로 간다.
    /// 유동인구 지도는 소개할 장소가 없어 참여 여부와 상관없이 바로 유동인구 화면으로 간다.
    static func map(id: Int64, title: String, joined: Bool, official: Bool) -> MainRoute {
        if joined || OfficialMapKind(official: official, title: title) == .footTraffic {
            return .detail(id: id, title: title, official: official)
        }
        return .mapIntro(mapID: id)
    }

    /// 지도 자체를 보는 화면. 장소가 없는 특수 공식지도는 지도 상세 대신 전용 화면으로 간다.
    static func detail(id: Int64, title: String, official: Bool) -> MainRoute {
        switch OfficialMapKind(official: official, title: title) {
        case .footTraffic: .densityMap(mapID: id, title: title)
        case .restroom: .restroomMap(mapID: id, title: title)
        case nil: .mapDetail(mapID: id, title: title)
        }
    }
}

#if DEBUG
@MainActor
private final class PreviewLocationProvider: LocationProvider {
    var authorization: LocationAuthorization { .denied }
    var lastKnownLocation: CLLocationCoordinate2D? { nil }
    func requestAuthorization() async -> LocationAuthorization { .denied }
    func currentLocation() async -> CLLocationCoordinate2D? { nil }
}

#Preview("메인 탭") {
    MainTabView(
        exploreViewModel: ExploreViewModel(
            repository: PreviewExploreRepository(),
            officialMapRepository: PreviewOfficialMapRepository()
        ),
        collectionViewModel: CollectionViewModel(repository: PreviewCollectionRepository(), mapRepository: PreviewMapDetailRepository()),
        makeSettingsViewModel: { SettingsViewModel(repository: PreviewAuthRepository(), termsRepository: PreviewTermsRepository()) },
        makeTermDetailViewModel: { TermDetailViewModel(termID: $0, repository: PreviewTermsRepository()) },
        makeNoticeListViewModel: { NoticeListViewModel(repository: PreviewNoticeRepository(), timeZone: .current) },
        makeNoticeDetailViewModel: { NoticeDetailViewModel(noticeID: $0, repository: PreviewNoticeRepository(), timeZone: .current) },
        makeInquiryViewModel: { InquiryViewModel(repository: PreviewInquiryRepository(), userRepository: PreviewUserRepository()) },
        makeProfileEditViewModel: { ProfileEditViewModel(repository: PreviewUserRepository()) },
        makeCreateMapViewModel: { CreateMapViewModel(repository: PreviewCollectionRepository(), importRepository: PreviewPlaceImportRepository()) },
        makePlaceImportViewModel: {
            PlaceImportViewModel(source: $0, url: $1, importRepository: PreviewPlaceImportRepository(), collectionRepository: PreviewCollectionRepository())
        },
        makeCommunityMapListViewModel: { CommunityMapListViewModel(repository: PreviewExploreRepository(), sleep: { try await Task.sleep(for: $0) }) },
        makeOfficialMapListViewModel: { OfficialMapListViewModel(repository: PreviewOfficialMapRepository()) },
        makeDensityMapViewModel: { DensityMapViewModel(repository: PreviewFootTrafficRepository()) },
        makeRestroomMapViewModel: { RestroomMapViewModel(repository: PreviewRestroomRepository()) },
        makeMapIntroViewModel: { MapIntroViewModel(mapID: $0, repository: PreviewMapDetailRepository()) },
        makeMapDetailViewModels: { MapDetailViewModels.preview(mapID: $0) },
        makeMapMembershipViewModel: { MapDetailViewModels.preview(mapID: $0).main },
        sharedLinkInbox: SharedLinkInbox(),
        locationProvider: PreviewLocationProvider(),
        onLoggedOut: {}
    )
}
#endif
