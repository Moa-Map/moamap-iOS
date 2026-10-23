import SwiftUI
import UIKit

struct CreateMapView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: CreateMapViewModel
    @State private var showsPhotoPicker = false
    /// 고를 때 한 번만 풀어 둔다. 입력할 때마다 사진을 다시 풀지 않게 한다.
    @State private var previewImage: UIImage?
    /// 화면만 있다. 서버에 보내는 값이 아니다.
    @State private var allowsURLImport = false
    /// TextField에 붙는 입력 중인 글자. 확정된 결과는 `tagInput`으로 다시 받는다.
    @State private var tagDraft = ""
    @FocusState private var focusedField: Field?
    /// 외부 지도 가져오기 흐름을 열고, 편집을 마치면 받은 장소를 넘겨준다.
    private let onImportPlaces: (@escaping ([EditedPlace]) -> Void) -> Void
    /// 장소를 다 넣지 못했으면 그 안내를, 프라이빗 지도면 초대 코드를 넘긴다.
    private let onCreated: (_ notice: String?, _ invite: CreatedMapInvite?) -> Void

    private enum Field { case name, description, tag }

    init(
        viewModel: CreateMapViewModel,
        onImportPlaces: @escaping (@escaping ([EditedPlace]) -> Void) -> Void,
        onCreated: @escaping (_ notice: String?, _ invite: CreatedMapInvite?) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.onImportPlaces = onImportPlaces
        self.onCreated = onCreated
    }

    var body: some View {
        let state = viewModel.uiState
        VStack(spacing: 0) {
            topBar
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        MapPhotoField(image: previewImage, onRemove: viewModel.removeImage) {
                            // 올리는 중에는 열지 않는다. 고른 사진이 반영되지 않는다.
                            guard !state.isSubmitting else { return }
                            // 입력 중이면 바깥을 누른 것처럼 키보드만 내린다.
                            guard focusedField == nil else {
                                focusedField = nil
                                return
                            }
                            // 사진이 있으면 바꾸지 않는다. x 로 지운 뒤 다시 고른다.
                            guard previewImage == nil else { return }
                            showsPhotoPicker = true
                        }
                        CreateMapInputField(
                            label: "지도 이름", required: true,
                            text: binding(state.name, viewModel.updateName), placeholder: "지도 이름을 입력해주세요",
                            focused: focusedField == .name
                        )
                        .focused($focusedField, equals: .name)
                        .background { scrollTarget(.name) }
                        .submitLabel(.next)
                        .onSubmit { focusedField = .description }
                        CreateMapInputField(
                            label: "지도 설명",
                            text: binding(state.description, viewModel.updateDescription), placeholder: "지도 설명을 입력해주세요",
                            focused: focusedField == .description
                        )
                        .focused($focusedField, equals: .description)
                        .background { scrollTarget(.description) }
                        .submitLabel(.next)
                        .onSubmit { focusedField = .tag }
                        visibilitySection(state.visibility)
                        // Binding setter 안에서 값을 비우면 TextField가 화면에 반영하지 않는다.
                        // 그래서 입력은 그대로 받아 두고, 확정과 되돌려 받기는 onChange에서 한다.
                        CreateMapInputField(
                            label: "태그",
                            text: $tagDraft, placeholder: "태그 입력 후 스페이스 또는 엔터",
                            focused: focusedField == .tag
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
                        .background { scrollTarget(.tag) }
                        .onChange(of: tagDraft) { _, draft in
                            // 확정 뒤 남은 값이 이전과 같아도 입력창은 맞춰야 한다. 빈 칸에 "카페 "를 붙여넣는 경우 등.
                            viewModel.updateTagInput(draft)
                            let remaining = viewModel.uiState.tagInput
                            if remaining != draft { tagDraft = remaining }
                        }
                        .onChange(of: state.tagInput, initial: true) { _, input in
                            if tagDraft != input { tagDraft = input }
                        }
                        .submitLabel(.done)
                        .onSubmit {
                            // 엔터 순간에는 마지막 글자가 아직 tagInput에 오지 않았을 수 있다. 입력창 값으로 다음 차례에 확정한다.
                            Task { @MainActor in commitTagDraft() }
                            // 이어서 태그를 더 넣을 수 있게 키보드를 유지한다.
                            focusedField = .tag
                        }
                        URLImportToggleRow(isOn: $allowsURLImport)
                        ImportActionCard(
                            iconName: "map", iconTint: colors.secondary, title: "외부 지도",
                            subtitle: state.importedPlaces.isEmpty ? "불러오기" : "\(state.importedPlaces.count)곳 불러옴",
                            background: MoaMapPrimitiveColors.yellow50, titleColor: MoaMapPrimitiveColors.yellow800
                        ) {
                            guard !state.isSubmitting else { return }
                            focusedField = nil
                            onImportPlaces { [viewModel] in viewModel.setImportedPlaces($0) }
                        }
                    }
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .keyboardOverlapPadding()
                // 화면이 키보드를 피하지 않아 시스템이 입력칸을 맞춰 주지 않는다.
                // 입력칸 아래로 여유를 두고 직접 맞춘다. 키보드가 이미 떠 있을 때 칸을 옮기는 경우와, 키보드가 다 올라온 뒤 둘 다 맞춘다.
                .onChange(of: focusedField) { _, field in scroll(proxy, to: field) }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                    scroll(proxy, to: focusedField)
                }
                // 태그 칩이 새 줄로 넘어가면 입력칸이 아래로 밀린다. 다시 맞춘다.
                .onChange(of: state.tags) {
                    if focusedField == .tag { scroll(proxy, to: .tag) }
                }
            }
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
        // 아래 버튼이 키보드를 따라 올라오지 않게 한다.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $showsPhotoPicker) {
            PhotoLibraryPicker(
                maxSelection: 1,
                onCancel: { showsPhotoPicker = false },
                onPicked: { photos in
                    showsPhotoPicker = false
                    guard let photo = photos.first else { return }
                    if let data = photo.data {
                        viewModel.selectImage(data: data, type: photo.type)
                    } else {
                        viewModel.showImageLoadFailure()
                    }
                }
            )
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: state.pickedImage?.selection) {
            previewImage = viewModel.uiState.pickedImage.flatMap { UIImage(data: $0.image.data) }
        }
        .onChange(of: state.submit) { _, submit in
            guard case .done(_, let inviteCode) = submit else { return }
            let state = viewModel.uiState
            onCreated(state.placeSaveNotice, inviteCode.map { CreatedMapInvite(mapName: state.name, inviteCode: $0) })
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to field: Field?) {
        guard let field else { return }
        withAnimation { proxy.scrollTo(field, anchor: .bottom) }
    }

    /// 키보드 위로 입력칸을 맞출 때 쓰는 자리. 입력칸보다 아래로 길게 잡아 키보드와 붙지 않게 띄운다.
    private func scrollTarget(_ field: Field) -> some View {
        Color.clear
            .id(field)
            .padding(.bottom, -Self.keyboardGap)
    }

    private static let keyboardGap: CGFloat = 20

    /// 입력창에 보이는 글자 그대로 태그로 확정하고 입력창을 남은 값으로 맞춘다.
    private func commitTagDraft() {
        viewModel.updateTagInput(tagDraft + "\n")
        tagDraft = viewModel.uiState.tagInput
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
                ) {
                    focusedField = nil
                    viewModel.selectVisibility(.public)
                }
                VisibilityCard(
                    iconName: "lock", title: "프라이빗 지도", subtitle: "초대한 사람만 볼 수 있어요",
                    selected: selected == .private
                ) {
                    focusedField = nil
                    viewModel.selectVisibility(.private)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    CreateMapView(
        viewModel: CreateMapViewModel(repository: PreviewCollectionRepository(), importRepository: PreviewPlaceImportRepository()),
        onImportPlaces: { _ in }, onCreated: { _, _ in }
    )
}
#endif
