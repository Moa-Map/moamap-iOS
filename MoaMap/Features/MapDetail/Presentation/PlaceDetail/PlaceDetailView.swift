import SwiftUI

/// 「나만의 지도에 추가」 버튼 상태. 결과 안내는 버튼 아래에 띄운다.
struct PersonalMapAction: Equatable {
    var adding = false
    var message: String?
    var failed = false
}

/// 장소 상세. 지도 위에 반쯤 올라온 시트로 열고, 끌어올리면 화면을 다 덮는다.
/// 댓글 입력은 끝까지 올렸을 때만 둔다.
struct PlaceDetailView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let place: MapPlace
    /// nil 이면 버튼을 띄우지 않는다. 나만의 지도를 보고 있을 때다.
    let personalMapAction: PersonalMapAction?
    /// nil 이면 하트·신고하기·댓글을 뺀다. 공식지도다.
    let reviews: PlaceReviewViewModel?
    /// 참여 중인 지도에만 댓글을 남길 수 있다.
    let canWriteReview: Bool
    let onBack: () -> Void
    /// 지도 상세에 처음 들어왔을 때의 화면으로 돌아간다.
    let onClose: () -> Void
    let onInstagram: () -> Void
    let onViewMap: () -> Void
    let onAddToPersonalMap: () -> Void
    let onLike: () -> Void
    /// 반만 올라온 시트의 높이가 처음 정해지면 한 번 알린다. 지도가 이만큼 가려진다.
    /// 댓글이 늦게 와 높이가 바뀌어도 다시 알리지 않는다. 그 사이 사용자가 옮긴 지도를 되돌리면 안 된다.
    var onCollapsedHeightSettle: (CGFloat) -> Void = { _ in }

    private var showsReactions: Bool { reviews != nil }

    private static let cornerRadius: CGFloat = 38
    /// 반만 올라온 시트에서 마지막으로 보이는 칸 아래 여백.
    private static let peekBottomGap: CGFloat = 12
    private static let contentSpace = "placeDetailContent"
    private static let contentTopID = "placeDetailTop"

    @State private var expanded = false
    @GestureState private var dragOffset: CGFloat = 0
    /// 반만 올라온 시트의 높이를 정하는 치수.
    /// 상태 표시줄·홈 표시줄까지 친 화면의 절반. 홈 표시줄 위부터 잰다.
    @State private var halfScreenHeight: CGFloat = 0
    @State private var bottomInset: CGFloat = 0
    @State private var collapsedHeightSettled = false
    @State private var controlsHeight: CGFloat = 0
    @State private var actionsBottom: CGFloat = 0
    @State private var dividerBottom: CGFloat = 0
    @State private var firstReviewHeight: CGFloat = 0

    @State private var reviewText = ""
    @State private var reviewPhoto: UploadImage?
    /// 밀어 버튼이 드러난 댓글. 한 번에 한 줄만 연다.
    @State private var openReviewID: Int64?
    @State private var deleteTargetID: Int64?
    @State private var showsSourceMenu = false
    @FocusState private var composerFocused: Bool

    var body: some View {
        GeometryReader { proxy in
            // 끝까지 올리면 안전 영역을 다 채우고, 배경만 상태 표시줄 밑까지 칠한다.
            // 높이에 상태 표시줄을 더하면 시트가 그만큼 아래로 밀려 입력창이 잘린다.
            let fullHeight = proxy.size.height
            // 재기 전에는 화면 절반에서 시작한다.
            let collapsedHeight = min(collapsedHeight ?? fullHeight / 2, fullHeight)
            let base = expanded ? fullHeight : collapsedHeight
            let height = min(max(base - dragOffset, collapsedHeight), fullHeight)
            // 시안 1번은 버튼이 홈 표시줄 칸까지 내려온다. 그 칸만큼 시트를 늘려 아래로 내린다.
            let homeIndicatorOverlap = compact ? proxy.safeAreaInsets.bottom : 0
            let shape = UnevenRoundedRectangle(
                topLeadingRadius: expanded ? 0 : Self.cornerRadius,
                topTrailingRadius: expanded ? 0 : Self.cornerRadius
            )

            // 뒤를 어둡게 덮지 않는다. 시트 위로 보이는 지도는 그대로 만질 수 있다.
            ZStack(alignment: .bottom) {
                sheet
                    .frame(height: height + homeIndicatorOverlap, alignment: .top)
                    .clipShape(shape)
                    .background(alignment: .top) {
                        shape
                            .fill(colors.backgroundSecondary)
                            .shadow(color: .black.opacity(0.18), radius: 18.75, y: 15)
                            .ignoresSafeArea(edges: expanded ? [.top, .bottom] : .bottom)
                    }
                    .offset(y: homeIndicatorOverlap)
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .onGeometryChange(for: CGFloat.self) {
            ($0.size.height + $0.safeAreaInsets.top + $0.safeAreaInsets.bottom) / 2 - $0.safeAreaInsets.bottom
        } action: { halfScreenHeight = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomInset = $0 }
        .animation(.easeOut(duration: 0.25), value: expanded)
        .animation(.easeOut(duration: 0.25), value: collapsedHeight)
        .onChange(of: collapsedHeight) { _, height in
            guard let height, !collapsedHeightSettled else { return }
            collapsedHeightSettled = true
            onCollapsedHeightSettle(height)
        }
        .imageSourcePicker(isPresented: $showsSourceMenu, darkMenu: true) { data, type in
            reviewPhoto = reviews?.preparePhoto(data: data, type: type)
        }
        .overlay {
            if let id = deleteTargetID, let reviews {
                MoaMapConfirmDialog(
                    title: "댓글을 삭제하시겠습니까?",
                    message: "삭제한 댓글은 되돌릴 수 없습니다",
                    dismissText: "취소하기",
                    dismissColor: MoaMapPrimitiveColors.gray100,
                    confirmText: "삭제",
                    onConfirm: {
                        deleteTargetID = nil
                        reviews.delete(reviewID: id)
                    },
                    onDismiss: { deleteTargetID = nil }
                )
            }
        }
        .onChange(of: reviews?.uiState.editingReviewID) { _, editingID in
            // 고치기 시작하면 원래 글을 채우고 고른 사진은 뺀다. 사진은 고치지 않는다.
            if let editing = reviews?.uiState.editingReview, editing.id == editingID {
                reviewText = editing.content
                reviewPhoto = nil
                composerFocused = true
            } else {
                reviewText = ""
            }
        }
        .onChange(of: reviews?.uiState.submittedCount) {
            reviewText = ""
            reviewPhoto = nil
        }
    }

    /// 반만 올라온 시트의 높이. 홈 표시줄 위부터 잰다.
    /// 사진이 있으면 시안 1번대로 화면 절반이고, 버튼까지 들어가게 줄인 배치를 쓴다.
    /// 화면이 작아 절반에 버튼이 다 안 들어가면 버튼까지 늘린다. 홈 표시줄 칸까지는 내려도 된다.
    /// 사진이 없으면 댓글 한 개까지 보인다. 댓글이 없는 공식지도는 버튼까지다.
    private var collapsedHeight: CGFloat? {
        guard controlsHeight > 0, actionsBottom > 0 else { return nil }
        let toActions = controlsHeight + actionsBottom + Self.peekBottomGap
        if place.photoURL != nil {
            guard halfScreenHeight > 0 else { return nil }
            return max(halfScreenHeight, toActions - bottomInset)
        }
        var contentBottom = actionsBottom
        if reviews != nil {
            guard firstReviewHeight > 0 else { return nil }
            contentBottom = dividerBottom + firstReviewHeight
        }
        return controlsHeight + contentBottom + Self.peekBottomGap
    }

    /// 위로 끌면 끝까지 펼치고, 아래로 끌면 반으로 접는다.
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .updating($dragOffset) { value, state, _ in state = value.translation.height }
            .onEnded { value in
                let predicted = value.predictedEndTranslation.height
                if predicted < -80 { expanded = true } else if predicted > 80 { expanded = false }
            }
    }

    private var sheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if !expanded {
                    SheetGrabber()
                        .frame(height: 16)
                        .onTapGesture { expanded = true }
                        .accessibilityLabel("장소 상세 펼치기")
                        .accessibilityAddTraits(.isButton)
                }
                // 끝까지 올리면 처음 화면으로 가는 × 는 뺀다.
                BackCloseControls(onBack: onBack, onClose: expanded ? nil : onClose)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                if !expanded { controlsHeight = height }
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)

            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 0) {
                        header
                            .id(Self.contentTopID)
                        actions
                            .onGeometryChange(for: CGFloat.self) {
                                $0.frame(in: .named(Self.contentSpace)).maxY
                            } action: { actionsBottom = $0 }
                            .padding(.top, 12)
                        if let reviews {
                            Rectangle()
                                .fill(colors.lineNormal)
                                .frame(height: 0.5)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .onGeometryChange(for: CGFloat.self) {
                                    $0.frame(in: .named(Self.contentSpace)).maxY
                                } action: { dividerBottom = $0 }
                            PlaceReviewList(
                                state: reviews.uiState,
                                // 반만 올라온 동안의 끌기는 시트를 올리는 데 쓴다.
                                swipeEnabled: canWriteReview && expanded,
                                relativeTime: reviews.relativeTime(of:),
                                openReviewID: $openReviewID,
                                onRetry: reviews.retry,
                                onEdit: { id in
                                    openReviewID = nil
                                    reviews.startEdit(reviewID: id)
                                },
                                onDelete: { id in
                                    openReviewID = nil
                                    deleteTargetID = id
                                },
                                onFirstItemHeightChange: { firstReviewHeight = $0 }
                            )
                        }
                    }
                    .padding(.bottom, 16)
                    .coordinateSpace(.named(Self.contentSpace))
                }
                .scrollDismissesKeyboard(.interactively)
                // 반만 올라온 동안은 목록 대신 시트가 끌려 올라온다.
                .scrollDisabled(!expanded)
                .gesture(dragGesture, including: expanded ? .subviews : .all)
                .onChange(of: expanded) { _, isExpanded in
                    // 내려 둔 채로 접으면 반만 보이는 칸에 댓글 중간이 걸린다. 접히면 스크롤도 막혀 위로 못 간다.
                    if !isExpanded { scroll.scrollTo(Self.contentTopID, anchor: .top) }
                }
            }
            if expanded, let reviews {
                PlaceReviewComposer(
                    state: reviews.uiState,
                    canWrite: canWriteReview,
                    text: $reviewText,
                    photo: reviewPhoto,
                    onAddPhoto: {
                        composerFocused = false
                        showsSourceMenu = true
                    },
                    onRemovePhoto: { reviewPhoto = nil },
                    // 입력은 여기서 비우지 않는다. 서버가 받아들였는지는 아직 모른다.
                    onSubmit: { reviews.submit(content: reviewText, photo: reviewPhoto) },
                    onCancelEdit: reviews.cancelEdit
                )
                .focused($composerFocused)
                // 사진 메뉴를 입력창 바로 위 왼쪽에 띄운다.
                .overlay(alignment: .topLeading) {
                    Color.clear
                        .frame(width: ActionMenu.width, height: 0)
                        .padding(EdgeInsets(top: 4, leading: 20, bottom: 0, trailing: 0))
                        .imageSourceMenuAnchor()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 뒤에 깔린 지도로 터치가 새지 않게 하고, 빈 곳을 누르면 키보드를 내린다.
        .contentShape(Rectangle())
        .onTapGesture { composerFocused = false }
    }

    /// 사진 있는 장소를 반만 올렸을 때. 시안 1번처럼 설명·신고하기를 빼고 하트를 태그 아래에 붙인다.
    private var compact: Bool { !expanded && place.photoURL != nil }

    private var header: some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 20) {
            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(place.name)
                        .moaTextStyle(typography.subtitle1)
                        .foregroundStyle(colors.textNormal)
                        .lineLimit(1)
                    // 주소는 태그 옆에 잇는다. 태그가 없으면 주소만 둔다.
                    HStack(spacing: 4) {
                        if !place.categoryLabel.isEmpty { categoryTag }
                        if !place.address.isEmpty {
                            Text(place.categoryLabel.isEmpty ? place.address : "· \(place.address)")
                                .moaTextStyle(typography.body2)
                                .foregroundStyle(colors.textAlternative)
                                .lineLimit(1)
                        }
                    }
                    if compact, showsReactions { likeButton }
                }
                .padding(.horizontal, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                if place.instagramURL != nil {
                    InstagramLinkButton(action: onInstagram)
                }
            }
            if place.photoURL != nil {
                AsyncImage(url: place.photoURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image("photo-placeholder").resizable().scaledToFill()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: compact ? 167 : 175)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .accessibilityHidden(true)
            }
            if !compact, !place.description.isEmpty || showsReactions {
                VStack(alignment: .leading, spacing: 8) {
                    if !place.description.isEmpty {
                        Text(place.description)
                            .moaTextStyle(typography.body2)
                            .foregroundStyle(colors.textAlternative)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if showsReactions {
                        HStack {
                            likeButton
                            Spacer()
                            // 신고는 아직 기능이 없다. 누를 수 있는 것처럼 보이지 않게 버튼으로 두지 않는다.
                            Text("신고하기")
                                .moaTextStyle(typography.body2)
                                .underline()
                                .foregroundStyle(colors.textAlternative)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        // 시안 1번은 사진과 버튼 사이가 12 다. 버튼 위 간격이 이미 12 라 아래 여백을 뺀다.
        .padding(.bottom, compact ? 0 : 8)
    }

    private var likeButton: some View {
        Button(action: onLike) {
            HStack(spacing: 0) {
                Image(place.liked ? "Icons/favorite-filled" : "Icons/favorite-outline")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .foregroundStyle(place.liked ? colors.statusAlert : MoaMapPrimitiveColors.gray100)
                Text("\(place.likeCount)")
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(colors.textAlternative)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(place.liked ? "하트 취소하기" : "하트 누르기")
        .accessibilityValue("\(place.likeCount)")
    }

    private var categoryTag: some View {
        Text(place.categoryLabel)
            .moaTextStyle(typography.caption0)
            .foregroundStyle(MoaMapPrimitiveColors.yellow900)
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(MoaMapPrimitiveColors.yellow50, in: Capsule())
            .overlay { Capsule().strokeBorder(MoaMapPrimitiveColors.yellow500, lineWidth: 1) }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let personalMapAction {
                    actionButton(
                        "나만의 지도에 추가", icon: "add",
                        background: MoaMapPrimitiveColors.blue500, foreground: MoaMapPrimitiveColors.white,
                        loading: personalMapAction.adding, action: onAddToPersonalMap
                    )
                }
                actionButton(
                    "지도 보기", icon: "map",
                    background: MoaMapPrimitiveColors.gray200, foreground: MoaMapPrimitiveColors.white,
                    loading: false, action: onViewMap
                )
            }
            if let message = personalMapAction?.message {
                Text(message)
                    .moaTextStyle(typography.caption0)
                    // 성공은 다른 안내와 같은 회색, 실패만 빨강으로 눈에 띄게 한다.
                    .foregroundStyle(personalMapAction?.failed == true ? colors.statusAlert : colors.textAssistive)
            }
        }
        .padding(.horizontal, 20)
    }

    private func actionButton(
        _ label: String, icon: String, background: Color, foreground: Color, loading: Bool, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if loading {
                    ProgressView()
                        .tint(foreground)
                        .frame(width: 20, height: 20)
                } else {
                    Image("Icons/\(icon)")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .accessibilityHidden(true)
                }
                Text(label)
                    .moaTextStyle(typography.button2)
                    .lineLimit(1)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(background, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(loading)
    }
}

/// 한 화면짜리 페이지 맨 위의 `←`·`×` 줄. 장소 상세와 장소 추가가 같이 쓴다.
struct BackCloseControls: View {
    @Environment(\.moaColors) private var colors

    let onBack: () -> Void
    /// nil 이면 `×` 를 뺀다.
    let onClose: (() -> Void)?

    var body: some View {
        HStack {
            Button(action: onBack) {
                icon("arrow-left", size: 24, alignment: .leading)
            }
            .accessibilityLabel("뒤로가기")
            Spacer()
            if let onClose {
                Button(action: onClose) {
                    icon("close", size: 32, alignment: .trailing)
                }
                .accessibilityLabel("닫기")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(colors.textNormal)
        .frame(height: 56)
        .padding(.horizontal, 20)
    }

    private func icon(_ name: String, size: CGFloat, alignment: Alignment) -> some View {
        Image("Icons/\(name)")
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
            .frame(width: 44, height: 44, alignment: alignment)
            .contentShape(Rectangle())
    }
}

/// 장소를 가져온 인스타그램 게시물로 가는 동그란 버튼.
private struct InstagramLinkButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("Icons/link-out")
                .resizable()
                .frame(width: 24, height: 24)
                .frame(width: 36, height: 36)
                .background {
                    ZStack {
                        RadialGradient(
                            stops: [
                                .init(color: Color(argb: 0xFFFF_DD55), location: 0.1),
                                .init(color: Color(argb: 0xFFFF_994A), location: 0.3),
                                .init(color: Color(argb: 0xFFFF_7644), location: 0.4),
                                .init(color: Color(argb: 0xFFFF_543E), location: 0.5),
                                .init(color: Color(argb: 0xFFF1_4D59), location: 0.625),
                                .init(color: Color(argb: 0xFFE4_4675), location: 0.75),
                                .init(color: Color(argb: 0xFFC8_37AB), location: 1)
                            ],
                            center: UnitPoint(x: 0.27, y: 1.08),
                            startRadius: 0,
                            endRadius: 35
                        )
                        // 왼쪽 위에 살짝 도는 보라빛.
                        RadialGradient(
                            colors: [Color(argb: 0x404F_39E4), .clear],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 18
                        )
                    }
                    .clipShape(Circle())
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("인스타그램 게시물 열기")
    }
}

#Preview {
    ZStack {
        MoaMapPrimitiveColors.blue50.ignoresSafeArea()
        PlaceDetailView(
            place: MapPlace(
                id: 1, name: "커피나무", address: "서울 성동구 성수이로 12", latitude: 0, longitude: 0, photoURL: nil,
                description: "따뜻한 분위기에서 스페셜티 커피를 즐길 수 있는 카페", category: "음식점 > 카페 > 커피전문점",
                likeCount: 12, liked: true, instagramURL: URL(string: "https://www.instagram.com/p/abc")
            ),
            personalMapAction: PersonalMapAction(message: "나만의 지도에 추가했어요"),
            reviews: nil,
            canWriteReview: true,
            onBack: {}, onClose: {}, onInstagram: {}, onViewMap: {}, onAddToPersonalMap: {}, onLike: {}
        )
    }
}
