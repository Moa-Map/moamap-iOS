import SwiftUI

private enum MainRoute: Hashable {
    case settings
    case communityMaps
    case mapIntro(mapID: Int64)
    case mapDetail(mapID: Int64, title: String)
}

struct MainTabView: View {
    @Environment(\.moaColors) private var colors
    @State private var selection: MainTab = .explore
    @State private var exploreViewModel: ExploreViewModel
    @State private var explorePath: [MainRoute] = []

    @State private var collectionViewModel: CollectionViewModel
    @State private var collectionPath: [MainRoute] = []

    private let makeSettingsViewModel: () -> SettingsViewModel
    private let makeCommunityMapListViewModel: () -> CommunityMapListViewModel
    private let makeMapIntroViewModel: (Int64) -> MapIntroViewModel
    private let makeMapDetailViewModel: (Int64) -> MapDetailViewModel
    private let locationProvider: any LocationProvider
    private let onLoggedOut: () -> Void

    init(
        exploreViewModel: ExploreViewModel,
        collectionViewModel: CollectionViewModel,
        makeSettingsViewModel: @escaping () -> SettingsViewModel,
        makeCommunityMapListViewModel: @escaping () -> CommunityMapListViewModel,
        makeMapIntroViewModel: @escaping (Int64) -> MapIntroViewModel,
        makeMapDetailViewModel: @escaping (Int64) -> MapDetailViewModel,
        locationProvider: any LocationProvider,
        onLoggedOut: @escaping () -> Void
    ) {
        _collectionViewModel = State(initialValue: collectionViewModel)
        _exploreViewModel = State(initialValue: exploreViewModel)
        self.makeSettingsViewModel = makeSettingsViewModel
        self.makeCommunityMapListViewModel = makeCommunityMapListViewModel
        self.makeMapIntroViewModel = makeMapIntroViewModel
        self.makeMapDetailViewModel = makeMapDetailViewModel
        self.locationProvider = locationProvider
        self.onLoggedOut = onLoggedOut
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $explorePath) {
                ExploreView(
                    viewModel: exploreViewModel,
                    onSettingsClick: { explorePath.append(.settings) },
                    onSeeAllCommunityMapsClick: { explorePath.append(.communityMaps) },
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
                    onMapClick: { collectionPath.append(.mapDetail(mapID: $0.id, title: $0.title)) }
                )
                .navigationDestination(for: MainRoute.self) { destination($0, path: $collectionPath) }
            }
            .tag(MainTab.collection)
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 하위 화면에서는 하단 탭을 숨긴다.
            if explorePath.isEmpty && collectionPath.isEmpty {
                MoaMapBottomBar(selection: $selection)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func destination(_ route: MainRoute, path: Binding<[MainRoute]>) -> some View {
        switch route {
        case .settings:
            SettingsView(viewModel: makeSettingsViewModel(), onLoggedOut: onLoggedOut)
        case .communityMaps:
            CommunityMapListView(viewModel: makeCommunityMapListViewModel()) { path.wrappedValue.append(.map($0)) }
        case .mapIntro(let mapID):
            MapIntroView(
                viewModel: makeMapIntroViewModel(mapID),
                // 미리보기는 소개를 남긴다. 뒤로 가면 다시 소개로 온다.
                onPreview: { path.wrappedValue.append(.mapDetail(mapID: mapID, title: $0)) },
                // 참여하고 나면 소개는 볼 일이 없다. 상세로 갈아 끼운다.
                onJoined: { title in
                    path.wrappedValue.removeLast()
                    path.wrappedValue.append(.mapDetail(mapID: mapID, title: title))
                }
            )
        case .mapDetail(let mapID, let title):
            MapDetailView(
                viewModel: makeMapDetailViewModel(mapID),
                locationProvider: locationProvider,
                initialTitle: title,
                onBack: { joinedHere in
                    // 미리보기를 거쳐 들어와 참여했으면 소개까지 함께 닫는다.
                    let fromIntro = path.wrappedValue.dropLast().last == .mapIntro(mapID: mapID)
                    path.wrappedValue.removeLast(joinedHere && fromIntro ? 2 : 1)
                }
            )
        }
    }
}

private extension MainRoute {
    /// 참여한 지도는 소개를 다시 볼 이유가 없어 바로 상세로 간다.
    static func map(_ map: MapSummary) -> MainRoute {
        map.joined ? .mapDetail(mapID: map.id, title: map.title) : .mapIntro(mapID: map.id)
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
        makeCommunityMapListViewModel: { CommunityMapListViewModel(repository: PreviewExploreRepository()) },
        makeMapIntroViewModel: { MapIntroViewModel(mapID: $0, repository: PreviewMapDetailRepository()) },
        makeMapDetailViewModel: { MapDetailViewModel(mapID: $0, repository: PreviewMapDetailRepository()) },
        locationProvider: PreviewLocationProvider(),
        onLoggedOut: {}
    )
}
#endif
