import SwiftUI

struct ExploreView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: ExploreViewModel

    // TODO: 태그 목록 API 가 정해지면 서버 값으로 바꾸고 목록 조회에 반영한다.
    var categories = ExploreView.sampleCategories

    @State private var selectedCategory = "전체"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    ExploreSearchBar()
                        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    OfficialMapBanner()
                        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    content
                }
            }
            .padding(.bottom, 20)
        }
        .scrollIndicators(.hidden)
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .task { viewModel.loadIfNeeded() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.uiState {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        case .failed(let message):
            failure(message)
        case .loaded:
            if !viewModel.recommendedMaps.isEmpty {
                recommendedSection
            }
            communitySection
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image("moa-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 73.67, height: 44)
                .accessibilityLabel("모아맵")
            Spacer()
            headerButton(icon: "Icons/notifications", label: "알림")
            headerButton(icon: "Icons/person", label: "내 정보")
        }
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        .frame(height: 52)
    }

    private func headerButton(icon: String, label: String) -> some View {
        Button {} label: {
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
                        RecommendedMapCard(map: map)
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
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("커뮤니티 지도")
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        CategoryChip(title: category, isSelected: category == selectedCategory) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .padding(.vertical, -8)

            LazyVStack(alignment: .trailing, spacing: 8) {
                sortPicker
                if viewModel.communityMaps.isEmpty && !viewModel.isLoadingMore {
                    Text("아직 커뮤니티 지도가 없어요")
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAssistive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                }
                ForEach(viewModel.communityMaps) { map in
                    CommunityMapCard(map: map)
                        .onAppear { viewModel.loadMoreIfNeeded(after: map) }
                }
                if viewModel.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        }
    }

    private var sortPicker: some View {
        HStack(spacing: 8) {
            ForEach(MapSortOrder.allCases) { order in
                let isSelected = order == viewModel.sortOrder
                Button {
                    viewModel.changeSort(order)
                } label: {
                    Text(order.title)
                        .moaTextStyle(isSelected ? typography.button2 : typography.button3)
                        .foregroundStyle(isSelected ? colors.textNormal : colors.textAssistive)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textAlternative)
                .multilineTextAlignment(.center)
            Button("다시 시도") { viewModel.load() }
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textNormal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .moaTextStyle(typography.title2)
            .foregroundStyle(colors.textNormal)
            .padding(.horizontal, 4)
    }
}

private extension MapSortOrder {
    var title: String {
        switch self {
        case .popular: "인기순"
        case .latest: "최신순"
        }
    }
}

extension ExploreView {
    static let sampleCategories = ["전체", "맛집", "카페", "데이트", "여행", "팝업"]
}

#if DEBUG
@MainActor
final class PreviewExploreRepository: ExploreRepository {
    private static let maps = (1...4).map {
        MapSummary(id: Int64($0), title: "지도 이름", imageURL: nil, tags: ["태그", "태그", "태그"], memberCount: 0, placeCount: 0)
    }

    func fetchRecommendedMaps(size: Int) async throws -> [MapSummary] { Self.maps }
    func fetchCommunityMaps(sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage {
        MapPage(maps: Self.maps, isLast: true)
    }
    func fetchMyNickname() async throws -> String? { "00" }
}

#Preview {
    ExploreView(viewModel: ExploreViewModel(repository: PreviewExploreRepository()))
}
#endif
