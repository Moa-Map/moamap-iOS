import Foundation
import Observation
import UniformTypeIdentifiers

nonisolated enum PlaceSearchState: Equatable, Sendable {
    /// 아직 검색어를 넣지 않았다.
    case idle
    case loading
    case loaded([PlaceCandidate])
    case failed(String)
}

nonisolated struct AddPlaceUiState: Equatable, Sendable {
    /// 서버가 한 장소에 최대 5장까지 받는다.
    static let maxPhotos = 5

    var query = ""
    var search: PlaceSearchState = .idle
    /// nil 이면 검색, 값이 있으면 등록 폼이다. 단계를 따로 두면 둘이 어긋날 수 있다.
    var selected: PlaceCandidate?
    var photos: [UploadImage] = []
    var tags: [String] = []
    var tagInput = ""
    var memo = ""
    /// 등록이 실패해도 올린 사진은 남는다(지울 API 가 없다). 다시 시도할 때 재사용해 고아 파일이 쌓이지 않게 한다.
    var uploadedPhotoURLs: [String] = []
    var submitting = false
    /// 한 번 보여주고 지우는 실패 안내.
    var errorMessage: String?
    /// 등록이 끝났다. 화면이 이 신호로 닫고 안내를 띄운다.
    var addedMessage: String?

    var isFormStep: Bool { selected != nil }
    var canAddPhoto: Bool { photos.count < Self.maxPhotos }
}

@MainActor @Observable
final class AddPlaceViewModel {
    /// 글자마다 부르면 카카오 쿼터를 태운다. 쿼터가 소진되면 200 에 빈 결과로 와 알아채기 어렵다.
    static let searchDebounce: Duration = .milliseconds(300)

    let mapID: Int64
    private(set) var uiState = AddPlaceUiState()
    private(set) var searchTask: Task<Void, Never>?
    private(set) var submitTask: Task<Void, Never>?

    private let searchRepository: any PlaceSearchRepository
    private let addRepository: any PlaceAddRepository
    private let sleep: @Sendable (Duration) async throws -> Void

    init(
        mapID: Int64,
        searchRepository: any PlaceSearchRepository,
        addRepository: any PlaceAddRepository,
        sleep: @escaping @Sendable (Duration) async throws -> Void
    ) {
        self.mapID = mapID
        self.searchRepository = searchRepository
        self.addRepository = addRepository
        self.sleep = sleep
    }

    // MARK: 검색

