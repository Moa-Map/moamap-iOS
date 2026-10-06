import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor @Observable
final class PlaceImportViewModel {
    static let extractionFailedMessage = "장소를 가져오지 못했어요"
    static let mapsLoadFailedMessage = "지도 목록을 불러오지 못했어요"
    static let saveFailedMessage = "장소를 저장하지 못했어요"
    static let alreadySavedMessage = "이미 저장되어 있는 장소예요"
    static let networkErrorMessage = "네트워크에 연결할 수 없어요"

    private(set) var uiState: PlaceImportUiState
    private(set) var extractionTask: Task<Void, any Error>?
    private(set) var mapsTask: Task<Void, any Error>?
    private(set) var saveTask: Task<Void, any Error>?

    /// 재시도를 취소하거나 실패했을 때 돌아갈 직전 결과.
    private var previousResult: (places: [ImportedPlace], selection: Set<String>)?
    private let importRepository: any PlaceImportRepository
    private let collectionRepository: any CollectionRepository

    init(
        source: PlaceImportSource,
        url: String = "",
        importRepository: any PlaceImportRepository,
        collectionRepository: any CollectionRepository
    ) {
        uiState = PlaceImportUiState(source: source, url: url)
        self.importRepository = importRepository
        self.collectionRepository = collectionRepository
    }

    // MARK: 링크 → 장소

    func updateURL(_ url: String) {
        uiState.url = url
    }

    /// 검색과 재시도가 함께 쓴다.
    func startExtraction() {
        guard uiState.canSearch else { return }
        extractionTask?.cancel()
        if case .loaded(let places) = uiState.extraction {
            previousResult = (places, uiState.selectedPlaceIDs)
        }
        uiState.extraction = .loading
        uiState.selectedPlaceIDs = []
        uiState.errorMessage = nil

        let source = uiState.source
        let url = uiState.url
        extractionTask = Task { [weak self, importRepository] in
            do {
                let places = switch source {
                case .instagram: try await importRepository.extractInstagramPlaces(url: url)
                case .mapShare: try await importRepository.extractMapSharePlaces(url: url)
                }
                try Task.checkCancellation()
                guard let self else { return }
                previousResult = nil
                uiState.extraction = .loaded(places)
                uiState.selectedPlaceIDs = Self.initialSelection(places, source: source)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                self?.restorePrevious(errorMessage: Self.extractionMessage(for: error))
            }
        }
    }

    /// 로딩 중 뒤로가기. 진행 중이 아니면 이미 나온 결과를 지우지 않는다.
    func cancelExtraction() {
        guard uiState.extraction == .loading else { return }
        extractionTask?.cancel()
        extractionTask = nil
        restorePrevious(errorMessage: nil)
    }

    private func restorePrevious(errorMessage: String?) {
        let restored = previousResult
        previousResult = nil
        uiState.extraction = restored.map { .loaded($0.places) } ?? .idle
        uiState.selectedPlaceIDs = restored?.selection ?? []
        uiState.errorMessage = errorMessage
    }

    /// 외부 지도는 리스트를 통째로 가져오는 것이라 전부 고른 채로 시작한다. 인스타그램 후보는 직접 고른다.
    private static func initialSelection(_ places: [ImportedPlace], source: PlaceImportSource) -> Set<String> {
        source == .mapShare ? Set(places.filter(\.savable).map(\.id)) : []
    }

    /// 등록 키가 없는 후보는 서버가 거절해 고를 수 없다.
    func togglePlace(_ placeID: String) {
        guard uiState.places.contains(where: { $0.id == placeID && $0.savable }) else { return }
        if uiState.selectedPlaceIDs.contains(placeID) {
            uiState.selectedPlaceIDs.remove(placeID)
        } else {
            uiState.selectedPlaceIDs.insert(placeID)
        }
    }

    func consumeError() {
        uiState.errorMessage = nil
    }

    // MARK: 편집

    func updateEditTags(_ placeID: String, tags: [String]) {
        updateEdit(placeID) { $0.tags = tags }
    }

    func updateEditMemo(_ placeID: String, memo: String) {
        updateEdit(placeID) { $0.memo = memo }
    }

    /// 꽉 찼거나 같은 사진이면 무시한다.
    func addEditPhoto(_ placeID: String, data: Data?, type: UTType?) {
        do {
            guard let data else { throw ImageUploadError.unreadable }
            let image = try UploadImage(pickedData: data, type: type)
            updateEdit(placeID) { edit in
                guard edit.photos.count < PlaceImportUiState.maxPhotos, !edit.photos.contains(image) else { return }
                edit.photos.append(image)
            }
        } catch {
            uiState.errorMessage = (error as? ImageUploadError ?? .unreadable).userMessage
        }
    }

