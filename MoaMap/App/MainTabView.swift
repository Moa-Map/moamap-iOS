import SwiftUI

private enum ExploreRoute: Hashable {
    case settings
    case communityMaps
}

struct MainTabView: View {
    @Environment(\.moaColors) private var colors
    @State private var selection: MainTab = .explore
    @State private var exploreViewModel: ExploreViewModel
    @State private var explorePath: [ExploreRoute] = []

    @State private var collectionViewModel: CollectionViewModel

    private let makeSettingsViewModel: () -> SettingsViewModel
    private let makeCommunityMapListViewModel: () -> CommunityMapListViewModel
    private let onLoggedOut: () -> Void

    init(
        exploreViewModel: ExploreViewModel,
        collectionViewModel: CollectionViewModel,
        makeSettingsViewModel: @escaping () -> SettingsViewModel,
        makeCommunityMapListViewModel: @escaping () -> CommunityMapListViewModel,
        onLoggedOut: @escaping () -> Void
    ) {
        _collectionViewModel = State(initialValue: collectionViewModel)
        _exploreViewModel = State(initialValue: exploreViewModel)
        self.makeSettingsViewModel = makeSettingsViewModel
        self.makeCommunityMapListViewModel = makeCommunityMapListViewModel
        self.onLoggedOut = onLoggedOut
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack(path: $explorePath) {
                ExploreView(
                    viewModel: exploreViewModel,
                    onSettingsClick: { explorePath.append(.settings) },
                    onSeeAllCommunityMapsClick: { explorePath.append(.communityMaps) }
                )
                .navigationDestination(for: ExploreRoute.self) { route in
                    switch route {
                    case .settings:
                        SettingsView(viewModel: makeSettingsViewModel(), onLoggedOut: onLoggedOut)
                    case .communityMaps:
                        CommunityMapListView(viewModel: makeCommunityMapListViewModel())
                    }
                }
            }
            .tag(MainTab.explore)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                CollectionView(viewModel: collectionViewModel, onHome: { selection = .explore })
            }
            .tag(MainTab.collection)
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 하위 화면에서는 하단 탭을 숨긴다.
            if explorePath.isEmpty {
                MoaMapBottomBar(selection: $selection)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }
}

#if DEBUG
#Preview("메인 탭") {
    MainTabView(
        exploreViewModel: ExploreViewModel(repository: PreviewExploreRepository()),
        collectionViewModel: CollectionViewModel(repository: PreviewCollectionRepository()),
        makeSettingsViewModel: { SettingsViewModel(repository: PreviewAuthRepository()) },
        makeCommunityMapListViewModel: { CommunityMapListViewModel(repository: PreviewExploreRepository()) },
        onLoggedOut: {}
    )
}
#endif
