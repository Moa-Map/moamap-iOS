import Foundation
import Observation
import Turf

nonisolated enum DensityLoadState: Equatable, Sendable {
    case loading
    case loaded
    case failed(String)
}

nonisolated struct DensityMapUiState: Equatable, Sendable {
    var load: DensityLoadState = .loading
    var areas: [DensityArea] = []
    var selectedCode: String?
    /// nil 이면 「전체」.
    var filterLevel: CongestionLevel?

    /// 지도와 카드가 함께 보는, 필터를 통과한 지역.
    var visibleAreas: [DensityArea] {
        guard let filterLevel else { return areas }
        return areas.filter { $0.congestion?.level == filterLevel }
    }

    var selectedArea: DensityArea? {
        visibleAreas.first { $0.code == selectedCode }
    }
}

@MainActor @Observable
final class DensityMapViewModel {
    nonisolated static let loadFailedMessage = "밀집도 정보를 불러오지 못했어요"

    private(set) var uiState = DensityMapUiState() {
        // 지역 경계는 크다. 화면을 그릴 때마다 만들지 않고 보이는 지역이 바뀔 때만 만든다.
        didSet {
            if uiState.areas != oldValue.areas || uiState.filterLevel != oldValue.filterLevel {
                visibleFeatures = uiState.visibleAreas.densityFeatures()
            }
        }
    }
    /// 지도 소스에 넣을, 필터를 통과한 지역 피처.
    private(set) var visibleFeatures: [Feature] = []
    private(set) var loadTask: Task<Void, Never>?

    private let repository: any FootTrafficRepository

    init(repository: any FootTrafficRepository) { self.repository = repository }

    /// 화면이 보일 때 부른다. 실시간 값이지만 돌아올 때마다 다시 읽지는 않는다.
    func start() {
        guard uiState.load == .loading, loadTask == nil else { return }
        load()
    }

    func retry() { load() }

    /// 같은 지역을 다시 누르면 선택을 푼다.
    func selectArea(_ code: String) {
        uiState.selectedCode = uiState.selectedCode == code ? nil : code
    }

    /// 지역이 아닌 빈 곳을 눌렀다. 카드를 닫는다.
    func clearSelection() {
        uiState.selectedCode = nil
    }

    /// 같은 레벨을 다시 고르면 전체로 돌아간다.
    func selectLevel(_ level: CongestionLevel?) {
        uiState.filterLevel = uiState.filterLevel == level ? nil : level
        // 보던 지역이 필터 밖으로 나가면 카드도 닫는다.
        if uiState.selectedArea == nil { uiState.selectedCode = nil }
    }

    private func load() {
        loadTask?.cancel()
        uiState.load = .loading
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let areas = try await repository.fetchDensityAreas()
                try Task.checkCancellation()
                self?.uiState.areas = areas
                self?.uiState.load = .loaded
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.load = .failed(Self.loadFailedMessage)
            }
        }
    }
}
