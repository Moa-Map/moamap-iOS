import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class CreateMapViewModel {
    static let createFailedMessage = "지도를 만들지 못했어요"
    static let coverUploadFailedMessage = "사진을 올리지 못했어요"
    static let networkErrorMessage = "네트워크에 연결할 수 없어요"
    static let placeSavePartialMessage = "일부 장소를 못 넣었어요"
    static let placeSaveFailedMessage = "불러온 장소를 넣지 못했어요"

    private(set) var uiState = CreateMapUiState()
    private(set) var submitTask: Task<Void, any Error>?

    /// 생성만 실패해 다시 눌러도 같은 사진을 두 번 올리지 않게 들고 있다. 올린 파일을 지우는 API 가 없다.
    private var uploaded: (selection: Int, fileURL: String)?
    private var nextSelection = 0
    private let repository: any CollectionRepository
    private let importRepository: any PlaceImportRepository

    init(repository: any CollectionRepository, importRepository: any PlaceImportRepository) {
        self.repository = repository
        self.importRepository = importRepository
    }

    /// 제출 중에는 무시한다. 이미 앞의 사진을 올리고 있어, 바꾸면 화면과 저장된 사진이 어긋난다.
    func selectImage(data: Data, type: UTType?) {
        guard !uiState.isSubmitting else { return }
        do {
            let image = try UploadImage(pickedData: data, type: type)
            nextSelection += 1
            uiState.pickedImage = PickedCoverImage(selection: nextSelection, image: image)
        } catch {
            uiState.errorMessage = error.userMessage
        }
    }

    /// 제출 중에는 무시한다. 이미 올리고 있는 사진과 화면이 어긋난다.
    func removeImage() {
        guard !uiState.isSubmitting else { return }
        uiState.pickedImage = nil
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

    func updateTagInput(_ input: String) {
        (uiState.tags, uiState.tagInput) = MapTagInput.apply(input, to: uiState.tags)
    }

    func removeTag(_ tag: String) {
        uiState.tags.removeAll { $0 == tag }
    }

    /// 앞서 불러온 장소에 덧붙이지 않고 바꾼다.
    func setImportedPlaces(_ places: [EditedPlace]) {
        guard !uiState.isSubmitting else { return }
        uiState.importedPlaces = places
    }

    /// 사진은 여기서 올린다. 업로드가 실패하면 지도도 만들지 않는다.
    /// 불러온 장소는 지도를 만든 뒤 넣고, 못 넣어도 지도는 그대로 둔다.
    func submit() {
        guard uiState.canSubmit, let visibility = uiState.visibility else { return }
        let newMap = NewMap(
            name: uiState.name,
            description: uiState.description,
            visibility: visibility,
            tags: uiState.tags
        )
        let picked = uiState.pickedImage
        let places = uiState.importedPlaces
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

            let created: CreatedMap
            do {
                created = try await repository.createMap(newMap)
                try Task.checkCancellation()
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                uiState.submit = .idle
                uiState.errorMessage = Self.isConnection(error) ? Self.networkErrorMessage : Self.createFailedMessage
                return
            }

            if !places.isEmpty {
                uiState.placeSaveNotice = try await savePlaces(places, mapID: created.id)
            }
            uiState.submit = .done(mapID: created.id, inviteCode: created.inviteCode)
        }
    }

    /// 다 넣지 못했으면 안내를 돌려준다. 그 지도에 이미 있던 장소는 들어간 것으로 본다.
    private func savePlaces(_ places: [EditedPlace], mapID: Int64) async throws -> String? {
        do {
            var photoURLs: [String: [String]] = [:]
            if places.contains(where: { !$0.edit.photos.isEmpty }) {
                photoURLs = try await importRepository.uploadPhotos(mapID: mapID, places: places)
                try Task.checkCancellation()
            }
            let result = try await importRepository.savePlaces(mapIDs: [mapID], places: places, photoURLs: photoURLs)
            try Task.checkCancellation()
            let saved = result.created + result.duplicate
            if saved >= places.count { return nil }
            return saved == 0 ? Self.placeSaveFailedMessage : Self.placeSavePartialMessage
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            return Self.placeSaveFailedMessage
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
