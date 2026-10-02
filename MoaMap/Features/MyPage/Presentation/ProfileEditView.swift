import PhotosUI
import SwiftUI

struct ProfileEditView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var viewModel: ProfileEditViewModel
    @State private var photoItem: PhotosPickerItem?
    @State private var showsSourceMenu = false
    @State private var showsGallery = false
    @State private var showsCamera = false
    @State private var cameraAlert: CameraAlert?
    @FocusState private var focusedField: Field?
    /// 저장이 끝나면 서버가 확정한 프로필을 넘긴다. 다른 화면의 이름을 맞추는 데 쓴다.
    private let onSaved: (MyProfile) -> Void

    private enum Field { case nickname, introduction }

    init(viewModel: ProfileEditViewModel, onSaved: @escaping (MyProfile) -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 40) {
                    profileImage
                    content
                }
                .padding(.top, 26)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { saveButton }
        .overlayPreferenceValue(ProfileImageAnchorKey.self) { anchor in
            if showsSourceMenu, let anchor {
                GeometryReader { proxy in
                    let image = proxy[anchor]
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { showsSourceMenu = false }
                            .accessibilityHidden(true)
                        // 카메라 버튼 아래 8 에, 오른쪽 끝을 사진 칸 끝에 맞춘다.
                        sourceMenu
                            .offset(x: image.maxX - ActionMenu.width, y: image.maxY + 8)
                    }
                }
            }
        }
        .photosPicker(isPresented: $showsGallery, selection: $photoItem, matching: .images)
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { data in viewModel.selectImage(data: data, type: .jpeg) }
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
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .toolbar(.hidden, for: .navigationBar)
        .task { if viewModel.uiState.load == .loading, viewModel.loadTask == nil { viewModel.load() } }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            photoItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.selectImage(data: data, type: item.supportedContentTypes.first)
                } else {
                    viewModel.showImageLoadFailure()
                }
            }
        }
        .onChange(of: viewModel.uiState.saved) { _, saved in
            guard saved, let profile = viewModel.savedProfile else { return }
            onSaved(profile)
            dismiss()
        }
        .alert("저장하지 못했어요", isPresented: showsError) {
            Button("확인", role: .cancel) { viewModel.consumeError() }
        } message: {
            Text(viewModel.uiState.errorMessage ?? "")
        }
    }

    private var showsError: Binding<Bool> {
        Binding(
            get: { viewModel.uiState.errorMessage != nil },
            set: { if !$0 { viewModel.consumeError() } }
        )
    }

    private var topBar: some View {
        ZStack {
            Text("프로필 편집")
                .moaTextStyle(typography.title3)
                .foregroundStyle(MoaMapPrimitiveColors.black)
            HStack {
                Button { dismiss() } label: {
                    Image("Icons/arrow-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(colors.textNormal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")
                .padding(.leading, 10)
                Spacer()
            }
        }
        .frame(height: 52)
    }

    private var profileImage: some View {
        let enabled = !viewModel.uiState.saving
        return ZStack(alignment: .bottomTrailing) {
            imageContent
                .frame(width: 120, height: 120)
                .background(MoaMapPrimitiveColors.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 5)
                .accessibilityLabel("프로필 이미지")

            Button { showsSourceMenu = true } label: {
                Image("Icons/photo-camera")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(MoaMapPrimitiveColors.white)
                    .frame(width: 40, height: 40)
                    // 저장 중에는 바꿔도 반영되지 않아 눌리지 않는 색으로 보여 준다.
                    .background(enabled ? colors.primary : MoaMapPrimitiveColors.gray100, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .accessibilityLabel("프로필 사진 변경")
        }
        .anchorPreference(key: ProfileImageAnchorKey.self, value: .bounds) { $0 }
    }

    private var sourceMenu: some View {
        ActionMenu(items: [
            ActionMenuItem(icon: "photo-camera", label: "카메라", action: openCamera),
            ActionMenuItem(icon: "gallery", label: "갤러리") {
                showsSourceMenu = false
                showsGallery = true
            }
        ])
        .accessibilityAction(.escape) { showsSourceMenu = false }
    }

    private func openCamera() {
        showsSourceMenu = false
        guard CameraPicker.isAvailable else {
            cameraAlert = .unavailable
            return
        }
        Task {
            if await CameraPicker.requestAccess() {
                showsCamera = true
            } else {
                cameraAlert = .denied
            }
        }
    }

    private var showsCameraAlert: Binding<Bool> {
        Binding(get: { cameraAlert != nil }, set: { if !$0 { cameraAlert = nil } })
    }

    @ViewBuilder
    private var imageContent: some View {
        if let picked = viewModel.uiState.pickedImage, let image = UIImage(data: picked.image.data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if case .loaded(_, let url?) = viewModel.uiState.load {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.clear
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.uiState.load {
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .moaTextStyle(typography.body2)
                    .foregroundStyle(colors.textAlternative)
                    .multilineTextAlignment(.center)
                Button("다시 시도") { viewModel.load() }
                    .moaTextStyle(typography.subtitle2)
                    .foregroundStyle(colors.primary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
        case .loaded:
            fields
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 20) {
            field("이름", minHeight: 45) {
                TextField(
                    "",
                    text: Binding(get: { viewModel.uiState.nickname }, set: { viewModel.updateNickname($0) }),
                    prompt: placeholder("이름을 작성해주세요")
                )
                .focused($focusedField, equals: .nickname)
                .submitLabel(.next)
                .onSubmit { focusedField = .introduction }
            }
            field("자기소개", optional: true, minHeight: 88) {
                // 두 줄이 넘으면 칸이 자라고, 여섯 줄부터는 칸 안에서 스크롤한다.
                TextField(
                    "",
                    text: Binding(get: { viewModel.uiState.introduction }, set: { viewModel.updateIntroduction($0) }),
                    prompt: placeholder("나를 소개하는 한마디를 입력해보세요"),
                    axis: .vertical
                )
                .lineLimit(1...6)
                .focused($focusedField, equals: .introduction)
            }
        }
        .padding(.horizontal, 18)
    }

    private func placeholder(_ text: String) -> Text {
        Text(text).foregroundStyle(colors.textAssistive)
    }

    private func field(
        _ label: String,
        optional: Bool = false,
        minHeight: CGFloat,
        @ViewBuilder input: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(label)
                    .moaTextStyle(typography.subtitle1)
                    .foregroundStyle(colors.textNormal)
                if optional {
                    Text("(선택)")
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAlternative)
                }
            }
            .frame(height: 26)

            input()
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textNormal)
                .tint(colors.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
                .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.08), radius: 2.5)
        }
    }

    private var saveButton: some View {
        let enabled = viewModel.uiState.canSave
        return Button { viewModel.save() } label: {
            ZStack {
                // 업로드까지 하면 수십 초가 걸릴 수 있어 눌렸다는 것을 계속 보여 준다.
                if viewModel.uiState.saving {
                    ProgressView().tint(colors.textWhite)
                } else {
                    Text("저장하기")
                        .moaTextStyle(typography.subtitle2)
                        .foregroundStyle(colors.textWhite)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 49)
            .background(enabled ? colors.primary : MoaMapPrimitiveColors.gray100, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 1.25)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

private nonisolated struct ProfileImageAnchorKey: PreferenceKey {
    static let defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

#if DEBUG
@MainActor
final class PreviewUserRepository: UserRepository {
    func fetchMyProfile() async throws -> MyProfile {
        MyProfile(id: 1, nickname: "모아맵", email: "moa@example.com", profileImageURL: nil, introduction: "지도 모으는 사람")
    }
    func uploadProfileImage(_ image: UploadImage) async throws -> String { "https://example.com/p.png" }
    func updateMyProfile(nickname: String, introduction: String, profileImageURL: String?) async throws -> MyProfile {
        try await fetchMyProfile()
    }
}

#Preview {
    NavigationStack {
        ProfileEditView(viewModel: ProfileEditViewModel(repository: PreviewUserRepository()), onSaved: { _ in })
    }
}
#endif
