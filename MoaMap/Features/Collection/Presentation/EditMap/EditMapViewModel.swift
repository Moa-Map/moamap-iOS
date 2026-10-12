import Foundation
import Observation
import UniformTypeIdentifiers

/// 지도 정보 수정. 모음 편집과 지도 정보 화면이 함께 연다.
@MainActor @Observable
final class EditMapViewModel {
    static let saveFailedMessage = "지도 정보를 저장하지 못했어요"
    static let noPermissionMessage = "방장과 관리자만 지도 정보를 수정할 수 있어요"

    private(set) var uiState: EditMapUiState
    private(set) var saveTask: Task<Void, any Error>?

    /// 저장만 실패해 다시 눌러도 같은 사진을 두 번 올리지 않게 들고 있다. 올린 파일을 지우는 API 가 없다.
    private var uploaded: (selection: Int, fileURL: String)?
    private var nextSelection = 0
    private let repository: any CollectionRepository

    init(map: MapDetail, repository: any CollectionRepository) {
        uiState = EditMapUiState(map: map)
        self.repository = repository
    }

    /// 저장 중에는 무시한다. 이미 앞의 사진을 올리고 있어, 바꾸면 화면과 저장된 사진이 어긋난다.
    func selectImage(data: Data, type: UTType?) {
        guard !uiState.saving else { return }
        do {
            let image = try UploadImage(pickedData: data, type: type)
            try ImageUploadRules.validate(contentType: image.contentType, fileSize: image.fileSize)
            nextSelection += 1
            uiState.pickedImage = PickedCoverImage(selection: nextSelection, image: image)
        } catch {
            uiState.errorMessage = error.userMessage
        }
    }

    func showImageLoadFailure() {
        uiState.errorMessage = ImageUploadError.unreadable.userMessage
    }

    func updateName(_ value: String) {
        uiState.name = String(value.prefix(CreateMapUiState.nameMaxLength))
    }

    func updateDescription(_ value: String) {
        uiState.description = String(value.prefix(CreateMapUiState.descriptionMaxLength))
    }

    func updateTagInput(_ input: String) {
        (uiState.tags, uiState.tagInput) = MapTagInput.apply(input, to: uiState.tags)
    }

    func commitTag() {
        uiState.tags = MapTagInput.adding([uiState.tagInput], to: uiState.tags)
        uiState.tagInput = ""
    }

    func removeTag(_ tag: String) {
        uiState.tags.removeAll { $0 == tag }
    }

    /// 사진은 여기서 올린다. 업로드가 실패하면 정보도 저장하지 않는다.
    func save() {
        guard uiState.canSave else { return }
        // 입력만 해두고 바로 누른 태그도 요청에 담는다.
        commitTag()
        let original = uiState.original
        let picked = uiState.pickedImage
        // 서버가 통째로 덮어쓴다. 사진을 바꾸지 않았으면 원래 주소를 그대로 보내야 지워지지 않는다.
        var update = MapUpdate(
            name: uiState.name,
            description: uiState.description,
            tags: uiState.tags,
            imageURL: original.imageURL?.absoluteString
        )
        uiState.saving = true
        uiState.errorMessage = nil

        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let picked { update.imageURL = try await resolveCoverURL(picked) }
                try await repository.updateMap(mapID: original.id, update)
                try Task.checkCancellation()
                uiState.saving = false
                uiState.saved = true
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                uiState.saving = false
                uiState.errorMessage = Self.message(for: error)
            }
        }
    }

    func consumeError() {
        uiState.errorMessage = nil
    }

    private func resolveCoverURL(_ picked: PickedCoverImage) async throws -> String {
        if let uploaded, uploaded.selection == picked.selection { return uploaded.fileURL }
        let fileURL = try await repository.uploadCoverImage(picked.image)
        uploaded = (picked.selection, fileURL)
        return fileURL
    }

    /// 사진을 바꿔야 하는 실패, 권한을 잃은 실패, 다시 누르면 되는 실패를 나눠 안내한다.
    private static func message(for error: any Error) -> String {
        if let error = error as? ImageUploadError { return error.userMessage }
        if case .server(code: "MAP_003", _, _) = error as? NetworkError { return noPermissionMessage }
        return MapDetailMessage.userMessage(for: error, fallback: saveFailedMessage)
    }
}
