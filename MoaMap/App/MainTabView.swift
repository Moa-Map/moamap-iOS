import CoreLocation
import SwiftUI

private enum MainRoute: Hashable {
    case profileEdit
    case settings
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

    private let makeSettingsViewModel: () -> SettingsViewModel
    private let makeProfileEditViewModel: () -> ProfileEditViewModel
    private let makeCreateMapViewModel: () -> CreateMapViewModel
    private let makePlaceImportViewModel: (PlaceImportSource) -> PlaceImportViewModel
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
        makeProfileEditViewModel: @escaping () -> ProfileEditViewModel,
        makeCreateMapViewModel: @escaping () -> CreateMapViewModel,
        makePlaceImportViewModel: @escaping (PlaceImportSource) -> PlaceImportViewModel,
        makeCommunityMapListViewModel: @escaping () -> CommunityMapListViewModel,
        makeOfficialMapListViewModel: @escaping () -> OfficialMapListViewModel,
        makeDensityMapViewModel: @escaping () -> DensityMapViewModel,
        makeRestroomMapViewModel: @escaping () -> RestroomMapViewModel,
        makeMapIntroViewModel: @escaping (Int64) -> MapIntroViewModel,
        makeMapDetailViewModels: @escaping (Int64) -> MapDetailViewModels,
        makeMapMembershipViewModel: @escaping (Int64) -> MapDetailViewModel,
        locationProvider: any LocationProvider,
        onLoggedOut: @escaping () -> Void
    ) {
        _collectionViewModel = State(initialValue: collectionViewModel)
        _exploreViewModel = State(initialValue: exploreViewModel)
        self.makeSettingsViewModel = makeSettingsViewModel
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
                .navigationDestination(for: MainRoute.self) { destination($0, path: $explorePath) }
            }
            .tag(MainTab.explore)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack(path: $collectionPath) {
                CollectionView(
                    viewModel: collectionViewModel,
                    onHome: { selection = .explore },
                    onCreateMap: { collectionPath.append(.createMap) },
                    onImportPlaces: startPlaceImport,
                    // 모음에는 참여한 지도만 있어 소개를 건너뛴다.
                    onMapClick: { collectionPath.append(.detail(id: $0.id, title: $0.title, official: $0.official)) }
                )
                .navigationDestination(for: MainRoute.self) { destination($0, path: $collectionPath) }
            }
            .tag(MainTab.collection)
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 하위 화면에서는 하단 탭을 숨긴다.
            if isRoot {
                MoaMapBottomBar(selection: $selection)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
            }
        }
        // 하단 탭이 키보드를 따라 올라오지 않게 한다. 하위 화면은 입력창이 키보드를 피해야 한다.
        .ignoresSafeArea(isRoot ? .keyboard : [], edges: .bottom)
        .onChange(of: collectionPath) { _, path in
            if !path.contains(where: \.isPlaceImport) { placeImportViewModel = nil }
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }

    private var isRoot: Bool { explorePath.isEmpty && collectionPath.isEmpty }

    private func startPlaceImport(_ source: PlaceImportSource) {
        let viewModel = makePlaceImportViewModel(source)
        viewModel.loadTargetMaps()
        placeImportViewModel = viewModel
        collectionPath.append(.placeImport(.url))
    }

    private func placeImportNavigator(_ path: Binding<[MainRoute]>) -> PlaceImportNavigator {
        PlaceImportNavigator(
            steps: { path.wrappedValue.compactMap(\.placeImportStep) },
            // 흐름의 단계는 늘 스택 맨 위에 이어 쌓여 있다.
            setSteps: { steps in
                path.wrappedValue = path.wrappedValue.filter { !$0.isPlaceImport } + steps.map(MainRoute.placeImport)
            }
        )
    }

    @ViewBuilder
    private func destination(_ route: MainRoute, path: Binding<[MainRoute]>) -> some View {
        switch route {
        case .profileEdit:
            ProfileEditView(viewModel: makeProfileEditViewModel()) { _ in }
        case .settings:
            SettingsView(viewModel: makeSettingsViewModel(), onLoggedOut: onLoggedOut)
        case .placeImport(let step):
            if let placeImportViewModel {
                PlaceImportDestination(step: step, viewModel: placeImportViewModel, navigator: placeImportNavigator(path))
            }
        case .createMap:
            // 만들기 화면을 남기면 뒤로가기로 돌아와 같은 지도를 또 만들 수 있다.
            CreateMapView(viewModel: makeCreateMapViewModel()) { path.wrappedValue.removeLast() }
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
                    RestroomPreviewMap(viewModel: makeRestroomMapViewModel(), center: locationProvider.lastKnownLocation)
                }
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
        collectionViewModel: CollectionViewModel(repository: PreviewCollectionRepository()),
        makeSettingsViewModel: { SettingsViewModel(repository: PreviewAuthRepository()) },
        makeProfileEditViewModel: { ProfileEditViewModel(repository: PreviewUserRepository()) },
        makeCreateMapViewModel: { CreateMapViewModel(repository: PreviewCollectionRepository()) },
        makePlaceImportViewModel: {
            PlaceImportViewModel(source: $0, importRepository: PreviewPlaceImportRepository(), collectionRepository: PreviewCollectionRepository())
        },
        makeCommunityMapListViewModel: { CommunityMapListViewModel(repository: PreviewExploreRepository()) },
        makeOfficialMapListViewModel: { OfficialMapListViewModel(repository: PreviewOfficialMapRepository()) },
        makeDensityMapViewModel: { DensityMapViewModel(repository: PreviewFootTrafficRepository()) },
        makeRestroomMapViewModel: { RestroomMapViewModel(repository: PreviewRestroomRepository()) },
        makeMapIntroViewModel: { MapIntroViewModel(mapID: $0, repository: PreviewMapDetailRepository()) },
        makeMapDetailViewModels: { MapDetailViewModels.preview(mapID: $0) },
        makeMapMembershipViewModel: { MapDetailViewModels.preview(mapID: $0).main },
        locationProvider: PreviewLocationProvider(),
        onLoggedOut: {}
    )
}
#endif