    func updateQuery(_ query: String) {
        uiState.query = query
        searchTask?.cancel()
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            uiState.search = .idle
            return
        }
        searchTask = Task { [weak self, sleep] in
            do { try await sleep(Self.searchDebounce) } catch { return }
            guard let self, !Task.isCancelled else { return }
            self.uiState.search = .loading
            await self.search(query)
        }
    }

    func retrySearch() {
        let query = uiState.query
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        searchTask?.cancel()
        uiState.search = .loading
        searchTask = Task { [weak self] in await self?.search(query) }
    }

    private func search(_ query: String) async {
        let next: PlaceSearchState
        do {
            next = .loaded(try await searchRepository.search(query: query))
        } catch {
            guard !(error is CancellationError) else { return }
            next = .failed(MapDetailMessage.userMessage(for: error, fallback: AddPlaceMessage.searchFailed))
        }
        guard !Task.isCancelled else { return }
        uiState.search = next
    }

    /// 지도 상세에 매여 닫아도 살아남는다. 지우지 않으면 직전에 등록한 장소의 폼이 보인다.
    func reset() {
        searchTask?.cancel()
        submitTask?.cancel()
        uiState = AddPlaceUiState()
    }

    // MARK: 단계 이동

    func select(_ candidate: PlaceCandidate) {
        uiState.selected = candidate
    }

    /// 검색 결과는 남기고 폼에 적은 것만 버린다.
    func backToSearch() {
        uiState.selected = nil
        uiState.photos = []
        uiState.uploadedPhotoURLs = []
        uiState.tags = []
        uiState.tagInput = ""
        uiState.memo = ""
    }

    // MARK: 등록 폼

    /// 이미 꽉 찼거나 같은 사진이면 무시한다.
    func addPhoto(data: Data?, type: UTType?) {
        do {
            guard let data else { throw ImageUploadError.unreadable }
            let image = try UploadImage(pickedData: data, type: type)
            guard uiState.canAddPhoto, !uiState.photos.contains(image) else { return }
            uiState.photos.append(image)
            // 목록이 바뀌면 앞서 올려 둔 주소는 더 이상 맞지 않는다.
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

    func updateTagInput(_ input: String) {
        let result = TagInput.apply(tags: uiState.tags, rawInput: input)
        uiState.tags = result.tags
        uiState.tagInput = result.input
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

    /// 사진은 여기서 올린다. 고를 때마다 올리면 등록을 그만둔 사람의 사진이 서버에 남는다.
    /// 실패해도 화면을 닫지 않는다. 적어 둔 것이 날아가면 안 된다.
    func submit(map: MapDetail) {
        guard let candidate = uiState.selected, !uiState.submitting else { return }
        // 엔터 없이 바로 등록을 눌러도 입력 중이던 태그를 버리지 않는다.
        updateTagInput(uiState.tagInput + "\n")
        let state = uiState
        uiState.submitting = true
        uiState.errorMessage = nil
        submitTask?.cancel()
        submitTask = Task { [weak self, addRepository, mapID] in
            let photoURLs: [String]
            if !state.uploadedPhotoURLs.isEmpty || state.photos.isEmpty {
                photoURLs = state.uploadedPhotoURLs
            } else {
                do {
                    photoURLs = try await addRepository.uploadPhotos(mapID: mapID, photos: state.photos)
                    self?.uiState.uploadedPhotoURLs = photoURLs
                } catch {
                    self?.fail(error, message: AddPlaceMessage.photoMessage(for: error))
                    return
                }
            }
            do {
                let newPlace = NewPlace(candidate: candidate, tags: state.tags, memo: state.memo, photoURLs: photoURLs)
                try await addRepository.addPlace(mapID: mapID, newPlace: newPlace)
                try Task.checkCancellation()
                self?.uiState.submitting = false
                self?.uiState.addedMessage = map.addsPlaceDirectly ? AddPlaceMessage.added : AddPlaceMessage.requested
            } catch {
                self?.fail(error, message: AddPlaceMessage.addMessage(for: error))
            }
        }
    }

    private func fail(_ error: any Error, message: String) {
        guard !(error is CancellationError), !Task.isCancelled else { return }
        uiState.submitting = false
        uiState.errorMessage = message
    }
}

nonisolated extension MapDetail {
    var addPlaceButtonLabel: String { addsPlaceDirectly ? "추가하기" : "추가 요청 보내기" }
}

nonisolated enum AddPlaceMessage {
    static let searchFailed = "장소를 검색하지 못했어요"
    static let photoFailed = "사진을 올리지 못했어요"
    static let addFailed = "장소를 추가하지 못했어요"
    static let duplicate = "이미 이 지도에 있는 장소예요"
    /// 승인 대기는 목록에 나타나지 않아 안내가 없으면 사라진 것처럼 보인다.
    static let added = "장소를 추가했어요"
    static let requested = "추가 요청을 보냈어요"

    static func addMessage(for error: any Error) -> String {
        if case .server(code: "PLACE_010", _, _) = error as? NetworkError { return duplicate }
        return MapDetailMessage.userMessage(for: error, fallback: addFailed)
    }

    /// 형식·크기 문제는 사진을 바꿔야 하는 일이라 이유를 그대로 보여준다.
    static func photoMessage(for error: any Error) -> String {
        if let error = error as? ImageUploadError { return error.userMessage }
        return MapDetailMessage.userMessage(for: error, fallback: photoFailed)
    }
}

/// 스페이스나 줄바꿈이 들어오면 그 앞까지를 태그로 확정한다.
nonisolated enum TagInput {
    /// 서버가 태그 하나를 30자로 제한한다.
    static let maxLength = 30

    /// 붙여넣기로 여러 개가 한 번에 들어올 수 있어 구분자마다 끊는다.
    static func apply(tags: [String], rawInput: String) -> (tags: [String], input: String) {
        let delimiters: Set<Character> = [" ", "\n"]
        guard rawInput.contains(where: delimiters.contains) else { return (tags, rawInput) }
        let pieces = rawInput.split(omittingEmptySubsequences: false, whereSeparator: delimiters.contains)
        var next = tags
        // 마지막 조각은 구분자 뒤에 남은 부분이라 아직 입력 중이다.
        for piece in pieces.dropLast() {
            let tag = String(piece.trimmingCharacters(in: .whitespaces).prefix(maxLength))
            if !tag.isEmpty && !next.contains(tag) { next.append(tag) }
        }
        return (next, String(pieces.last ?? ""))
    }
}
