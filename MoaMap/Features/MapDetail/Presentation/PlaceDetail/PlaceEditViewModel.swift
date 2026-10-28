import Foundation
import Observation
import UniformTypeIdentifiers

nonisolated struct PlaceEditUiState: Equatable, Sendable {
    let original: MapPlace
    /// 서버에 있는 사진. 새로 고른 사진보다 앞에 보인다.
    var photoURLs: [URL]
    /// 새로 고른 사진. 저장할 때 올린다.
    var newPhotos: [UploadImage] = []
    var tags: [String]
    var tagInput = ""
    var memo: String
    var saving = false
    var errorMessage: String?
    /// 저장이 끝난 장소. 화면이 받아 시트에 반영하고 닫는다.
    var saved: MapPlace?

    init(place: MapPlace) {
        original = place
        photoURLs = place.photoURLs
        tags = place.tags
        memo = place.description
    }

    var photoCount: Int { photoURLs.count + newPhotos.count }
    var canAddPhoto: Bool { photoCount < AddPlaceUiState.maxPhotos }
    /// 바뀐 게 없으면 저장할 것도, 나갈 때 물을 것도 없다.
    var changed: Bool {
        photoURLs != original.photoURLs || !newPhotos.isEmpty || tags != original.tags || memo != original.description
    }
}

/// 장소 수정. 열 때마다 그 순간의 장소로 새로 시작한다.
@MainActor @Observable
final class PlaceEditViewModel {
    static let saveFailedMessage = "장소 정보를 수정하지 못했어요"

    private(set) var uiState: PlaceEditUiState
    private(set) var saveTask: Task<Void, Never>?

    private let mapID: Int64
    private let repository: any MapDetailRepository
    private let photoRepository: any PlaceAddRepository

    init(place: MapPlace, mapID: Int64, repository: any MapDetailRepository, photoRepository: any PlaceAddRepository) {
        uiState = PlaceEditUiState(place: place)
        self.mapID = mapID
        self.repository = repository
        self.photoRepository = photoRepository
    }

    func addPhoto(data: Data?, type: UTType?) {
        do {
            guard let data else { throw ImageUploadError.unreadable }
            let image = try UploadImage(pickedData: data, type: type)
            guard uiState.canAddPhoto, !uiState.newPhotos.contains(image) else { return }
            uiState.newPhotos.append(image)
        } catch {
            uiState.errorMessage = (error as? ImageUploadError ?? .unreadable).userMessage
        }
    }

    /// 서버 사진과 새로 고른 사진을 이어 붙인 순서로 센다.
    func removePhoto(at index: Int) {
        if uiState.photoURLs.indices.contains(index) {
            uiState.photoURLs.remove(at: index)
        } else if uiState.newPhotos.indices.contains(index - uiState.photoURLs.count) {
            uiState.newPhotos.remove(at: index - uiState.photoURLs.count)
        }
    }

    func updateTagInput(_ input: String) {
        let result = TagInput.apply(tags: uiState.tags, rawInput: input)
        uiState.tags = result.tags
        uiState.tagInput = String(result.input.prefix(TagInput.maxLength))
    }

    /// 입력창이 비었을 때 지우기를 누르면 마지막 태그를 지운다.
    func removeLastTagIfInputEmpty() {
        guard uiState.tagInput.isEmpty else { return }
        uiState.tags = Array(uiState.tags.dropLast())
    }

    func removeTag(_ tag: String) {
        uiState.tags.removeAll { $0 == tag }
    }

    func updateMemo(_ memo: String) {
        uiState.memo = memo
    }

    func consumeErrorMessage() {
        uiState.errorMessage = nil
    }

    /// 새 사진을 먼저 올리고, 남길 사진까지 모두 담아 보낸다. 서버는 받은 목록으로 사진을 통째로 바꾼다.
    func save() {
        guard uiState.changed, !uiState.saving else { return }
        uiState.saving = true
        uiState.errorMessage = nil
        saveTask = Task { [weak self, mapID, repository, photoRepository] in
            guard let self else { return }
            do {
                if !uiState.newPhotos.isEmpty {
                    let uploaded = try await photoRepository.uploadPhotos(mapID: mapID, photos: uiState.newPhotos)
                    // 올린 사진은 이제 서버 사진이다. 저장만 실패해 다시 눌러도 또 올리지 않는다.
                    uiState.photoURLs += uploaded.compactMap(URL.init(string:))
                    uiState.newPhotos = []
                }
                let state = uiState
                try await repository.updatePlace(
                    placeID: state.original.id,
                    tags: state.tags,
                    description: state.memo,
                    photoURLs: state.photoURLs.map(\.absoluteString)
                )
                try Task.checkCancellation()
                var place = state.original
                place.photoURLs = state.photoURLs
                place.tags = state.tags
                place.description = state.memo
                uiState.saving = false
                uiState.saved = place
            } catch {
                guard !(error is CancellationError) else { return }
                uiState.saving = false
                uiState.errorMessage = Self.message(for: error)
            }
        }
    }

    /// 사진을 바꿔야 하는 실패는 이유를 그대로, 나머지는 다시 누르면 되는 실패로 안내한다.
    private static func message(for error: any Error) -> String {
        if let error = error as? ImageUploadError { return error.userMessage }
        return MapDetailMessage.userMessage(for: error, fallback: saveFailedMessage)
    }
}
