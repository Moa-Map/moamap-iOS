import SwiftUI

/// 설정 「공지사항」. 공지가 없으면 안내를 화면 전체의 가운데에 둔다.
struct NoticeListView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NoticeListViewModel
    private let onNoticeClick: (Notice) -> Void

    /// 끝에서 이만큼 남으면 다음 페이지를 부른다.
    private static let loadMoreThreshold = 4

    init(viewModel: NoticeListViewModel, onNoticeClick: @escaping (Notice) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onNoticeClick = onNoticeClick
    }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "공지사항") { dismiss() }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay {
            if case .loaded(let notices) = viewModel.uiState.list, notices.isEmpty { empty }
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if case .loading = viewModel.uiState.list, viewModel.loadTask == nil { viewModel.load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.uiState.list {
        case .loading:
            ProgressView()
        case .failed(let message):
            MoaMapRetryPrompt(message: message) { viewModel.retry() }
        case .loaded(let notices) where notices.isEmpty:
            Color.clear
        case .loaded(let notices):
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(Array(notices.enumerated()), id: \.element.id) { index, notice in
                        Button { onNoticeClick(notice) } label: {
                            NoticeCard(notice: notice, dateLabel: viewModel.dateLabel(of: notice.createdAt), bodyLineLimit: 2)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if index >= notices.count - Self.loadMoreThreshold { viewModel.loadMore() }
                        }
                    }
                    paging
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
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

    private var empty: some View {
        VStack(spacing: 12) {
            Text("등록된 공지사항이 없어요")
                .moaTextStyle(typography.subtitle2)
                .foregroundStyle(colors.textAlternative)
            Text("새로운 소식이 생기면 이곳에서 알려드릴게요")
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textAssistive)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
        .accessibilityElement(children: .combine)
    }
}

/// 공지 상세. 목록 카드에 본문을 다 펼쳐 그린다.
struct NoticeDetailView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NoticeDetailViewModel

    init(viewModel: NoticeDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "공지사항") { dismiss() }
            switch viewModel.uiState {
            case .loading:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                MoaMapRetryPrompt(message: message) { viewModel.load() }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded(let notice):
                ScrollView {
                    NoticeCard(notice: notice, dateLabel: viewModel.dateLabel(of: notice.createdAt), bodyLineLimit: nil)
                        .textSelection(.enabled)
                        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                        .padding(.vertical, 20)
                }
                .scrollIndicators(.hidden)
            }
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.loadTask == nil, case .loading = viewModel.uiState { viewModel.load() }
        }
    }
}

/// 흰 바탕·안쪽 16·모서리 12 에 제목 → 본문 → 날짜를 12 간격으로 쌓는다.
private struct NoticeCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let notice: Notice
    let dateLabel: String?
    /// nil 이면 본문을 다 보인다.
    let bodyLineLimit: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(notice.title)
                .moaTextStyle(typography.subtitle2)
                .foregroundStyle(colors.textNormal)
            Text(notice.content)
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                .lineLimit(bodyLineLimit)
            if let dateLabel {
                Text(dateLabel)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.textAssistive)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 5)
        .contentShape(Rectangle())
    }
}

#if DEBUG
@MainActor
final class PreviewNoticeRepository: NoticeRepository {
    private static let notices = [
        Notice(
            id: 1, title: "모아맵 서비스 점검 안내",
            content: "10월 25일 새벽 2시부터 4시까지 서버 점검이 있어요. 점검 중에는 지도와 장소를 불러올 수 없어요. 이용에 불편을 드려 죄송합니다.",
            createdAt: Date(timeIntervalSince1970: 1_792_454_400)
        ),
        Notice(
            id: 2, title: "공식 지도에 공중화장실 지도가 추가됐어요",
            content: "서울 공중화장실 위치를 지도에서 바로 찾아보세요.",
            createdAt: Date(timeIntervalSince1970: 1_791_849_600)
        )
    ]

    func fetchNotices(page: Int, size: Int) async throws -> NoticePage { NoticePage(notices: Self.notices, isLast: true) }
    func fetchNotice(id: Int64) async throws -> Notice { Self.notices[0] }
}

#Preview("목록") {
    NavigationStack {
        NoticeListView(viewModel: NoticeListViewModel(repository: PreviewNoticeRepository(), timeZone: .current)) { _ in }
    }
}

#Preview("상세") {
    NavigationStack {
        NoticeDetailView(viewModel: NoticeDetailViewModel(noticeID: 1, repository: PreviewNoticeRepository(), timeZone: .current))
    }
}
#endif
