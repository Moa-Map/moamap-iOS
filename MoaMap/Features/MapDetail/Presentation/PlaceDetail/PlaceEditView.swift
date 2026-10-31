import SwiftUI

/// 장소 수정. 지도 상세 위를 덮는 한 장이다. 사진·태그·메모를 장소 추가와 같은 폼으로 고친다.
struct PlaceEditView: View {
    @Environment(\.moaColors) private var colors

    let viewModel: PlaceEditViewModel
    let onClose: () -> Void

    @State private var showsPhotoPicker = false
    @State private var discardDialogVisible = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: AddPlaceField?

    private var state: PlaceEditUiState { viewModel.uiState }

    var body: some View {
        VStack(spacing: 0) {
            MoaMapTopBar(title: "장소 수정하기", onBack: back)
            AddPlaceFormContent(
                name: state.original.name,
                address: state.original.address,
                remotePhotoURLs: state.photoURLs,
                photos: state.newPhotos,
                tags: state.tags,
                tagInput: state.tagInput,
                memo: state.memo,
                focus: $focusedField,
                onAddPhoto: {
                    focusedField = nil
                    showsPhotoPicker = true
                },
                onRemovePhoto: viewModel.removePhoto(at:),
                onTagInputChange: {
                    viewModel.updateTagInput($0)
                    return viewModel.uiState.tagInput
                },
                onTagBackspace: viewModel.removeLastTagIfInputEmpty,
                onRemoveTag: viewModel.removeTag,
                onMemoChange: viewModel.updateMemo
            )
            // 누른 순간의 값으로 저장한다. 기다리는 동안 바꾸면 반영되지 않으니 막는다.
            .disabled(state.saving)
            .padding(.top, 16)
            PlaceImportButton(text: "저장하기", height: 54, enabled: state.changed, loading: state.saving) {
                focusedField = nil
                viewModel.save()
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.backgroundSecondary)
        // 뒤에 깔린 지도로 터치가 새지 않게 하고, 빈 곳을 누르면 키보드를 내린다.
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .fullScreenCover(isPresented: $showsPhotoPicker) {
            PhotoLibraryPicker(
                maxSelection: AddPlaceUiState.maxPhotos - state.photoCount,
                onCancel: { showsPhotoPicker = false },
                onPicked: { photos in
                    showsPhotoPicker = false
                    for photo in photos { viewModel.addPhoto(data: photo.data, type: photo.type) }
                }
            )
        }
        .moaSnackbar($errorMessage)
        .onChange(of: state.errorMessage, initial: true) { _, message in
            guard let message else { return }
            errorMessage = message
            viewModel.consumeErrorMessage()
        }
        .overlay {
            if discardDialogVisible {
                MoaMapConfirmDialog(
                    title: "수정을 그만둘까요?",
                    message: "저장하지 않은 변경사항은 사라져요",
                    dismissText: "계속 수정",
                    confirmText: "나가기",
                    onConfirm: onClose,
                    onDismiss: { discardDialogVisible = false }
                )
            }
        }
    }

    /// 저장하는 동안에는 나가지 않는다. 화면을 닫으면 저장 결과를 시트에 반영할 곳이 없다.
    private func back() {
        guard !state.saving else { return }
        guard state.changed else { return onClose() }
        focusedField = nil
        discardDialogVisible = true
    }
}

#if DEBUG
#Preview {
    PlaceEditView(
        viewModel: PlaceEditViewModel(
            place: MapPlace(
                id: 1, name: "커피나무", address: "서울 성동구 성수이로 1", latitude: 37.5, longitude: 127.0, photoURLs: [],
                description: "창가 자리가 좋아요", tags: ["카페", "데이트"]
            ),
            mapID: 1, repository: PreviewMapDetailRepository(), photoRepository: PreviewPlaceAddRepository()
        ),
        onClose: {}
    )
}
#endif
