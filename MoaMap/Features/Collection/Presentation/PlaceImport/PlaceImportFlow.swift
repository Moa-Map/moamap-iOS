import SwiftUI

/// 링크 입력 → 로딩 → 장소 선택 → 편집 → 지도 선택. 편집은 목록과 장소 하나를 고치는 화면으로 나뉜다.
nonisolated enum PlaceImportStep: Hashable, Sendable {
    case url
    case loading
    case places
    case edit
    case editDetail(placeID: String)
    case maps
}

/// 흐름 안의 이동. 단계들은 내비게이션 스택 맨 위에 이어 쌓인다.
struct PlaceImportNavigator {
    /// 지금 쌓여 있는 단계. 흐름 밖 화면은 빠져 있다.
    let steps: () -> [PlaceImportStep]
    let setSteps: ([PlaceImportStep]) -> Void

    func push(_ step: PlaceImportStep) { setSteps(steps() + [step]) }
    func pop() { setSteps(Array(steps().dropLast())) }
    /// 흐름을 통째로 닫는다.
    func finish() { setSteps([]) }

    /// 끝난 로딩은 스택에서 지운다. 재시도로 들어왔으면 아래 장소 선택으로 돌아간다.
    func showPlaces() {
        var next = Array(steps().dropLast())
        if next.last != .places { next.append(.places) }
        setSteps(next)
    }
}

/// 단계마다 화면을 고르고, 같은 ViewModel 을 넘긴다.
struct PlaceImportDestination: View {
    let step: PlaceImportStep
    let viewModel: PlaceImportViewModel
    let navigator: PlaceImportNavigator

    var body: some View {
        switch step {
        case .url:
            PlaceImportURLView(viewModel: viewModel, onBack: navigator.pop, onSearch: search)
        case .loading:
            PlaceImportLoadingStep(viewModel: viewModel, navigator: navigator)
        case .places:
            PlaceImportPlaceView(viewModel: viewModel, onBack: navigator.pop, onRetry: search) {
                navigator.push(.edit)
            }
        case .edit:
            PlaceImportEditView(
                viewModel: viewModel,
                onBack: navigator.pop,
                onEdit: { navigator.push(.editDetail(placeID: $0)) },
                onNext: { navigator.push(.maps) }
            )
        case .editDetail(let placeID):
            if let place = viewModel.uiState.selectedPlaces.first(where: { $0.id == placeID }) {
                PlaceImportEditDetailView(viewModel: viewModel, place: place, onDone: navigator.pop)
            }
        case .maps:
            PlaceImportMapView(viewModel: viewModel, onBack: navigator.pop)
                // 한 곳이라도 들어갔으면 흐름을 끝낸다. 하나도 못 넣으면 남아서 안내만 띄운다.
                .onChange(of: viewModel.uiState.saveResult) { _, result in
                    if result != nil { navigator.finish() }
                }
        }
    }

    private func search() {
        viewModel.startExtraction()
        navigator.push(.loading)
    }
}

/// 추출이 끝나면 로딩을 지우고 넘어간다. 실패하면 직전 화면으로 돌아가고, 그 화면이 안내를 띄운다.
private struct PlaceImportLoadingStep: View {
    let viewModel: PlaceImportViewModel
    let navigator: PlaceImportNavigator
    /// 밀어서 이미 빠져나간 뒤에는 이동하지 않는다. 한 번 더 빠지면 링크 입력까지 닫힌다.
    @State private var active = true

    var body: some View {
        // 취소하면 직전 결과가 돌아오고, 아래 onChange 가 그에 맞춰 빠져나간다.
        PlaceImportLoadingView(source: viewModel.uiState.source, onCancel: viewModel.cancelExtraction)
            .onChange(of: viewModel.uiState.extraction, initial: true) { _, extraction in
                guard active else { return }
                switch extraction {
                case .loading: break
                case .loaded where viewModel.uiState.errorMessage == nil: navigator.showPlaces()
                default: navigator.pop()
                }
            }
            .onDisappear {
                active = false
                viewModel.cancelExtraction()
            }
    }
}

#if DEBUG
@MainActor
final class PreviewPlaceImportRepository: PlaceImportRepository {
    private let places = [
        ImportedPlace(id: "1", name: "커피나무", roadAddress: "서울시 동작구 369", kakaoPlaceID: "1"),
        ImportedPlace(id: "2", name: "블루보틀 성수", roadAddress: "서울시 성동구 아차산로 7", kakaoPlaceID: "2"),
        ImportedPlace(id: "3", name: "노티드 도넛", roadAddress: "서울시 강남구 압구정로 42길", kakaoPlaceID: "3")
    ]

    func extractInstagramPlaces(url: String) async throws -> [ImportedPlace] { places }
    func extractMapSharePlaces(url: String) async throws -> [ImportedPlace] { places }
    func uploadPhotos(mapID: Int64, places: [EditedPlace]) async throws -> [String: [String]] { [:] }
    func savePlaces(mapIDs: [Int64], places: [EditedPlace], photoURLs: [String: [String]]) async throws -> PlaceSaveResult {
        PlaceSaveResult(created: places.count, duplicate: 0, failed: 0)
    }
}

#Preview {
    @Previewable @State var steps: [PlaceImportStep] = []
    let viewModel = PlaceImportViewModel(
        source: .instagram, url: "https://www.instagram.com/reel/ABC123/",
        importRepository: PreviewPlaceImportRepository(), collectionRepository: PreviewCollectionRepository()
    )
    NavigationStack(path: $steps) {
        PlaceImportDestination(step: .url, viewModel: viewModel, navigator: PlaceImportNavigator(
            steps: { [.url] + steps }, setSteps: { steps = Array($0.dropFirst()) }
        ))
        .navigationDestination(for: PlaceImportStep.self) { step in
            PlaceImportDestination(step: step, viewModel: viewModel, navigator: PlaceImportNavigator(
                steps: { [.url] + steps }, setSteps: { steps = Array($0.dropFirst()) }
            ))
        }
    }
}
#endif
