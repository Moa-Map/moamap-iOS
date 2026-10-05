import MapboxMaps
import SwiftUI

/// 유동인구 지도. 상단바·참여·나가기는 `OfficialMapScaffold` 가 지도 상세 것을 그대로 쓴다.
struct DensityMapView: View {
    @State private var viewModel: DensityMapViewModel
    private let membership: MapDetailViewModel
    private let title: String
    private let onBack: (_ joinedHere: Bool) -> Void
    /// 서울 전역이 보이는 처음 카메라.
    @State private var viewport: Viewport = .camera(
        center: CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780), zoom: 10.5
    )

    private enum Id {
        static let source = "density"
        static let selectedSource = "density-selected"
        static let fill = "density-fill"
    }

    /// 부모가 다시 그려져도 처음 받은 ViewModel 을 쓴다.
    init(
        viewModel: DensityMapViewModel,
        membership: MapDetailViewModel,
        title: String,
        onBack: @escaping (_ joinedHere: Bool) -> Void
    ) {
        _viewModel = State(initialValue: viewModel)
        self.membership = membership
        self.title = title
        self.onBack = onBack
    }

    var body: some View {
        OfficialMapScaffold(membership: membership, initialTitle: title, onBack: onBack) {
            ZStack {
                switch viewModel.uiState.load {
                case .loading:
                    ProgressView()
                case .failed(let message):
                    CommunityMapsError(message: message) { viewModel.retry() }
                case .loaded:
                    content
                }
            }
        }
        .onAppear { viewModel.start() }
    }

    private var content: some View {
        let state = viewModel.uiState
        return map(features: viewModel.visibleFeatures, selected: state.selectedArea)
            .overlay(alignment: .top) {
                CongestionFilterChips(selected: state.filterLevel) { viewModel.selectLevel($0) }
                    .padding(.top, 18)
            }
            .overlay(alignment: .bottom) {
                if let area = state.selectedArea {
                    AreaInfoCard(area: area)
                        .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                        .padding(.bottom, 30)
                }
            }
    }

    private func map(features: [Feature], selected: DensityArea?) -> some View {
        Map(viewport: $viewport) {
            GeoJSONSource(id: Id.source)
                .data(.featureCollection(FeatureCollection(features: features)))
            // 평소에는 옅게 채우고 경계를 흐리게 번지게 한다.
            FillLayer(id: Id.fill, source: Id.source)
                .fillColor(Self.levelColor)
                .fillOpacity(0.35)
            LineLayer(id: "density-line", source: Id.source)
                .lineColor(Self.levelColor)
                .lineWidth(10)
                .lineBlur(8)
                .lineOpacity(0.5)
            // 고른 지역은 진하게 채우고 테두리를 또렷하게 그린다.
            GeoJSONSource(id: Id.selectedSource)
                .data(.featureCollection(FeatureCollection(features: [selected].compactMap { $0 }.densityFeatures())))
            FillLayer(id: "density-selected-fill", source: Id.selectedSource)
                .fillColor(Self.levelColor)
                .fillOpacity(0.55)
            LineLayer(id: "density-selected-line", source: Id.selectedSource)
                .lineColor(Self.levelColor)
                .lineWidth(2.5)
            TapInteraction(.layer(Id.fill)) { feature, _ in
                guard case .string(let code) = feature.properties["code"] else { return false }
                viewModel.selectArea(code)
                return true
            }
            // 지역이 받은 탭은 여기까지 오지 않는다. 빈 곳을 눌렀을 때만 온다.
            TapInteraction { _ in
                viewModel.clearSelection()
                return true
            }
        }
        .mapStyle(.standard(lightPreset: .day))
        .ornamentOptions(OrnamentOptions(
            scaleBar: ScaleBarViewOptions(visibility: .hidden),
            compass: CompassViewOptions(visibility: .hidden)
        ))
    }

    /// 피처의 `level` 로 레벨 색을 고른다.
    private static let levelColor = Exp(.match) {
        Exp(.get) { "level" }
        CongestionLevel.relaxed.rawValue
        UIColor(CongestionLevel.relaxed.color)
        CongestionLevel.normal.rawValue
        UIColor(CongestionLevel.normal.color)
        CongestionLevel.slightlyBusy.rawValue
        UIColor(CongestionLevel.slightlyBusy.color)
        CongestionLevel.busy.rawValue
        UIColor(CongestionLevel.busy.color)
        UIColor(CongestionLevel.unknown.color)
    }
}

#if DEBUG
@MainActor
final class PreviewFootTrafficRepository: FootTrafficRepository {
    func fetchDensityAreas() async throws -> [DensityArea] { [] }
}
#endif
