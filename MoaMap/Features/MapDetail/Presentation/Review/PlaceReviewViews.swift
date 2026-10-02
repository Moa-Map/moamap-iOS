import SwiftUI

/// 장소 상세 아래 댓글 목록. 로딩·오류·빈 상태는 같은 높이를 써서 상태가 바뀌어도 화면이 튀지 않는다.
struct PlaceReviewList: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let state: PlaceReviewUiState
    /// 수정·삭제·신고는 지도 멤버만 할 수 있다. false 면 밀리지 않는다.
    let swipeEnabled: Bool
    let relativeTime: (PlaceReview) -> String
    @Binding var openReviewID: Int64?
    let onRetry: () -> Void
    let onEdit: (Int64) -> Void
    let onDelete: (Int64) -> Void

    private static let placeholderHeight: CGFloat = 140

    var body: some View {
        if state.loading {
            placeholder { ProgressView() }
        } else if let message = state.loadErrorMessage {
            placeholder {
                VStack(spacing: 12) {
                    Text(message)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAssistive)
                    Button(action: onRetry) {
                        Text("다시 시도")
                            .moaTextStyle(typography.button2)
                            .foregroundStyle(colors.textWhite)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(MoaMapPrimitiveColors.blue500, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        } else if state.reviews.isEmpty {
            placeholder {
                Text("아직 댓글이 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
            }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(state.reviews) { review in
                    SwipeRevealRow(
                        actions: actions(for: review),
                        open: Binding(
                            get: { openReviewID == review.id },
                            set: { open in
                                if open { openReviewID = review.id } else if openReviewID == review.id { openReviewID = nil }
                            }
                        )
                    ) {
                        PlaceReviewRow(review: review, relativeTime: relativeTime(review))
                    }
                }
            }
        }
    }

    /// 내 댓글은 수정·삭제, 남의 댓글은 신고. 신고는 사유를 정하기 전이라 아직 누를 수 없다.
    private func actions(for review: PlaceReview) -> [SwipeAction] {
        guard swipeEnabled else { return [] }
        if review.isMine(state.myUserID) {
            return [
                SwipeAction(label: "수정", color: MoaMapPrimitiveColors.gray200) { onEdit(review.id) },
                SwipeAction(label: "삭제", color: SwipeAction.dangerColor) { onDelete(review.id) }
            ]
        }
        return [SwipeAction(label: "신고", color: SwipeAction.dangerColor, action: nil)]
    }

    private func placeholder(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: Self.placeholderHeight)
    }
}

struct PlaceReviewRow: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let review: PlaceReview
    let relativeTime: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(MoaMapPrimitiveColors.black)
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(review.authorName ?? "이름 없는 사용자")
                            .moaTextStyle(typography.body2)
                            .foregroundStyle(colors.textNormal)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(relativeTime)
                            .moaTextStyle(typography.caption0)
                            .foregroundStyle(colors.textAlternative)
                    }
                    // 사진만 남긴 댓글은 빈 줄이 끼지 않게 통째로 뺀다.
                    if !review.content.isEmpty {
                        Text(review.content)
                            .moaTextStyle(typography.body1)
                            .foregroundStyle(colors.textNormal)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let url = review.imageURLs.first {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            MoaMapPrimitiveColors.gray50
                        }
                        .frame(width: 96, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.top, 4)
                        .accessibilityLabel("댓글 사진")
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            Rectangle()
                .fill(colors.lineAlternative)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 밀었을 때 드러나는 버튼. `action` 이 nil 이면 보이기만 하고 눌리지 않는다.
struct SwipeAction: Identifiable {
    /// 시안의 삭제·신고 빨강. 디자인 토큰에 없는 색이다.
    static let dangerColor = Color(red: 0xD9 / 255, green: 0x40 / 255, blue: 0x2F / 255)

    let label: String
    let color: Color
    let action: (() -> Void)?

    var id: String { label }
}

/// 왼쪽으로 밀면 오른쪽에 버튼이 드러나는 줄. 절반 넘게 밀고 놓으면 열린다.
struct SwipeRevealRow<Content: View>: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let actions: [SwipeAction]
    @Binding var open: Bool
    @ViewBuilder let content: () -> Content

    private var actionWidth: CGFloat { 72 }
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        if actions.isEmpty {
            content()
        } else {
            let reveal = actionWidth * CGFloat(actions.count)
            let offset = min(max((open ? -reveal : 0) + dragOffset, -reveal), 0)
            content()
                .frame(maxWidth: .infinity)
                // 밑의 버튼이 비치지 않게 화면 배경으로 덮는다.
                .background(colors.backgroundSecondary)
                .offset(x: offset)
                .background(alignment: .trailing) { buttons }
                .clipped()
                .contentShape(Rectangle())
                .onTapGesture { if open { open = false } }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .updating($dragOffset) { value, state, _ in
                            // 세로 스크롤과 겹치지 않게 가로로 민 것만 받는다.
                            if abs(value.translation.width) > abs(value.translation.height) { state = value.translation.width }
                        }
                        .onEnded { value in
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            let end = (open ? -reveal : 0) + value.translation.width
                            open = end < -reveal / 2
                        }
                )
                .animation(.easeOut(duration: 0.2), value: open)
                .accessibilityActions {
                    ForEach(actions) { action in
                        if let handler = action.action { Button(action.label, action: handler) }
                    }
                }
        }
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            ForEach(actions) { action in
                Button {
                    action.action?()
                } label: {
                    Text(action.label)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textWhite)
                        .frame(width: actionWidth)
                        .frame(maxHeight: .infinity)
                        .background(action.color)
                }
                .buttonStyle(.plain)
                .disabled(action.action == nil)
            }
        }
        .accessibilityHidden(true)
    }
}

