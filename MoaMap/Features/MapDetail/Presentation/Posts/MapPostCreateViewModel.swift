import Foundation
import Observation
import UniformTypeIdentifiers

/// 게시물에 태그한 장소. 폼에서는 주소까지 보여준다.
nonisolated struct SelectedPostPlace: Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    let address: String
}

nonisolated struct MapPostCreateUiState: Equatable, Sendable {
    /// 서버는 5장까지 받지만 상세도 한 장만 크게 보여줘 한 장만 받는다.
    static let maxPhotos = 1
    static let maxContentLength = 1000
    /// 서버는 10곳까지 받지만 카드가 한 곳만 보여준다.
    static let maxPlaceTags = 1

    var content = ""
    var photos: [UploadImage] = []
    /// 앞선 시도에서 이미 올려 둔 주소. 작성만 실패해 다시 누를 때 또 올리지 않는다. 사진이 바뀌면 비운다.
    var uploadedPhotoURLs: [String] = []
    var places: [SelectedPostPlace] = []
    var submitting = false
    var errorMessage: String?
    /// 올리기에 성공한 횟수. 화면이 이 값이 바뀌는 것을 보고 닫는다.
    var postedCount = 0

    var canAddPhoto: Bool { photos.count < Self.maxPhotos }
    var canAddPlace: Bool { places.count < Self.maxPlaceTags }
    /// 서버가 수정할 때 빈 본문을 막아 작성에서도 같은 기준을 둔다.
    var canSubmit: Bool { !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !submitting }
}

/// 지도 로그 탭의 새 게시물. 지도 상세에 매여 폼을 닫아도 살아남는다. 새로 열 때 `reset()` 으로 비운다.
@MainActor @Observable
final class MapPostCreateViewModel {
    nonisolated static let photoFailedMessage = "사진을 올리지 못했어요"
    nonisolated static let createFailedMessage = "게시물을 올리지 못했어요"

    let mapID: Int64
    private(set) var uiState = MapPostCreateUiState()
    private(set) var submitTask: Task<Void, Never>?

    private let repository: any MapPostRepository

    init(mapID: Int64, repository: any MapPostRepository) {
        self.mapID = mapID
        self.repository = repository
    }

    /// 성공 횟수는 남긴다. 되돌리면 화면이 새 성공 신호를 놓친다.
    func reset() {
        submitTask?.cancel()
        submitTask = nil
        uiState = MapPostCreateUiState(postedCount: uiState.postedCount)
    }

    /// 붙여 넣기로 한 번에 넘길 수 있어 한도를 넘는 입력은 잘라 낸다.
    func updateContent(_ content: String) {
        uiState.content = String(content.prefix(MapPostCreateUiState.maxContentLength))
    }

    func addPhoto(data: Data?, type: UTType?) {
        do {
            guard let data else { throw ImageUploadError.unreadable }
            let image = try UploadImage(pickedData: data, type: type)
            guard uiState.canAddPhoto, !uiState.photos.contains(image) else { return }
            uiState.photos.append(image)
            uiState.uploadedPhotoURLs = []
        } catch {
            uiState.errorMessage = (error as? ImageUploadError ?? .unreadable).userMessage
        }
    }

    func removePhoto(at index: Int) {
        guard uiState.photos.indices.contains(index) else { return }
        uiState.photos.remove(at: index)
        uiState.uploadedPhotoURLs = []
    }

    func addPlace(_ place: MapPlace) {
        guard uiState.canAddPlace, !uiState.places.contains(where: { $0.id == place.id }) else { return }
        uiState.places.append(SelectedPostPlace(id: place.id, name: place.name, address: place.address))
    }

    func removePlace(id: Int64) {
        uiState.places.removeAll { $0.id == id }
    }

    func consumeErrorMessage() { uiState.errorMessage = nil }

    /// 사진은 여기서 올린다. 고를 때마다 올리면 작성을 그만둔 사용자의 사진이 서버에 남는다.
    /// 사진이 하나라도 실패하면 게시물을 올리지 않는다.
    func submit() {
        let state = uiState
        guard state.canSubmit else { return }
        uiState.submitting = true
        uiState.errorMessage = nil
        submitTask?.cancel()
        submitTask = Task { [weak self, repository, mapID] in
            let photoURLs: [String]
            if !state.uploadedPhotoURLs.isEmpty || state.photos.isEmpty {
                photoURLs = state.uploadedPhotoURLs
            } else {
                do {
                    photoURLs = try await repository.uploadPhotos(mapID: mapID, photos: state.photos)
                    try Task.checkCancellation()
                    self?.uiState.uploadedPhotoURLs = photoURLs
                } catch {
                    guard !Task.isCancelled, !(error is CancellationError) else { return }
                    let message = (error as? ImageUploadError)?.userMessage
                        ?? MapDetailMessage.userMessage(for: error, fallback: Self.photoFailedMessage)
                    self?.fail(message)
                    return
                }
            }
            do {
                let post = NewMapPost(
                    content: state.content.trimmingCharacters(in: .whitespacesAndNewlines),
                    photoURLs: photoURLs,
                    placeTags: state.places.map { MapPostPlaceTag(placeID: $0.id, name: $0.name) }
                )
                try await repository.createPost(mapID: mapID, post: post)
                try Task.checkCancellation()
                guard let self else { return }
                self.uiState = MapPostCreateUiState(postedCount: self.uiState.postedCount + 1)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.fail(MapDetailMessage.userMessage(for: error, fallback: Self.createFailedMessage))
            }
        }
    }

    /// 실패해도 폼은 비우지 않는다.
    private func fail(_ message: String) {
        uiState.submitting = false
        uiState.errorMessage = message
    }
}
