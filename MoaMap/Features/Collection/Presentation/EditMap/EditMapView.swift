import SwiftUI
import UIKit

/// 지도 정보 수정. 사진·이름·설명·태그를 고친다.
struct EditMapView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    @State private var viewModel: EditMapViewModel
    @State private var showsPhotoPicker = false
    /// 고를 때 한 번만 풀어 둔다. 입력할 때마다 사진을 다시 풀지 않게 한다.
    @State private var previewImage: UIImage?
    /// TextField에 붙는 입력 중인 글자. 확정된 결과는 `tagInput`으로 다시 받는다.
    @State private var tagDraft = ""
    @FocusState private var focusedField: Field?
    private let onBack: () -> Void
    private let onSaved: () -> Void

    private enum Field { case name, description, tag }

    init(viewModel: EditMapViewModel, onBack: @escaping () -> Void, onSaved: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onBack = onBack
        self.onSaved = onSaved
    }

    var body: some View {
        let state = viewModel.uiState
        VStack(spacing: 0) {
            MoaMapTopBar(title: "지도 정보 수정") {
                // 저장 중에 닫으면 저장이 끝나도 목록과 상세가 새 값을 다시 읽지 않는다.
                guard !state.saving else { return }
                onBack()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("지도 이름과 소개, 태그를 수정할 수 있어요")
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textNormal)
                        .padding(.leading, 4)
                    MapPhotoField(image: previewImage, imageURL: state.original.imageURL, showsEditOverlay: true) {
                        // 올리는 중에는 열지 않는다. 고른 사진이 반영되지 않는다.
                        guard !state.saving else { return }
                        focusedField = nil
                        showsPhotoPicker = true
                    }
                    CreateMapInputField(
                        label: "지도 이름",
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
                    tagField(state)
                }
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .moaSnackbar(errorMessage)
        }
        .safeAreaInset(edge: .bottom) {
            CreateMapSubmitButton(title: "저장하기", enabled: state.canSave, submitting: state.saving) {
                focusedField = nil
                viewModel.save()
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .padding(.vertical, 13)
            // 스크롤한 내용이 버튼 뒤로 비치지 않게 한다.
            .background(colors.backgroundSecondary)
        }
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
        .onChange(of: state.saved) { _, saved in
            if saved { onSaved() }
        }
    }

    /// Binding setter 안에서 값을 비우면 TextField가 화면에 반영하지 않는다.
    /// 그래서 입력은 그대로 받아 두고, 확정과 되돌려 받기는 onChange에서 한다.
    private func tagField(_ state: EditMapUiState) -> some View {
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
    }

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
}

#if DEBUG
#Preview {
    EditMapView(
        viewModel: EditMapViewModel(
            map: MapDetail(
                id: 1, title: "숭실대 주변 맛집", description: "학교 주변에서 함께 찾아본 맛집을 모아봤어요", imageURL: nil,
                ownerName: "모아", type: .community, role: .owner, tags: ["맛집", "숭실대"], memberCount: 3, placeCount: 10,
                joined: true, personal: false, inviteCode: nil
            ),
            repository: PreviewCollectionRepository()
        ),
        onBack: {},
        onSaved: {}
    )
}
#endif
