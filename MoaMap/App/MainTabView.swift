import CoreLocation
import SwiftUI

private enum MainRoute: Hashable {
    case profileEdit
    case settings
    case communityMaps
    case officialMaps
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

    private let makeSettingsViewModel: () -> SettingsViewModel
    private let makeProfileEditViewModel: () -> ProfileEditViewModel
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
                    onOfficialMapsClick: { explorePath.append(.officialMaps) },
                    onMapClick: { explorePath.append(.map($0)) }
                )
                .navigationDestination(for: MainRoute.self) { destination($0, path: $explorePath) }
            }
            .tag(MainTab.explore)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack(path: $collectionPath) {
                CollectionView(
                    viewModel: collectionViewModel,
                    onHome: { selection = .explore },
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
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }

    private var isRoot: Bool { explorePath.isEmpty && collectionPath.isEmpty }

    @ViewBuilder
    private func destination(_ route: MainRoute, path: Binding<[MainRoute]>) -> some View {
        switch route {
        case .profileEdit:
            ProfileEditView(viewModel: makeProfileEditViewModel()) { profile in
                exploreViewModel.updateNickname(profile.nickname)
            }
        case .settings:
            SettingsView(viewModel: makeSettingsViewModel(), onLoggedOut: onLoggedOut)
        case .communityMaps:
            CommunityMapListView(viewModel: makeCommunityMapListViewModel()) { path.wrappedValue.append(.map($0)) }
        case .officialMaps:
            OfficialMapListView(viewModel: makeOfficialMapListViewModel()) {
                path.wrappedValue.append(.map(id: $0.id, title: $0.title, joined: $0.joined, official: true))
            }
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
    /// 커뮤니티 지도 목록에는 공식지도가 없다.
    static func map(_ map: MapSummary) -> MainRoute {
        .map(id: map.id, title: map.title, joined: map.joined, official: false)
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
        exploreViewModel: ExploreViewModel(repository: PreviewExploreRepository()),
        collectionViewModel: CollectionViewModel(repository: PreviewCollectionRepository()),
        makeSettingsViewModel: { SettingsViewModel(repository: PreviewAuthRepository()) },
        makeProfileEditViewModel: { ProfileEditViewModel(repository: PreviewUserRepository()) },
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
