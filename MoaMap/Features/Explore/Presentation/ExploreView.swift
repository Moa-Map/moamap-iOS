import SwiftUI

struct ExploreView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: ExploreViewModel
    var onProfileClick: () -> Void = {}
    var onSettingsClick: () -> Void = {}
    var onSeeAllCommunityMapsClick: () -> Void = {}
    var onOfficialMapsClick: () -> Void = {}
    var onMapClick: (MapSummary) -> Void = { _ in }

    @State private var showsProfileMenu = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    OfficialMapBanner(action: onOfficialMapsClick)
                        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    content
                }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .overlay(alignment: .topTrailing) {
            if showsProfileMenu { profileMenu }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.refresh() }
        .onDisappear { showsProfileMenu = false }
    }

    private var profileMenu: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { showsProfileMenu = false }
                .accessibilityHidden(true)
            ProfileMenu(
                onProfileClick: {
                    showsProfileMenu = false
                    onProfileClick()
                },
                onSettingsClick: {
                    showsProfileMenu = false
                    onSettingsClick()
                }
            )
            .padding(.top, 5)
            .padding(.trailing, MoaMapDimens.screenHorizontalPadding)
            .accessibilityAction(.escape) { showsProfileMenu = false }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !viewModel.recommendedMaps.isEmpty {
            recommendedSection
        }
        communitySection
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image("moa-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 73.67, height: 44)
                .accessibilityLabel("모아맵")
            Spacer()
            headerButton(icon: "Icons/notifications", label: "알림") {}
            headerButton(icon: "Icons/person", label: "내 정보") { showsProfileMenu = true }
        }
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        .frame(height: 52)
    }

    private func headerButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var recommendedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("\(viewModel.nickname ?? "회원")님을 위한 추천 지도")
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(viewModel.recommendedMaps) { map in
                        Button { onMapClick(map) } label: { RecommendedMapCard(map: map) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                // 카드 그림자가 스크롤 영역에 잘리지 않게 한다.
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, -8)
        }
    }

    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("커뮤니티 지도")
                    .moaTextStyle(typography.title2)
                    .foregroundStyle(colors.textNormal)
                Spacer()
                Button(action: onSeeAllCommunityMapsClick) {
                    HStack(spacing: 2) {
                        Text("전체보기")
                            .moaTextStyle(typography.button2)
                        Image("Icons/arrow-right")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(colors.textAlternative)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 12) {
                CommunityMapSortRow(selected: viewModel.sortOrder) { viewModel.changeSort($0) }

                VStack(spacing: 8) {
                    switch viewModel.uiState {
                    case .idle, .loading:
                        CommunityMapsPlaceholder { ProgressView() }
                    case .failed(let message):
                        CommunityMapsPlaceholder {
                            CommunityMapsError(message: message) { viewModel.retryCommunity() }
                        }
                    case .loaded:
                        if viewModel.communityMaps.isEmpty {
                            CommunityMapsPlaceholder {
                                Text("아직 등록된 지도가 없어요")
                                    .moaTextStyle(typography.body2)
                                    .foregroundStyle(colors.textAssistive)
                            }
                        }
                        ForEach(viewModel.communityMaps) { map in
                            Button { onMapClick(map) } label: { CommunityMapCard(map: map) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .moaTextStyle(typography.title2)
            .foregroundStyle(colors.textNormal)
            .padding(.horizontal, 4)
    }
}

#if DEBUG
@MainActor
final class PreviewExploreRepository: ExploreRepository {
    private static let maps = (1...4).map {
        MapSummary(id: Int64($0), title: "지도 이름", imageURL: nil, tags: ["태그", "태그", "태그"], memberCount: 0, placeCount: 0)
    }

    func fetchRecommendedMaps(size: Int) async throws -> [MapSummary] { Self.maps }
    func fetchCommunityMaps(tag: String?, sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage {
        MapPage(maps: Self.maps, isLast: true)
    }
    func fetchMyNickname() async throws -> String? { "00" }
}

#Preview {
    ExploreView(viewModel: ExploreViewModel(repository: PreviewExploreRepository()))
}
#endif
