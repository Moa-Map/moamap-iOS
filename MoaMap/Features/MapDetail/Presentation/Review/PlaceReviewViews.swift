import SwiftUI

/// 장소 상세 아래 댓글 목록. 로딩·오류·빈 상태는 같은 높이를 써서 상태가 바뀌어도 화면이 튀지 않는다.
struct PlaceReviewList: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let state: PlaceReviewUiState
    /// 내가 차단한 사람. 서버가 걸러 주기 전에도 바로 뺀다.
    let hiddenAuthorIDs: Set<Int64>
    /// false 면 꾹 눌러도 메뉴가 뜨지 않는다.
    let menuEnabled: Bool
    let relativeTime: (PlaceReview) -> String
    let onRetry: () -> Void
    let onDelete: (PlaceReview) -> Void
    let onBlock: (PlaceReview) -> Void
    let onReport: (PlaceReview) -> Void
    /// 첫 댓글(없으면 로딩·오류·빈 안내) 높이. 장소 상세가 반만 올라올 때 이만큼 보여 준다.
    var onFirstItemHeightChange: (CGFloat) -> Void = { _ in }

    private static let placeholderHeight: CGFloat = 140

    private var reviews: [PlaceReview] {
        state.reviews.filter { !hiddenAuthorIDs.contains($0.authorID) }
    }

    var body: some View {
        let reviews = reviews
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
        } else if reviews.isEmpty {
            placeholder {
                Text("아직 댓글이 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAssistive)
            }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(reviews) { review in
                    PlaceReviewRow(review: review, relativeTime: relativeTime(review))
                        // 시안처럼 메뉴는 댓글 위에 띄운다.
                        .longPressMenu(items: menuItems(for: review), edge: .top) {
                            PlaceReviewRow(review: review, relativeTime: relativeTime(review), highlighted: true)
                        }
                        .background {
                            // 맨 앞 댓글이 지워지면 다음 줄이 새로 재도록 맨 앞 줄에만 단다.
                            if review.id == reviews.first?.id {
                                Color.clear
                                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onFirstItemHeightChange($0) }
                            }
                        }
                }
            }
        }
    }

    /// 내 댓글은 삭제, 남의 댓글은 차단·신고. 누가 썼는지 모르면 띄우지 않는다.
    private func menuItems(for review: PlaceReview) -> [ActionMenuItem] {
        guard menuEnabled, state.myUserID != nil else { return [] }
        if review.isMine(state.myUserID) {
            return [ActionMenuItem(icon: "trash", label: "삭제하기") { onDelete(review) }]
        }
        return [
            ActionMenuItem(icon: "block", label: "차단하기") { onBlock(review) },
            ActionMenuItem(icon: "report", label: "신고하기", isDestructive: true) { onReport(review) }
        ]
    }

    private func placeholder(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: Self.placeholderHeight)
            .onAppear { onFirstItemHeightChange(Self.placeholderHeight) }
    }
}

struct PlaceReviewRow: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let review: PlaceReview
    let relativeTime: String
    /// 꾹 눌러 메뉴를 띄운 줄. 구분선 대신 카드로 띄운다.
    var highlighted = false

    /// 사진이 없는 사람은 시안의 빈 프로필 자리를 둔다.
    @ViewBuilder
    private var avatar: some View {
        if let url = review.authorImageURL {
            RemoteImage(url: url)
        } else {
            Image("photo-placeholder").resizable().scaledToFill()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                avatar
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
                    .frame(width: 28, height: 28)
                    .background(MoaMapPrimitiveColors.white, in: Circle())
                    .overlay { Circle().strokeBorder(colors.lineNormal, lineWidth: 1) }
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
                            .foregroundStyle(colors.textAssistive)
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
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(.top, 4)
                        .accessibilityLabel("댓글 사진")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
            if !highlighted {
                Rectangle()
                    .fill(colors.lineAlternative)
                    .frame(height: 1)
            }
        }
        .background { if highlighted { RoundedRectangle(cornerRadius: 8).fill(colors.backgroundSecondary) } }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .combine)
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
    let focused: FocusState<Bool>.Binding
    let photo: UploadImage?
    let onAddPhoto: () -> Void
    let onRemovePhoto: () -> Void
    let onSubmit: () -> Void

    private var inputEnabled: Bool { canWrite && !state.submitting }
    private var canAddPhoto: Bool { inputEnabled && photo == nil }
    private var canSend: Bool {
        inputEnabled && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || photo != nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let photo { draftPhoto(photo) }
            CommentInputRow(
                text: $text,
                focused: focused,
                placeholder: canWrite ? "이 장소에 대한 경험을 공유해주세요" : "지도에 참여하면 댓글을 남길 수 있어요",
                enabled: inputEnabled,
                canSend: canSend,
                sending: state.submitting,
                onSend: onSubmit
            ) {
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
            }
            if let message = state.submitErrorMessage {
                Text(message)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.statusAlert)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        // 홈 표시줄·키보드 바로 위에 붙인다.
        .padding(.bottom, 8)
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
                        .frame(width: 18, height: 18)
                        .foregroundStyle(MoaMapPrimitiveColors.white)
                        .frame(width: 24, height: 24)
                        .background(MoaMapPrimitiveColors.black.opacity(0.6), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(2)
                .accessibilityLabel("첨부한 사진 빼기")
            }
        }
    }
}
