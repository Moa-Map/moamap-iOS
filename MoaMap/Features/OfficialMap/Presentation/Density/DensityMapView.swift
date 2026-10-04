import MapboxMaps
import SwiftUI

struct DensityMapView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: DensityMapViewModel
    private let title: String
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
    init(viewModel: DensityMapViewModel, title: String) {
        _viewModel = State(initialValue: viewModel)
        self.title = title
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background { colors.backgroundSecondary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { viewModel.start() }
    }

    private var topBar: some View {
        ZStack {
            Text(title)
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
            HStack {
                Button { dismiss() } label: {
                    Image("Icons/arrow-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(colors.textNormal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")
                Spacer()
                // 저장 기능은 아직 없다. Android 도 누를 수 없게 두었다.
                Image("Icons/bookmark-outline")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(colors.textNormal)
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding - 6)
        }
        .frame(height: 58)
    }

    private var content: some View {
        let state = viewModel.uiState
        return map(areas: state.visibleAreas, selected: state.selectedArea)
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

    private func map(areas: [DensityArea], selected: DensityArea?) -> some View {
        Map(viewport: $viewport) {
            GeoJSONSource(id: Id.source)
                .data(.featureCollection(FeatureCollection(features: areas.densityFeatures())))
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

#Preview {
    NavigationStack {
        DensityMapView(viewModel: DensityMapViewModel(repository: PreviewFootTrafficRepository()), title: FootTrafficMap.name)
    }
}
#endif
