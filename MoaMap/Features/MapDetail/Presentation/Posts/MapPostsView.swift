import SwiftUI

/// 로그 탭 카드 목록. 카드 높이가 사진·글 길이에 따라 달라 두 줄로 엇갈려 쌓는다.
struct MapPostsView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: MapPostListViewModel
    let onViewModeSelect: (MapPostViewMode) -> Void

    /// 위에 겹친 탭 바(위 16 + 높이 46) 밑으로 18 을 띄운다.
    static let tabBarClearance: CGFloat = 80
    static let bottomClearance: CGFloat = 88
    private static let cardGap: CGFloat = 12
    /// 끝에서 이만큼 남았을 때 다음 페이지를 부른다.
    private static let loadMoreThreshold = 4

    var body: some View {
        ScrollView {
            VStack(spacing: Self.cardGap) {
                MapPostsToolbar(
                    viewMode: .card,
                    onViewModeSelect: onViewModeSelect,
                    sort: viewModel.uiState.sort,
                    onSortSelect: viewModel.selectSort
                )
                    .padding(.bottom, 8)
                content
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .padding(.top, Self.tabBarClearance)
            .padding(.bottom, Self.bottomClearance)
        }
        .scrollIndicators(.hidden)
        .background(colors.backgroundSecondary)
        .onAppear { viewModel.loadOnce() }
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
        case .loaded(let posts) where posts.isEmpty:
            CommunityMapsPlaceholder {
                Text("아직 게시물이 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
            }
        case .loaded(let posts):
            HStack(alignment: .top, spacing: Self.cardGap) {
                ForEach(Array(MapPostColumns.split(posts).enumerated()), id: \.offset) { _, column in
                    LazyVStack(spacing: Self.cardGap) {
                        ForEach(column, id: \.post.id) { item in
                            MapPostCard(post: item.post)
                                .onAppear {
                                    if item.index >= posts.count - Self.loadMoreThreshold { viewModel.loadMore() }
                                }
                        }
                    }
                }
            }
            paging
        }
    }

    @ViewBuilder
    private var paging: some View {
        switch viewModel.uiState.paging {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .failed:
            VStack(spacing: 12) {
                Text(MapPostListViewModel.loadFailedMessage)
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
                Button("다시 시도") { viewModel.loadMore() }
                    .moaTextStyle(typography.button2)
                    .foregroundStyle(colors.textNormal)
                    .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        case .idle, .end:
            EmptyView()
        }
    }
}

/// 카드를 두 줄로 나눈다. 다음 카드는 추정 높이가 낮은 줄에 붙는다.
/// 앞 카드의 자리는 뒤에 붙는 카드에 영향을 받지 않아 다음 페이지가 붙어도 보던 카드가 옮겨 가지 않는다.
nonisolated enum MapPostColumns {
    struct Item: Equatable, Sendable {
        /// 전체 목록에서의 순서.
        let index: Int
        let post: MapPost
    }

    static func split(_ posts: [MapPost]) -> [[Item]] {
        var columns: [[Item]] = [[], []]
        var heights: [CGFloat] = [0, 0]
        for (index, post) in posts.enumerated() {
            let target = heights[1] < heights[0] ? 1 : 0
            columns[target].append(Item(index: index, post: post))
            heights[target] += estimatedHeight(of: post)
        }
        return columns
    }

    /// 카드 폭(약 150)에 14pt 글자가 한 줄에 열 자 남짓 들어간다.
    static func estimatedHeight(of post: MapPost) -> CGFloat {
        let charsPerLine = 10
        let lineHeight: CGFloat = 21
        var height: CGFloat = 24
        if !post.imageURLs.isEmpty {
            height += MapPostCard.photoHeight + 8
        } else if !post.placeNames.isEmpty {
            height += 26
        }
        if !post.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lines = post.content.split(separator: "\n", omittingEmptySubsequences: false)
                .reduce(0) { $0 + max(1, ($1.count + charsPerLine - 1) / charsPerLine) }
            height += CGFloat(min(lines, MapPostCard.contentMaxLines)) * lineHeight
        }
        return height
    }
}

nonisolated enum MapPostViewMode: CaseIterable, Sendable {
    case card
    case calendar

    var label: String {
        switch self {
        case .card: "카드 형식"
        case .calendar: "달력 형식"
        }
    }
}

