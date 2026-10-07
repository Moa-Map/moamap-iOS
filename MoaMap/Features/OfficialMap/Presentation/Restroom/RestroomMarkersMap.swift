import MapboxMaps
import SwiftUI

nonisolated enum RestroomMapCamera {
    /// 처음 줌. 화장실이 한도(500)를 넘지 않고 마커가 겹치지 않는 정도.
    static let zoom = 15.0
    /// 현재 위치를 모를 때 보는 자리. 서울 시청 앞.
    static let start = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
}

/// 화장실 마커 지도. 카메라가 멈출 때마다 보이는 범위를 `onCameraIdle` 로 알린다.
///
/// 마커는 많게는 500개라 지도 상세처럼 마커마다 뷰를 띄우지 않고 원 레이어 하나로 그린다.
/// 회전·기울기는 닫는다. 화장실을 찾는 데 쓸 일이 없고, 기울이면 먼 곳까지 범위에 들어간다.
struct RestroomMarkersMap: View {
    let restrooms: [RestroomMarker]
    let selected: RestroomMarker?
    @Binding var viewport: Viewport
    let onCameraIdle: (ViewportBounds) -> Void
    var onCameraChanged: ((CameraState) -> Void)?
    var onRestroomTap: ((Int64) -> Void)?
    /// 마커가 받은 탭은 여기까지 오지 않는다. 빈 곳을 눌렀을 때만 온다.
    var onMapTap: (() -> Void)?
    /// 위치 권한이 있을 때만 켠다. 지도 라이브러리는 내 위치를 그리려 할 때 권한을 스스로 묻는다.
    var showsMyLocation = false

    private enum Id {
        static let source = "restrooms"
        static let selectedSource = "restroom-selected"
        static let layer = "restroom-circle"
        static let property = "id"
    }

    /// 마커가 작아 손끝이 빗나가기 쉽다. 이만큼 떨어져 눌러도 그 마커로 본다.
    private static let tapRadius: CGFloat = 12

    var body: some View {
        MapReader { proxy in
            Map(viewport: $viewport) {
                if showsMyLocation { Puck2D.myLocation }
                GeoJSONSource(id: Id.source)
                    .data(.featureCollection(FeatureCollection(features: restrooms.map(Self.feature))))
                CircleLayer(id: Id.layer, source: Id.source)
                    .circleColor(UIColor(MoaMapPrimitiveColors.blue500))
                    .circleRadius(7)
                    .circleStrokeColor(.white)
                    .circleStrokeWidth(2)
                    // 지도 조명에 따라 색이 어두워지지 않게 한다.
                    .circleEmissiveStrength(1)
                GeoJSONSource(id: Id.selectedSource)
                    .data(.featureCollection(FeatureCollection(features: [selected].compactMap { $0 }.map(Self.feature))))
                CircleLayer(id: "restroom-selected-circle", source: Id.selectedSource)
                    .circleColor(UIColor(MoaMapPrimitiveColors.blue800))
                    .circleRadius(11)
                    .circleStrokeColor(.white)
                    .circleStrokeWidth(3)
                    .circleEmissiveStrength(1)
                TapInteraction(.layer(Id.layer), radius: Self.tapRadius) { feature, _ in
                    guard let onRestroomTap, case .number(let id) = feature.properties[Id.property] else { return false }
                    onRestroomTap(Int64(id))
                    return true
                }
                TapInteraction { _ in
                    guard let onMapTap else { return false }
                    onMapTap()
                    return true
                }
            }
            .mapStyle(.standard(lightPreset: .day, show3dObjects: false))
            .ornamentOptions(OrnamentOptions(
                scaleBar: ScaleBarViewOptions(visibility: .hidden),
                compass: CompassViewOptions(visibility: .hidden)
            ))
            .gestureOptions(GestureOptions(rotateEnabled: false, pitchEnabled: false))
            .onCameraChanged { onCameraChanged?($0.cameraState) }
            .onMapIdle { _ in
                guard let map = proxy.map else { return }
                let bounds = map.coordinateBounds(for: CameraOptions(cameraState: map.cameraState))
                onCameraIdle(ViewportBounds(
                    south: bounds.south, west: bounds.west, north: bounds.north, east: bounds.east
                ))
            }
        }
    }

    private static func feature(_ restroom: RestroomMarker) -> Feature {
        var feature = Feature(geometry: Point(CLLocationCoordinate2D(latitude: restroom.latitude, longitude: restroom.longitude)))
        feature.properties = [Id.property: .number(Double(restroom.id))]
        return feature
    }
}

/// 참여 전 지도 소개의 작은 지도. 화면과 같은 마커를 그리기만 하고 누르는 동작은 없다.
/// 따로 ViewModel 을 둔다. 화장실 화면으로 넘어가면 그쪽이 다시 읽는다.
struct RestroomPreviewMap: View {
    @State private var viewModel: RestroomMapViewModel
    @State private var viewport: Viewport
    /// 소개 화면은 권한을 묻지 않는다. 이미 허용돼 있을 때만 내 위치가 보인다.
    private let showsMyLocation: Bool

    init(viewModel: RestroomMapViewModel, center: CLLocationCoordinate2D?, showsMyLocation: Bool) {
        _viewModel = State(initialValue: viewModel)
        self.showsMyLocation = showsMyLocation
        _viewport = State(initialValue: .camera(center: center ?? RestroomMapCamera.start, zoom: RestroomMapCamera.zoom))
    }

    var body: some View {
        RestroomMarkersMap(
            restrooms: viewModel.uiState.restrooms,
            selected: nil,
            viewport: $viewport,
            onCameraIdle: { viewModel.onCameraIdle($0) },
            showsMyLocation: showsMyLocation
        )
    }
}