    func removeEditPhoto(_ placeID: String, at index: Int) {
        updateEdit(placeID) { edit in
            guard edit.photos.indices.contains(index) else { return }
            edit.photos.remove(at: index)
        }
    }

    private func updateEdit(_ placeID: String, _ transform: (inout PlaceEdit) -> Void) {
        guard let place = uiState.places.first(where: { $0.id == placeID }) else { return }
        let before = uiState.edit(of: place)
        var after = before
        transform(&after)
        uiState.edits[placeID] = after
        // 올려 둔 주소가 바뀐 사진과 어긋나지 않게 그 장소 것만 버린다.
        if before.photos != after.photos { uiState.uploadedPhotoURLs[placeID] = nil }
    }

    // MARK: 지도 → 등록

    /// 흐름에 들어올 때 미리 읽어 지도 선택에서 기다리지 않게 한다.
    func loadTargetMaps() {
        mapsTask?.cancel()
        uiState.targetMaps = .loading
        mapsTask = Task { [weak self, collectionRepository] in
            do {
                let maps = try await collectionRepository.fetchMyMaps(type: .private)
                try Task.checkCancellation()
                self?.uiState.targetMaps = .loaded(maps)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                self?.uiState.targetMaps = .failed(Self.mapsLoadFailedMessage)
            }
        }
    }

    func toggleMap(_ mapID: Int64) {
        if let index = uiState.selectedMapIDs.firstIndex(of: mapID) {
            uiState.selectedMapIDs.remove(at: index)
        } else {
            uiState.selectedMapIDs.append(mapID)
        }
    }

    /// 실패하면 고른 것을 그대로 두고 같은 자리에서 다시 누를 수 있게 한다.
    func savePlaces() {
        guard uiState.canSave, let photoMapID = uiState.selectedMapIDs.first else { return }
        let entries = uiState.selectedEntries
        let mapIDs = uiState.selectedMapIDs
        let uploaded = uiState.uploadedPhotoURLs
        uiState.saving = true
        uiState.errorMessage = nil

        saveTask = Task { [weak self, importRepository] in
            do {
                var photoURLs = uploaded
                // 앞서 올려 둔 장소는 건너뛴다. 실패 뒤 새로 고른 장소의 사진만 올린다.
                let pending = entries.filter { uploaded[$0.place.id] == nil }
                if pending.contains(where: { !$0.edit.photos.isEmpty }) {
                    // 발급 권한만 확인하는 값이라 고른 지도 중 아무거나면 된다.
                    let fresh = try await importRepository.uploadPhotos(mapID: photoMapID, places: pending)
                    try Task.checkCancellation()
                    photoURLs.merge(fresh) { _, new in new }
                    self?.uiState.uploadedPhotoURLs = photoURLs
                }
                let result = try await importRepository.savePlaces(mapIDs: mapIDs, places: entries, photoURLs: photoURLs)
                try Task.checkCancellation()
                guard let self else { return }
                uiState.saving = false
                // 한 곳도 들어가지 않았는데 저장된 것처럼 닫으면 안 된다.
                if result.created == 0 {
                    uiState.errorMessage = result.failed == 0 ? Self.alreadySavedMessage : Self.saveFailedMessage
                } else {
                    uiState.saveResult = result
                }
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                self?.uiState.saving = false
                self?.uiState.errorMessage = Self.saveMessage(for: error)
            }
        }
    }

    // MARK: 안내

    /// 캡션을 못 읽은 이유와 서버가 준 거절 사유는 사용자가 조치할 수 있어 그대로 보여준다.
    private static func extractionMessage(for error: any Error) -> String {
        if let error = error as? PlaceExtractionError { return error.userMessage }
        return networkMessage(for: error) ?? extractionFailedMessage
    }

    /// 사진 형식·크기는 사진을 바꿔야 하는 일이라 이유를 그대로 보여준다.
    private static func saveMessage(for error: any Error) -> String {
        if let error = error as? ImageUploadError { return error.userMessage }
        return networkMessage(for: error) ?? saveFailedMessage
    }

    private static func networkMessage(for error: any Error) -> String? {
        guard let error = error as? NetworkError else { return nil }
        if case .connection = error { return networkErrorMessage }
        return error.serverMessage
    }
}
