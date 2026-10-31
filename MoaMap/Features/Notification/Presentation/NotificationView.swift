import SwiftUI

/// 알림. 홈 종 아이콘으로 들어온다. 시안 「알림」(`4925:20123`).
struct NotificationView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: NotificationListViewModel
    /// 갈 곳이 있는 알림을 눌렀을 때. 갈 곳이 없으면 읽음으로만 바뀐다.
    private let onDestination: (NotificationDestination) -> Void

    /// 끝에서 이만큼 남으면 다음 페이지를 부른다.
    private static let loadMoreThreshold = 4

    init(viewModel: NotificationListViewModel, onDestination: @escaping (NotificationDestination) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onDestination = onDestination
    }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "알림") { dismiss() }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // 화면 전체의 가운데에 둔다.
        .overlay {
            if case .loaded(let notifications) = viewModel.uiState.list, notifications.isEmpty {
                Text("아직 받은 알림이 없어요")
                    .moaTextStyle(typography.subtitle2)
                    .foregroundStyle(colors.textAlternative)
                    .multilineTextAlignment(.center)
            }
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
        case .loaded(let notifications) where notifications.isEmpty:
            Color.clear
        case .loaded(let notifications):
            ScrollView {
                // 시안: 상단 바 아래 12 에 「모두 읽음」, 그 아래 12 에 카드(사이 8).
                VStack(alignment: .trailing, spacing: 12) {
                    Button("모두 읽음") { viewModel.markAllRead() }
                        .moaTextStyle(typography.button2)
                        .foregroundStyle(colors.textAlternative)
                        .buttonStyle(.plain)
                        .contentShape(Rectangle().inset(by: -8))
                    LazyVStack(spacing: 8) {
                        ForEach(Array(notifications.enumerated()), id: \.element.id) { index, notification in
                            Button {
                                if let destination = viewModel.open(notification) { onDestination(destination) }
                            } label: {
                                NotificationCard(notification: notification, timeLabel: viewModel.timeLabel(of: notification.createdAt))
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if index >= notifications.count - Self.loadMoreThreshold { viewModel.loadMore() }
                            }
                        }
                        paging
                    }
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 20)
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
}

/// 시안 「Alarm」: 안쪽 16, 모서리 12, 아이콘 24 · 문구 위에 시각(사이 4).
/// 안 읽은 알림은 흰 바탕에 그림자와 오른쪽 위 파란 점 8, 읽은 알림은 회색 바탕에 테두리 1 이다.
private struct NotificationCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let notification: UserNotification
    let timeLabel: String?

    private var unread: Bool { !notification.read }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 12) {
                Image(notification.kind.iconName)
                    .resizable()
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.message)
                        .moaTextStyle(typography.subtitle4)
                        .foregroundStyle(colors.textNormal)
                    if let timeLabel {
                        Text(timeLabel)
                            .moaTextStyle(typography.caption0)
                            .foregroundStyle(colors.textAssistive)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if unread {
                Circle()
                    .fill(MoaMapPrimitiveColors.blue600)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(16)
        .background {
            let shape = RoundedRectangle(cornerRadius: 12)
            if unread {
                shape.fill(MoaMapPrimitiveColors.white).shadow(color: .black.opacity(0.04), radius: 4)
            } else {
                shape.fill(colors.backgroundSecondary).overlay { shape.strokeBorder(colors.lineAlternative, lineWidth: 1) }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(unread ? "안 읽음" : "")
    }
}

#if DEBUG
@MainActor
final class PreviewNotificationRepository: NotificationRepository {
    func fetchNotifications(page: Int, size: Int) async throws -> NotificationPage {
        let now = Date()
        return NotificationPage(notifications: [
            UserNotification(
                id: 1, kind: .mapAdminAssigned, message: "모아님이 나를 지도 관리자로 지정했어요.", targetID: 10, mapID: 10,
                read: false, createdAt: now
            ),
            UserNotification(
                id: 2, kind: .mapPostCommented, message: "커비님이 내 게시글에 댓글을 남겼어요.", targetID: 3, mapID: 10,
                read: false, createdAt: now.addingTimeInterval(-3600)
            ),
            UserNotification(
                id: 3, kind: .placeApproved, message: "등록 요청한 장소가 승인됐어요.", targetID: 5, mapID: 10,
                read: true, createdAt: now.addingTimeInterval(-86_400)
            ),
            UserNotification(
                id: 4, kind: .placeRejected, message: "등록 요청한 장소가 반려됐어요.", targetID: 6, mapID: 10,
                read: true, createdAt: now.addingTimeInterval(-2 * 86_400)
            )
        ], isLast: true)
    }

    func markRead(id: Int64) async throws {}
    func markAllRead() async throws {}
}

#Preview("알림") {
    NavigationStack {
        NotificationView(
            viewModel: NotificationListViewModel(repository: PreviewNotificationRepository(), timeZone: .current, now: Date.init)
        ) { _ in }
    }
}
#endif
