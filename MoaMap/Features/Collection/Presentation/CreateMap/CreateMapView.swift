import SwiftUI
import UIKit

struct CreateMapView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CreateMapViewModel
    @State private var showsSourceMenu = false
    /// 고를 때 한 번만 풀어 둔다. 입력할 때마다 사진을 다시 풀지 않게 한다.
    @State private var previewImage: UIImage?
    /// 화면만 있다. 서버에 보내는 값이 아니다.
    @State private var allowsURLImport = false
    /// TextField에 붙는 입력 중인 글자. 확정된 결과는 `tagInput`으로 다시 받는다.
    @State private var tagDraft = ""
    @FocusState private var focusedField: Field?
    private let onCreated: () -> Void

    private enum Field { case name, description, tag }

    init(viewModel: CreateMapViewModel, onCreated: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onCreated = onCreated
    }

    var body: some View {
        let state = viewModel.uiState
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(spacing: 20) {
                    MapPhotoField(image: previewImage) {
                        // 올리는 중에는 열지 않는다. 고른 사진이 반영되지 않는다.
                        guard !state.isSubmitting else { return }
                        focusedField = nil
                        showsSourceMenu = true
                    }
                    CreateMapInputField(
                        label: "지도 이름", required: true,
                        text: binding(state.name, viewModel.updateName), placeholder: "지도 이름을 입력해주세요"
                    )
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .description }
                    CreateMapInputField(
                        label: "지도 설명",
                        text: binding(state.description, viewModel.updateDescription), placeholder: "지도 설명을 입력해주세요"
                    )
                    .focused($focusedField, equals: .description)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .tag }
                    visibilitySection(state.visibility)
                    // Binding setter 안에서 값을 비우면 TextField가 화면에 반영하지 않는다.
                    // 그래서 입력은 그대로 받아 두고, 확정과 되돌려 받기는 onChange에서 한다.
                    CreateMapInputField(
                        label: "태그",
                        text: $tagDraft, placeholder: "태그 입력 후 스페이스 또는 엔터"
                    ) {
                        if !state.tags.isEmpty {
                            FlowLayout(spacing: 4, lineSpacing: 4) {
                                ForEach(state.tags, id: \.self) { tag in
                                    TagChip(tag: tag) { viewModel.removeTag(tag) }
                                }
                            }
                        }
                    }
                    .focused($focusedField, equals: .tag)
                    .onChange(of: tagDraft) { _, draft in
                        // 확정 뒤 남은 값이 이전과 같아도 입력창은 맞춰야 한다. 빈 칸에 "카페 "를 붙여넣는 경우 등.
                        viewModel.updateTagInput(draft)
                        let remaining = viewModel.uiState.tagInput
                        if remaining != draft { tagDraft = remaining }
                    }
                    .onChange(of: state.tagInput, initial: true) { _, input in
                        if tagDraft != input { tagDraft = input }
                    }
                    .onChange(of: focusedField) { old, new in
                        // 엔터 없이 입력창을 벗어나도 입력 중이던 태그를 확정한다.
                        if old == .tag, new != .tag { viewModel.commitTag() }
                    }
                    .submitLabel(.done)
                    .onSubmit {
                        viewModel.commitTag()
                        // 이어서 태그를 더 넣을 수 있게 키보드를 유지한다.
                        focusedField = .tag
                    }
                    URLImportToggleRow(isOn: $allowsURLImport)
                    // 가져오기 흐름은 장소 가져오기 작업에서 연결한다.
                    ImportActionCard(
                        iconName: "map", iconTint: colors.secondary, title: "외부 지도", subtitle: "불러오기",
                        background: MoaMapPrimitiveColors.yellow50, titleColor: MoaMapPrimitiveColors.yellow800
                    )
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .moaSnackbar(errorMessage)
        }
        .safeAreaInset(edge: .bottom) {
            CreateMapSubmitButton(enabled: state.canSubmit, submitting: state.isSubmitting) {
                focusedField = nil
                viewModel.submit()
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .padding(.vertical, 13)
            // 스크롤한 내용이 버튼 뒤로 비치지 않게 한다.
            .background(colors.backgroundSecondary)
        }
        .imageSourcePicker(isPresented: $showsSourceMenu) { data, type in
            if let data { viewModel.selectImage(data: data, type: type) } else { viewModel.showImageLoadFailure() }
        }
        .overlay {
            if case .showingInviteCode(_, let inviteCode) = state.submit {
                MapInviteCodeDialog(
                    mapName: state.name, inviteCode: inviteCode, title: "프라이빗 지도가 만들어졌어요",
                    onDismiss: viewModel.dismissInviteCode
                )
            }
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: state.pickedImage?.selection) {
            previewImage = viewModel.uiState.pickedImage.flatMap { UIImage(data: $0.image.data) }
        }
        .onChange(of: state.submit) { _, submit in
            if case .done = submit { onCreated() }
        }
    }

    private var errorMessage: Binding<String?> {
        Binding(
            get: { viewModel.uiState.errorMessage },
            set: { if $0 == nil { viewModel.consumeError() } }
        )
    }

    private func binding(_ value: String, _ update: @escaping (String) -> Void) -> Binding<String> {
        Binding(get: { value }, set: update)
    }

    private var topBar: some View {
        ZStack {
            Text("새 지도 만들기")
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button { dismiss() } label: {
                    Image("Icons/arrow-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(colors.textNormal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")
                Spacer()
            }
            .padding(.leading, MoaMapDimens.screenHorizontalPadding - 6)
        }
        .frame(height: 58)
    }

    private func visibilitySection(_ selected: MapVisibility?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CreateMapLabel(text: "공개 범위", style: typography.subtitle1, required: true)
            HStack(spacing: 9) {
                VisibilityCard(
                    iconName: "language", title: "공개 지도", subtitle: "모두가 볼 수 있어요",
                    selected: selected == .public
                ) { viewModel.selectVisibility(.public) }
                VisibilityCard(
                    iconName: "lock", title: "프라이빗 지도", subtitle: "초대한 사람만 볼 수 있어요",
                    selected: selected == .private
                ) { viewModel.selectVisibility(.private) }
            }
        }
    }
}

#if DEBUG
#Preview {
    CreateMapView(viewModel: CreateMapViewModel(repository: PreviewCollectionRepository())) {}
}
#endif
