import Foundation

/// 실패는 담지 않는다. 담으면 재시도가 실패했을 때 보던 목록과 선택이 날아간다.
nonisolated enum PlaceExtractionState: Equatable, Sendable {
    case idle
    case loading
    case loaded([ImportedPlace])
}

/// 장소 가져오기 단계들이 함께 쓰는 상태. 뒤로 오가도 값이 끊기지 않게 한 곳에 둔다.
nonisolated struct PlaceImportUiState: Equatable, Sendable {
    static let maxPhotos = 5

    let source: PlaceImportSource
    var url: String
    var extraction: PlaceExtractionState = .idle
    var selectedPlaceIDs: Set<String> = []
    /// 한 번도 편집하지 않은 장소는 없다. `edit(of:)` 가 기본값을 만든다.
    var edits: [String: PlaceEdit] = [:]
    /// 저장할 곳으로 고를 수 있는 내 프라이빗 지도.
    var targetMaps: CollectionMapsState = .loading
    /// 고른 순서대로 등록한다.
    var selectedMapIDs: [Int64] = []
    /// 등록이 실패해 다시 시도할 때 같은 사진을 또 올리지 않게 둔다. 사진이 바뀌면 비운다.
    var uploadedPhotoURLs: [String: [String]] = [:]
    var saving = false
    /// 채워지면 흐름을 빠져나간다.
    var saveResult: PlaceSaveResult?
    var errorMessage: String?

    var places: [ImportedPlace] {
        if case .loaded(let places) = extraction { places } else { [] }
    }

    /// 고른 순서가 아니라 목록에 나온 순서다.
    var selectedPlaces: [ImportedPlace] { places.filter { selectedPlaceIDs.contains($0.id) } }

    /// 외부 지도에서 온 메모를 시작값으로 삼아, 손대지 않으면 원래 메모가 그대로 등록된다.
    func edit(of place: ImportedPlace) -> PlaceEdit {
        edits[place.id] ?? PlaceEdit(memo: place.description ?? "")
    }

    var selectedEntries: [EditedPlace] { selectedPlaces.map { EditedPlace(place: $0, edit: edit(of: $0)) } }

    var canSearch: Bool { !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var canProceed: Bool { !selectedPlaces.isEmpty }
    var canSave: Bool { !selectedMapIDs.isEmpty && !selectedPlaces.isEmpty && !saving }
}
