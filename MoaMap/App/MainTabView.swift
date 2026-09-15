import SwiftUI

struct MainTabView: View {
    @Environment(\.moaColors) private var colors
    @State private var selection: MainTab = .explore

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ExploreView()
            }
            .tag(MainTab.explore)
            .toolbar(.hidden, for: .tabBar)

            NavigationStack {
                CollectionView()
            }
            .tag(MainTab.collection)
            .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MoaMapBottomBar(selection: $selection)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .preferredColorScheme(.light)
    }
}

#Preview("메인 탭") {
    MainTabView()
}
