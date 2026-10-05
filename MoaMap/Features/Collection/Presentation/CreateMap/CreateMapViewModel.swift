import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class CreateMapViewModel {
    static let createFailedMessage = "지도를 만들지 못했어요"
    static let coverUploadFailedMessage = "사진을 올리지 못했어요"
    static let networkErrorMessage = "네트워크에 연결할 수 없어요"

    private(set) var uiState = CreateMapUiState()
    private(set) var submitTask: Task<Void, any Error>?

    /// 생성만 실패해 다시 눌러도 같은 사진을 두 번 올리지 않게 들고 있다. 올린 파일을 지우는 API 가 없다.
    private var uploaded: (selection: Int, fileURL: String)?
    private var nextSelection = 0
    private let repository: any CollectionRepository

    init(repository: any CollectionRepository) { self.repository = repository }

    /// 제출 중에는 무시한다. 이미 앞의 사진을 올리고 있어, 바꾸면 화면과 저장된 사진이 어긋난다.
    func selectImage(data: Data, type: UTType?) {
        guard !uiState.isSubmitting else { return }
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

    func selectVisibility(_ visibility: MapVisibility) {
        uiState.visibility = visibility
    }

    /// 공백이나 줄바꿈이 들어오면 그 앞까지 태그로 확정한다. 붙여넣기로 여러 개가 들어와도 같다.
    func updateTagInput(_ input: String) {
        let tokens = input.split(omittingEmptySubsequences: false, whereSeparator: Self.isTagSeparator).map(String.init)
        guard tokens.count > 1, let pending = tokens.last else {
            uiState.tagInput = String(input.prefix(CreateMapUiState.tagMaxLength))
            return
        }
        uiState.tags = Self.adding(tokens.dropLast(), to: uiState.tags)
        uiState.tagInput = String(pending.prefix(CreateMapUiState.tagMaxLength))
    }

    func commitTag() {
        uiState.tags = Self.adding([uiState.tagInput], to: uiState.tags)
        uiState.tagInput = ""
    }

    func removeTag(_ tag: String) {
        uiState.tags.removeAll { $0 == tag }
    }

    /// 사진은 여기서 올린다. 업로드가 실패하면 지도도 만들지 않는다.
    func submit() {
        guard uiState.canSubmit, let visibility = uiState.visibility else { return }
        // 입력만 해두고 바로 누른 태그도 요청에 담는다.
        commitTag()
        let newMap = NewMap(
            name: uiState.name,
            description: uiState.description,
            visibility: visibility,
            tags: uiState.tags
        )
        let picked = uiState.pickedImage
        uiState.submit = .submitting
        uiState.errorMessage = nil

        submitTask = Task { [weak self] in
            guard let self else { return }
            var newMap = newMap
            do {
                if let picked { newMap.imageURL = try await resolveCoverURL(picked) }
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                uiState.submit = .idle
                uiState.errorMessage = Self.coverMessage(for: error)
                return
            }

            do {
                let created = try await repository.createMap(newMap)
                try Task.checkCancellation()
                uiState.submit = created.inviteCode.map { .showingInviteCode(mapID: created.id, inviteCode: $0) }
                    ?? .done(mapID: created.id)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                uiState.submit = .idle
                uiState.errorMessage = Self.isConnection(error) ? Self.networkErrorMessage : Self.createFailedMessage
            }
        }
    }

    func dismissInviteCode() {
        guard case .showingInviteCode(let mapID, _) = uiState.submit else { return }
        uiState.submit = .done(mapID: mapID)
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

    private static func isTagSeparator(_ character: Character) -> Bool {
        character == " " || character.isNewline
    }

    /// 빈 값과 이미 담긴 태그는 거른다.
    private static func adding(_ candidates: some Sequence<String>, to tags: [String]) -> [String] {
        var result = tags
        for candidate in candidates {
            let tag = String(candidate.trimmingCharacters(in: .whitespacesAndNewlines).prefix(CreateMapUiState.tagMaxLength))
            if !tag.isEmpty, !result.contains(tag) { result.append(tag) }
        }
        return result
    }

    /// 사진을 바꿔야 하는 실패와 다시 누르면 되는 실패를 나눠 안내한다.
    private static func coverMessage(for error: any Error) -> String {
        if let error = error as? ImageUploadError { return error.userMessage }
        return isConnection(error) ? networkErrorMessage : coverUploadFailedMessage
    }

    private static func isConnection(_ error: any Error) -> Bool {
        if case .connection = error as? NetworkError { return true }
        return false
    }
}
