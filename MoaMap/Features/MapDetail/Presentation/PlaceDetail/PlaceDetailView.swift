import PhotosUI
import SwiftUI

/// 「나만의 지도에 추가」 버튼 상태. 결과 안내는 버튼 아래에 띄운다.
struct PersonalMapAction: Equatable {
    var adding = false
    var message: String?
    var failed = false
}

/// 장소 상세. 지도 화면 위를 덮는 한 장이다. 목록 시트 위에 시트를 또 겹치지 않는다.
struct PlaceDetailView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.openURL) private var openURL

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
    let onExternalLink: () -> Void
    let onAddToPersonalMap: () -> Void
    let onLike: () -> Void

    private var showsReactions: Bool { reviews != nil }

    @State private var reviewText = ""
    @State private var reviewPhoto: UploadImage?
    /// 밀어 버튼이 드러난 댓글. 한 번에 한 줄만 연다.
    @State private var openReviewID: Int64?
    @State private var deleteTargetID: Int64?
    @State private var showsSourceMenu = false
    @State private var showsGallery = false
    @State private var showsCamera = false
    @State private var photoItem: PhotosPickerItem?
    @State private var cameraAlert: CameraAlert?
    @FocusState private var composerFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    BackCloseControls(onBack: onBack, onClose: onClose)
                    header
                        .padding(.top, 20)
                    actions
                        .padding(.top, 12)
                    if let reviews {
                        Rectangle()
                            .fill(colors.lineNormal)
                            .frame(height: 0.5)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        PlaceReviewList(
                            state: reviews.uiState,
                            swipeEnabled: canWriteReview,
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
                            }
                        )
                    }
                }
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            if let reviews {
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.backgroundSecondary)
        // 뒤에 깔린 지도로 터치가 새지 않게 한다.
        .contentShape(Rectangle())
        .overlay {
            if showsSourceMenu { sourceMenu }
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
        .photosPicker(isPresented: $showsGallery, selection: $photoItem, matching: .images)
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { data in reviewPhoto = reviews?.preparePhoto(data: data, type: .jpeg) }
                .ignoresSafeArea()
        }
        .alert(cameraAlert?.title ?? "", isPresented: showsCameraAlert, presenting: cameraAlert) { alert in
            if alert == .denied {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                Button("취소", role: .cancel) {}
            } else {
                Button("확인", role: .cancel) {}
            }
        } message: { alert in
            Text(alert.message)
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                let data = try? await item.loadTransferable(type: Data.self)
                reviewPhoto = reviews?.preparePhoto(data: data, type: item.supportedContentTypes.first)
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

    private var sourceMenu: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { showsSourceMenu = false }
                .accessibilityHidden(true)
            ActionMenu(items: [
                ActionMenuItem(icon: "photo-camera", label: "카메라", action: openCamera),
                ActionMenuItem(icon: "gallery", label: "갤러리") {
                    showsSourceMenu = false
                    showsGallery = true
                }
            ])
            .accessibilityAction(.escape) { showsSourceMenu = false }
        }
    }

    private func openCamera() {
        showsSourceMenu = false
        guard CameraPicker.isAvailable else {
            cameraAlert = .unavailable
            return
        }
        Task {
            if await CameraPicker.requestAccess() { showsCamera = true } else { cameraAlert = .denied }
        }
    }

    private var showsCameraAlert: Binding<Bool> {
        Binding(get: { cameraAlert != nil }, set: { if !$0 { cameraAlert = nil } })
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            PhotoThumbnail(imageURL: place.photoURL, size: 107)
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .moaTextStyle(typography.subtitle1)
                            .foregroundStyle(colors.textNormal)
                            .lineLimit(1)
                        if !place.categoryLabel.isEmpty { categoryTag }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if showsReactions {
                        HStack(spacing: 8) {
                            Button(action: onLike) {
                                iconAction(
                                    icon: place.liked ? "favorite-filled" : "favorite-outline",
                                    tint: place.liked ? colors.statusAlert : MoaMapPrimitiveColors.gray100,
                                    label: "\(place.likeCount)"
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(place.liked ? "하트 취소하기" : "하트 누르기")
                            .accessibilityValue("\(place.likeCount)")
                            // 신고는 아직 기능이 없다. 누를 수 있는 것처럼 보이지 않게 버튼으로 두지 않는다.
                            iconAction(icon: "emergency", tint: colors.textNormal, label: "신고하기")
                                .accessibilityHidden(true)
                        }
                    }
                }
                if !place.description.isEmpty {
                    Text(place.description)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAlternative)
                }
                HStack(spacing: 2) {
                    Image("Icons/location")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .accessibilityHidden(true)
                    Text(place.address)
                        .moaTextStyle(typography.body2)
                        .lineLimit(1)
                }
                .foregroundStyle(colors.textAlternative)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
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

    private func iconAction(icon: String, tint: Color, label: String) -> some View {
        VStack(spacing: 2) {
            Image("Icons/\(icon)")
                .renderingMode(.template)
                .resizable()
                .frame(width: 24, height: 24)
                .foregroundStyle(tint)
            Text(label)
                .moaTextStyle(typography.caption0)
                .foregroundStyle(colors.textAlternative)
        }
        .contentShape(Rectangle())
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
                    "외부 링크로 가기", icon: "arrow-outward",
                    background: MoaMapPrimitiveColors.yellow100, foreground: MoaMapPrimitiveColors.yellow800,
                    loading: false, action: onExternalLink
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
            .shadow(color: .black.opacity(0.04), radius: 4)
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
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                icon("arrow-left", size: 24, alignment: .leading)
            }
            .accessibilityLabel("뒤로가기")
            Spacer()
            Button(action: onClose) {
                icon("close", size: 32, alignment: .trailing)
            }
            .accessibilityLabel("닫기")
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

#Preview {
    PlaceDetailView(
        place: MapPlace(
            id: 1, name: "커피나무", address: "서울 성동구 성수이로 12", latitude: 0, longitude: 0, photoURL: nil,
            description: "따뜻한 분위기에서 스페셜티 커피를 즐길 수 있는 카페", category: "음식점 > 카페 > 커피전문점",
            likeCount: 12, liked: true
        ),
        personalMapAction: PersonalMapAction(message: "나만의 지도에 추가했어요"),
        reviews: nil,
        canWriteReview: true,
        onBack: {}, onClose: {}, onExternalLink: {}, onAddToPersonalMap: {}, onLike: {}
    )
}