/// 보기 방식 칩과 정렬. 달력 형식에는 정렬이 없어 `sort` 를 nil 로 넘기면 숨긴다.
struct MapPostsToolbar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewMode: MapPostViewMode
    let onViewModeSelect: (MapPostViewMode) -> Void
    var sort: MapPostSort?
    var onSortSelect: (MapPostSort) -> Void = { _ in }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            MapPostViewModeChip(viewMode: viewMode, onSelect: onViewModeSelect)
            Spacer()
            if let sort {
                option("등록순", .oldest, selected: sort == .oldest)
                option("최신순", .latest, selected: sort == .latest)
            }
        }
    }

    private func option(_ label: String, _ value: MapPostSort, selected: Bool) -> some View {
        Button { onSortSelect(value) } label: {
            Text(label)
                .moaTextStyle(selected ? typography.button2 : typography.button3)
                .foregroundStyle(selected ? colors.textNormal : colors.textAssistive)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 누르면 아래로 다른 보기 방식이 펼쳐진다.
private struct MapPostViewModeChip: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @State private var expanded = false

    let viewMode: MapPostViewMode
    let onSelect: (MapPostViewMode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 2) {
                    Text(viewMode.label)
                        .moaTextStyle(typography.button3)
                    // 오른쪽 화살표를 돌려 쓴다. 닫혀 있으면 아래, 펼치면 위를 가리킨다.
                    Image("Icons/arrow-right")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .rotationEffect(.degrees(expanded ? -90 : 90))
                }
                .foregroundStyle(colors.textNormal)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(viewMode.label)
            .accessibilityHint(expanded ? "보기 방식 닫기" : "보기 방식 펼치기")
            if expanded {
                ForEach(MapPostViewMode.allCases.filter { $0 != viewMode }, id: \.self) { mode in
                    Button {
                        expanded = false
                        onSelect(mode)
                    } label: {
                        Text(mode.label)
                            .moaTextStyle(typography.button3)
                            .foregroundStyle(colors.textNormal)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(MoaMapPrimitiveColors.gray300, lineWidth: 1) }
    }
}

/// 새 게시물 진입. 로그 탭에만 있다.
struct WritePostButton: View {
    @Environment(\.moaColors) private var colors

    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("Icons/add")
                .renderingMode(.template)
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(colors.textWhite)
                .padding(8)
                .background(MoaMapPrimitiveColors.blue500, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("새 게시물")
    }
}

/// 사진이 있으면 첫 사진 위에 장소 이름을 얹고, 없으면 글 위 오른쪽에 둔다. 장소는 첫 번째만 보여준다.
struct MapPostCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let post: MapPost

    nonisolated static let photoHeight: CGFloat = 146.5
    /// 목록에서는 긴 글을 자른다.
    nonisolated static let contentMaxLines = 6

    var body: some View {
        let placeName = post.placeNames.first
        VStack(alignment: .trailing, spacing: 8) {
            if let photoURL = post.imageURLs.first {
                photo(photoURL)
                    .overlay(alignment: .topTrailing) {
                        if let placeName { MapPostPlacePill(name: placeName).padding(8) }
                    }
            } else if let placeName {
                MapPostPlacePill(name: placeName)
            }
            if !post.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(post.content)
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textNormal)
                    .lineLimit(Self.contentMaxLines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private func photo(_ url: URL) -> some View {
        PostPhotoFill(url: url)
            .frame(maxWidth: .infinity)
            .frame(height: Self.photoHeight)
            .background(colors.lineAlternative)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.textWhite, lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

/// 주어진 자리를 사진으로 채운다. 크기는 부르는 쪽이 정하고 사진은 그 크기를 바꾸지 않는다.
/// `scaledToFill` 사진을 바로 두면 비율대로 자리를 넘어 옆 칸을 민다. 받지 못하면 비워 둔다.
struct PostPhotoFill: View {
    let url: URL?

    var body: some View {
        Color.clear.overlay {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { Color.clear }
                }
            }
        }
    }
}

struct MapPostPlacePill: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let name: String
    /// 기본은 caption0 이다.
    var style: MoaMapTextStyle?

    var body: some View {
        Text(name)
            .moaTextStyle(style ?? typography.caption0)
            .foregroundStyle(colors.textNormal)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(MoaMapPrimitiveColors.white.opacity(0.6), in: Capsule())
    }
}

#if DEBUG
#Preview {
    let viewModel = MapPostListViewModel(mapID: 1, repository: PreviewMapPostRepository())
    MapPostsView(viewModel: viewModel, onViewModeSelect: { _ in })
}
#endif