/// 댓글 입력. 별점 없이 글과 사진 한 장을 남긴다. 목록과 함께 스크롤되지 않고 아래에 붙는다.
struct PlaceReviewComposer: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let state: PlaceReviewUiState
    /// false 면 참여 전이라 입력을 막는다.
    let canWrite: Bool
    @Binding var text: String
    let photo: UploadImage?
    let onAddPhoto: () -> Void
    let onRemovePhoto: () -> Void
    let onSubmit: () -> Void
    let onCancelEdit: () -> Void

    private var inputEnabled: Bool { canWrite && !state.submitting }
    private var editing: PlaceReview? { state.editingReview }
    private var canAddPhoto: Bool { inputEnabled && photo == nil && editing == nil }
    /// 사진이 있는 댓글은 글을 비워도 고칠 수 있다.
    private var canSend: Bool {
        inputEnabled && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photo != nil
            || editing?.imageURLs.isEmpty == false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if editing != nil {
                HStack {
                    Text("댓글 수정 중")
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(colors.textAlternative)
                    Spacer()
                    Button("취소", action: onCancelEdit)
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(colors.textNormal)
                        .buttonStyle(.plain)
                        .disabled(state.submitting)
                }
            }
            if let photo { draftPhoto(photo) }
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Button(action: onAddPhoto) {
                        Image("Icons/add")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .foregroundStyle(canAddPhoto ? colors.textNormal : colors.textDisable)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAddPhoto)
                    .accessibilityLabel("사진 첨부")
                    TextField(
                        "", text: $text,
                        prompt: Text(canWrite ? "이 장소에 대한 경험을 공유해주세요" : "지도에 참여하면 댓글을 남길 수 있어요")
                            .foregroundStyle(colors.textAssistive)
                    )
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textNormal)
                    .tint(MoaMapPrimitiveColors.blue500)
                    .disabled(!inputEnabled)
                    .submitLabel(.send)
                    .onSubmit { if canSend { onSubmit() } }
                }
                .padding(.leading, 8)
                .padding(.trailing, 16)
                .frame(height: 44)
                .background(MoaMapPrimitiveColors.white, in: Capsule())
                .shadow(color: .black.opacity(0.04), radius: 4)

                Button(action: onSubmit) {
                    ZStack {
                        if state.submitting {
                            ProgressView().tint(MoaMapPrimitiveColors.white)
                        } else {
                            Image("Icons/send")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 24, height: 24)
                                .foregroundStyle(MoaMapPrimitiveColors.white)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .background(canSend ? MoaMapPrimitiveColors.blue500 : MoaMapPrimitiveColors.gray200, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("댓글 보내기")
            }
            if let message = state.submitErrorMessage {
                Text(message)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.statusAlert)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    /// 보내기 전의 첨부 사진. 오른쪽 위를 눌러 뺀다.
    private func draftPhoto(_ photo: UploadImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image = UIImage(data: photo.data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    MoaMapPrimitiveColors.gray50
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("첨부한 사진")
            if inputEnabled {
                Button(action: onRemovePhoto) {
                    Image("Icons/close")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(MoaMapPrimitiveColors.white)
                        .frame(width: 20, height: 20)
                        .background(MoaMapPrimitiveColors.black.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(2)
                .accessibilityLabel("첨부한 사진 빼기")
            }
        }
    }
}
