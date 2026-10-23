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
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("지도 이름과 소개, 태그를 수정할 수 있어요")
                            .moaTextStyle(typography.body2)
                            .foregroundStyle(colors.textNormal)
                            .padding(.leading, 4)
                        MapPhotoField(image: previewImage, imageURL: state.original.imageURL, showsEditOverlay: true) {
                            // 올리는 중에는 열지 않는다. 고른 사진이 반영되지 않는다.
                            guard !state.saving else { return }
                            // 입력 중이면 바깥을 누른 것처럼 키보드만 내린다.
                            guard focusedField == nil else {
                                focusedField = nil
                                return
                            }
                            showsPhotoPicker = true
                        }
                        CreateMapInputField(
                            label: "지도 이름",
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
                        tagField(state)
                    }
                    .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                    .padding(.top, 20)
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
            CreateMapSubmitButton(title: "저장하기", enabled: state.canSave, submitting: state.saving) {
                focusedField = nil
                viewModel.save()
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
        .onChange(of: state.saved) { _, saved in
            if saved { onSaved() }
        }
    }

    /// Binding setter 안에서 값을 비우면 TextField가 화면에 반영하지 않는다.
    /// 그래서 입력은 그대로 받아 두고, 확정과 되돌려 받기는 onChange에서 한다.
    private func tagField(_ state: EditMapUiState) -> some View {
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
