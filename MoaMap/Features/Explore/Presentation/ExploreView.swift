import SwiftUI

struct ExploreView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: ExploreViewModel
    var onProfileClick: () -> Void = {}
    var onSettingsClick: () -> Void = {}
    var onSeeAllCommunityMapsClick: () -> Void = {}
    var onSeeAllOfficialMapsClick: () -> Void = {}
    var onMapClick: (MapSummary) -> Void = { _ in }
    var onOfficialMapClick: (OfficialMap) -> Void = { _ in }

    @State private var showsProfileMenu = false

    private static let topID = "explore-top"

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                header { withAnimation { proxy.scrollTo(Self.topID, anchor: .top) } }

                ScrollView {
                    // 시안 「메인 화면」: 상단 바 아래 20, 히어로 아래 21, 섹션 사이 20.
                    VStack(alignment: .leading, spacing: 0) {
                        // 운영자 추천 API 가 없어 임시 데이터다.
                        FeaturedMapCarousel(maps: FeaturedMap.mocks)
                        VStack(alignment: .leading, spacing: 20) {
                            communitySection
                            officialSection
                        }
                        .padding(.top, 21)
                    }
                    .padding(.top, 20)
                    // 하단 탭 위 띄움 8 과 합쳐 시안의 마지막 카드 ↔ 하단 탭 32.
                    .padding(.bottom, 24)
                    // 위 여백까지 포함해야 맨 위로 올렸을 때 처음 화면과 같다.
                    .id(Self.topID)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background { MoaMapPrimitiveColors.tabBackground.ignoresSafeArea() }
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
            // 시안: 상태 표시줄 아래 42(상단 바 아래쪽과 10 겹침), 화면 끝에서 20.
            .padding(.top, 42)
            .padding(.trailing, MoaMapDimens.screenHorizontalPadding)
            .accessibilityAction(.escape) { showsProfileMenu = false }
        }
    }

    /// 시안 「메인 화면」: 높이 52, 로고 본체(43×34.3)가 왼쪽 24·위 9, 오른쪽 끝 20 에 알림·프로필 아이콘
    /// 24 가 사이 8 로 놓인다. 로고는 홈으로 가는 버튼이라, 이미 홈인 여기서는 맨 위로 올린다.
    private func header(onLogoClick: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            MoaMapTopBarLogo(action: onLogoClick)
                .accessibilityLabel("맨 위로")
            Spacer()
            // 알림 기능이 생길 때까지 보이기만 한다.
            headerIcon("Icons/bell-outline")
                .accessibilityLabel("알림")
            Button { showsProfileMenu = true } label: { headerIcon("Icons/person-outline") }
                .buttonStyle(.plain)
                .accessibilityLabel("프로필 메뉴")
        }
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        .frame(height: 52)
    }

    private func headerIcon(_ name: String) -> some View {
        Image(name)
            .resizable()
            .frame(width: 24, height: 24)
            .contentShape(Rectangle().inset(by: -8))
    }

    /// 섹션 제목 줄: 제목 + 「전체보기 >」.
    private func sectionHeader(_ title: String, onSeeAllClick: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .moaTextStyle(typography.title2)
                .foregroundStyle(colors.textNormal)
            Spacer()
            Button(action: onSeeAllClick) {
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
    }

    /// 시안: 제목 줄 ↔ 카드 16, 카드 사이 8. 인기순 앞 3개만 보여 준다.
    private var communitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("커뮤니티 지도", onSeeAllClick: onSeeAllCommunityMapsClick)

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
                        CommunityMapsPlaceholder { emptyMessage("아직 등록된 지도가 없어요") }
                    }
                    ForEach(viewModel.communityMaps) { map in
                        Button { onMapClick(map) } label: { CommunityMapCard(map: map) }
                            .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
    }

    /// 시안: 제목 줄 ↔ 카드 16, 카드는 가로로 넘기고 사이 12. 로딩·오류·빈 상태는 시안이 없어
    /// 커뮤니티 섹션과 같은 모양을 쓴다.
    private var officialSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader("공식 지도", onSeeAllClick: onSeeAllOfficialMapsClick)
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)

            switch viewModel.officialState {
            case .loading:
                CommunityMapsPlaceholder { ProgressView() }
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            case .failed(let message):
                CommunityMapsPlaceholder {
                    CommunityMapsError(message: message) { viewModel.retryOfficial() }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            case .loaded(let maps) where maps.isEmpty:
                CommunityMapsPlaceholder { emptyMessage("아직 공식 지도가 없어요") }
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            case .loaded(let maps):
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(maps) { map in
                            Button { onOfficialMapClick(map) } label: { HomeOfficialMapCard(map: map) }
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
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .moaTextStyle(typography.body2)
            .foregroundStyle(colors.textAssistive)
    }
}

#if DEBUG
@MainActor
final class PreviewExploreRepository: ExploreRepository {
    private static let maps = (1...3).map {
        MapSummary(id: Int64($0), title: "지도 이름", imageURL: nil, tags: ["태그", "태그", "태그"], memberCount: 0, placeCount: 0)
    }

    func fetchRecommendedMaps(size: Int) async throws -> [MapSummary] { Self.maps }
    func fetchCommunityMaps(tag: String?, sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage {
        MapPage(maps: Self.maps, isLast: true)
    }
    func fetchMyNickname() async throws -> String? { "00" }
}

#Preview {
    ExploreView(
        viewModel: ExploreViewModel(
            repository: PreviewExploreRepository(),
            officialMapRepository: PreviewOfficialMapRepository()
        )
    )
}
#endif
