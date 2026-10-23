import SwiftUI

/// 로그 탭 게시물 상세. 지도 상세 위에 검은 막을 덮고 크게 펼친 카드, 그 아래 댓글, 맨 아래 입력 줄을 띄운다.
/// 닫기는 X 와 검은 막이다. 입력 줄의 사진 + 는 서버가 댓글 사진을 받지 않아 뺐다.
struct MapPostDetailView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: MapPostDetailViewModel
    let post: MapPost
    let dateLabel: String?
    /// 지도 멤버. 아니면 입력칸을 막고 참여 안내를 띄운다.
    let canComment: Bool

    @State private var commentText = ""
    @FocusState private var commentFocused: Bool

    private static let closeButtonColor = Color(argb: 0xFF3E_3E3F)
    private static let bottomID = "bottom"
    private static let cardID = "card"

    private var state: MapPostDetailUiState { viewModel.uiState }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MoaMapPrimitiveColors.transparentBlack
                .ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        // 카드와 댓글 사이 16. 목록 간격 4 에 12 를 더한다.
                        ExpandedPostCard(post: post, dateLabel: dateLabel)
                            .onTapGesture { commentFocused = false }
                            .id(Self.cardID)
                            .padding(.bottom, 12)
                        comments
                        Color.clear.frame(height: 1).id(Self.bottomID)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 55)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                // 카드·말풍선·입력 줄 밖을 누르면 닫는다. 안쪽은 각자 탭을 받아 여기까지 오지 않는다.
                // 댓글을 쓰는 중이면 닫지 않고 키보드만 내린다.
                .onTapGesture {
                    if commentFocused { commentFocused = false } else { viewModel.close() }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) { inputBar }
                // 키보드가 올라오면 카드 아래 끝이 입력 줄 바로 위에 오도록 올린다. 그대로 두면 카드 사진이 키보드에 가린다.
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    guard commentFocused else { return }
                    withAnimation { proxy.scrollTo(Self.cardID, anchor: .bottom) }
                }
                .onChange(of: state.sentCount) {
                    // 남겼으면 입력칸을 비우고 내 댓글이 보이게 맨 아래로 내린다.
                    commentText = ""
                    withAnimation { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
            }
            closeButton
                .padding(.leading, 14)
                .padding(.top, 3)
        }
    }

    @ViewBuilder
    private var comments: some View {
        switch state.comments {
        case .loading:
            notice { ProgressView().tint(MoaMapPrimitiveColors.white) }
        case .failed(let message):
            notice {
                VStack(spacing: 12) {
                    Text(message)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textWhite)
                        .multilineTextAlignment(.center)
                    Button("다시 시도", action: viewModel.retry)
                        .moaTextStyle(typography.button2)
                        .foregroundStyle(colors.textWhite)
                        .buttonStyle(.plain)
                }
            }
        case .loaded(let comments) where comments.isEmpty:
            notice {
                Text("아직 댓글이 없어요")
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textWhite)
            }
        case .loaded(let comments):
            ForEach(comments) { comment in
                MapPostCommentRow(comment: comment, mine: comment.authorID == state.myUserID) { commentFocused = false }
            }
        }
    }

    private func notice(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .frame(height: 200)
    }

    private var inputBar: some View {
        let enabled = canComment && state.commentsReady && !state.sending
        return VStack(alignment: .leading, spacing: 8) {
            CommentInputRow(
                text: Binding(
                    get: { commentText },
                    set: { commentText = String($0.prefix(MapPostDetailUiState.maxCommentLength)) }
                ),
                focused: $commentFocused,
                placeholder: canComment ? "댓글을 입력해주세요" : "지도에 참여하면 댓글을 남길 수 있어요",
                enabled: enabled,
                canSend: enabled && !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                sending: state.sending,
                onSend: { viewModel.send(commentText) }
            )
            if let message = state.sendErrorMessage {
                Text(message)
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.statusAlert)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 70)
        .padding(.bottom, 30)
        .background {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.2), location: 0.46),
                    .init(color: .black.opacity(0.1), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        }
        .contentShape(Rectangle())
        .onTapGesture { commentFocused = false }
    }

    private var closeButton: some View {
        Button(action: viewModel.close) {
            Image("Icons/close")
                .renderingMode(.template)
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundStyle(MoaMapPrimitiveColors.white)
                .frame(width: 40, height: 40)
                .background(Self.closeButtonColor, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("닫기")
    }
}

/// 댓글 한 줄. 남의 댓글은 왼쪽에 작성자 사진·이름을 위에 두고, 내 댓글은 오른쪽에 말풍선만 둔다.
private struct MapPostCommentRow: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let comment: MapPostComment
    let mine: Bool
    /// 말풍선을 누르면 닫지 않고 이것만 한다.
    let onTap: () -> Void

    /// 말풍선이 줄 끝까지 차면 내 것·남의 것이 구별되지 않는다.
    private static let bubbleMaxWidth: CGFloat = 280

    var body: some View {
        VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
            if !mine {
                HStack(spacing: 4) {
                    RemoteImage(url: comment.authorImageURL)
                        .frame(width: 18, height: 18)
                        .clipShape(Circle())
                        .accessibilityHidden(true)
                    Text(comment.authorName ?? "알 수 없는 사용자")
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(colors.textWhite)
                }
            }
            // 여백 12 와 줄 높이 21 로 한 줄 말풍선이 45 다.
            Text(comment.content)
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                .padding(12)
                .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 16))
                .onTapGesture(perform: onTap)
                .frame(maxWidth: Self.bubbleMaxWidth, alignment: mine ? .trailing : .leading)
        }
        .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    let viewModels = MapDetailViewModels.preview(mapID: 1)
    let post = MapPost(id: 1, authorID: 2, content: "성수 카페 다녀왔어요", imageURLs: [], placeNames: ["블루보틀"], createdAt: nil)
    MapPostDetailView(viewModel: viewModels.postDetail, post: post, dateLabel: "2026. 10. 15.", canComment: true)
        .task { viewModels.postDetail.open(post) }
}
#endif
