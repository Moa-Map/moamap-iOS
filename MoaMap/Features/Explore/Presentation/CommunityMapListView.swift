import SwiftUI

struct CommunityMapListView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CommunityMapListViewModel
    private let onMapClick: (MapSummary) -> Void

    /// 끝에서 이만큼 남으면 다음 페이지를 부른다.
    private static let loadMoreThreshold = 4

    /// 부모가 다시 그려져도 처음 받은 ViewModel 을 쓴다. 바뀌면 받아 둔 목록이 사라진다.
    init(viewModel: CommunityMapListViewModel, onMapClick: @escaping (MapSummary) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onMapClick = onMapClick
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ExploreSearchBar(
                        query: viewModel.uiState.query,
                        maxLength: CommunityMapListViewModel.searchKeywordMaxLength,
                        onQueryChange: { viewModel.updateQuery($0) },
                        onSearch: { viewModel.searchNow() }
                    )
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    if viewModel.uiState.isSearching {
                        // 칩·정렬이 빠진 자리. 검색창과 목록 사이 간격은 그대로 둔다.
                        Color.clear.frame(height: 20)
                    } else {
                        tagChips
                            .padding(.top, 12)
                        CommunityMapSortRow(selected: viewModel.uiState.sort) { viewModel.selectSort($0) }
                            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                            .padding(.top, 20)
                            .padding(.bottom, 12)
                    }
                    content
                    paging
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.refresh() }
    }

    private var topBar: some View {
        ZStack {
            Text("커뮤니티 지도")
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
            HStack {
                Button { dismiss() } label: {
                    Image("Icons/arrow-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(colors.textNormal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")
                Spacer()
            }
            .padding(.leading, MoaMapDimens.screenHorizontalPadding - 6)
        }
        .frame(height: 58)
    }

    private var tagChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                CategoryChip(title: "전체", isSelected: viewModel.uiState.selectedTag == nil) {
                    viewModel.selectTag(nil)
                }
                ForEach(viewModel.uiState.tags, id: \.self) { tag in
                    CategoryChip(title: tag, isSelected: tag == viewModel.uiState.selectedTag) {
                        viewModel.selectTag(tag)
                    }
                }
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            // 칩 그림자가 스크롤 영역에 잘리지 않게 한다.
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, -8)
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.uiState.list {
        case .loading:
            CommunityMapsPlaceholder { ProgressView() }
        case .failed(let message):
            CommunityMapsPlaceholder {
                CommunityMapsError(message: message) { viewModel.retry() }
            }
        case .loaded(let maps) where maps.isEmpty && viewModel.uiState.isSearching:
            // 검색 결과가 없으면 아무것도 띄우지 않는다.
            EmptyView()
        case .loaded(let maps) where maps.isEmpty:
            CommunityMapsPlaceholder {
                Text(viewModel.uiState.selectedTag == nil ? "아직 등록된 지도가 없어요" : "이 태그의 지도가 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
            }
        case .loaded(let maps):
            ForEach(Array(maps.enumerated()), id: \.element.id) { index, map in
                Button { onMapClick(map) } label: { CommunityMapCard(map: map) }
                    .buttonStyle(.plain)
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    .padding(.bottom, 8)
                    .onAppear {
                        if index >= maps.count - Self.loadMoreThreshold { viewModel.loadMore() }
                    }
            }
        }
    }

    @ViewBuilder
    private var paging: some View {
        switch viewModel.uiState.paging {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        case .failed:
            Button("다시 시도") { viewModel.loadMore() }
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textNormal)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        case .idle, .end:
            EmptyView()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        CommunityMapListView(viewModel: CommunityMapListViewModel(repository: PreviewExploreRepository(), sleep: { try await Task.sleep(for: $0) }), onMapClick: { _ in })
    }
}
#endif
