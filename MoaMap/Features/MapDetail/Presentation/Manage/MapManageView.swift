import SwiftUI

/// 지도 관리. 장소 등록 요청과 멤버의 장소 추가·삭제·댓글 기록을 모아 본다.
struct MapManageView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let activityViewModel: MapActivityViewModel
    let pendingViewModel: PendingRequestViewModel
    /// 수락·거절할 수 있는 사람에게만 요청을 보여 준다.
    let canReviewRequests: Bool
    let onBack: () -> Void

    @State private var notice: String?

    private var activity: MapActivityUiState { activityViewModel.uiState }
    private var pending: PendingRequestUiState { pendingViewModel.uiState }

    var body: some View {
        VStack(spacing: 0) {
            MapOverlayTopBar(title: "지도 관리", onBack: onBack)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if canReviewRequests {
                        ForEach(pending.requests) { request in
                            PendingRequestCard(
                                request: request,
                                timeAgo: activityViewModel.relativeTime(of: request.requestedAt),
                                // 처리 중에는 잠근다. 두 번 눌러도 서버에는 한 번만 간다.
                                actionEnabled: !pending.processing,
                                onAccept: { pendingViewModel.approve(placeID: request.id) },
                                onReject: { pendingViewModel.reject(placeID: request.id) }
                            )
                            .padding(.bottom, 20)
                        }
                    }
                    Text("활동 내역")
                        .moaTextStyle(typography.subtitle1)
                        .foregroundStyle(colors.textNormal)
                        .padding(.bottom, 20)
                    logs
                }
                .padding(EdgeInsets(top: 20, leading: 20, bottom: 32, trailing: 20))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.backgroundSecondary)
        // 뒤에 깔린 지도로 터치가 새지 않게 한다.
        .contentShape(Rectangle())
        .task {
            activityViewModel.loadOnce()
            // 볼 수 없는 목록을 받아 오는 통신을 남기지 않는다.
            if canReviewRequests { pendingViewModel.loadOnce() }
        }
        .moaSnackbar($notice)
        // 처리 실패가 조회 실패보다 앞선다. 버튼을 누른 직후라 답을 기다리고 있다.
        .onChange(of: pending.actionErrorMessage, initial: true) { _, message in
            guard let message else { return }
            notice = message
            pendingViewModel.consumeActionError()
        }
        .onChange(of: pending.errorMessage, initial: true) { _, message in
            guard let message, canReviewRequests else { return }
            notice = message
            pendingViewModel.consumeLoadError()
        }
    }

    @ViewBuilder
    private var logs: some View {
        if activity.loading {
            notice { ProgressView() }
        } else if let message = activity.errorMessage {
            notice {
                VStack(spacing: 4) {
                    Text(message)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAssistive)
                        .multilineTextAlignment(.center)
                    // 요청 목록에는 재시도 자리가 따로 없어 함께 다시 읽는다.
                    Button("다시 시도") {
                        activityViewModel.retry()
                        if canReviewRequests { pendingViewModel.retry() }
                    }
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textNormal)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                }
            }
        } else if activity.activities.isEmpty {
            notice {
                Text("아직 활동 내역이 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
            }
        } else {
            ForEach(Array(activity.activities.enumerated()), id: \.offset) { index, item in
                MapLogItem(
                    activity: item,
                    timeAgo: activityViewModel.relativeTime(of: item.occurredAt),
                    hasLineAbove: index > 0,
                    hasLineBelow: index < activity.activities.count - 1
                )
            }
        }
    }

    private func notice(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
    }
}

private struct PendingRequestCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let request: PendingPlace
    let timeAgo: String
    let actionEnabled: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                LogAuthor(name: request.requesterName ?? MapLogText.unknownUser, imageURL: request.requesterImageURL)
                Spacer()
                LogTime(text: timeAgo)
            }
            Text(MapLogText.message(for: request))
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                // 아바타 폭만큼 들여써서 사용자명 아래로 문장이 이어지게 한다.
                .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 0))
            HStack(spacing: 4) {
                actionButton("수락", color: MoaMapPrimitiveColors.blue500, action: onAccept)
                actionButton("거절", color: MoaMapPrimitiveColors.gray200, action: onReject)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 4)
    }

    private func actionButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .moaTextStyle(typography.button2)
                .foregroundStyle(colors.textWhite)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(color, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!actionEnabled)
    }
}

/// 활동 한 건. 왼쪽 세로선에 종류별 색 점이 찍힌다.
private struct MapLogItem: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let activity: MapActivity
    let timeAgo: String
    let hasLineAbove: Bool
    let hasLineBelow: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            rail
                .padding(.horizontal, 8)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    LogAuthor(name: activity.actorName ?? MapLogText.unknownUser, imageURL: activity.actorImageURL)
                    LogTime(text: timeAgo)
                }
                Text(MapLogText.message(for: activity))
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textNormal)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
                    .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(MoaMapPrimitiveColors.gray50, lineWidth: 1) }
            }
            .padding(.bottom, 20)
        }
        .accessibilityElement(children: .combine)
    }

    /// 점을 사용자명 줄 높이에 맞춘다. 위 선이 없는 첫 항목도 같은 자리에 놓여야 한다.
    private var rail: some View {
        VStack(spacing: 0) {
            line.frame(height: 8).opacity(hasLineAbove ? 1 : 0)
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
            if hasLineBelow {
                line.frame(maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var line: some View {
        Rectangle().fill(MoaMapPrimitiveColors.gray50).frame(width: 1)
    }

    private var dotColor: Color {
        switch activity.type {
        case .placeAdded: MoaMapPrimitiveColors.blue500
        case .placeRemoved: MoaMapPrimitiveColors.gray400
        case .reviewCreated: MoaMapPrimitiveColors.yellow500
        }
    }
}

private struct LogAuthor: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let name: String
    let imageURL: URL?

    var body: some View {
        HStack(spacing: 4) {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                MoaMapPrimitiveColors.blue50
            }
            .frame(width: 24, height: 24)
            .clipShape(Circle())
            .accessibilityHidden(true)
            Text(name)
                .moaTextStyle(typography.caption0)
                .foregroundStyle(colors.textNormal)
        }
    }
}

private struct LogTime: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let text: String

    var body: some View {
        Text(text)
            .moaTextStyle(typography.caption2)
            .foregroundStyle(colors.textAlternative)
    }
}
