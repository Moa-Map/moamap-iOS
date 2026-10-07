import MapboxMaps
import SwiftUI

/// 장소 마커를 찍는 지도. 미리보기와 상세가 함께 쓴다. 겹치는 마커는 묶어서 그린다.
struct PlaceMarkerMap: View {
    let places: [MapPlace]
    @Binding var viewport: Viewport
    /// 미리보기처럼 되돌릴 버튼이 없는 화면에서는 회전과 기울기를 닫는다.
    var allowsRotation = true
    var shows3DObjects = false
    /// 위치 권한이 있을 때만 켠다. 지도 라이브러리는 내 위치를 그리려 할 때 권한을 스스로 묻는다.
    var showsMyLocation = false
    var onCameraChanged: ((CameraState) -> Void)?
    var onMarkerTap: ((Int64) -> Void)?
    var onClusterTap: ((MarkerCluster) -> Void)?

    @State private var cameraKey = ClusterCameraKey(zoom: MapCameraDefaults.zoom, center: nil)
    /// 다른 화면이 위에 쌓이면 지도는 살아 있어도 가려진다. 그동안은 내 위치를 받지 않는다.
    @State private var onScreen = false

    var body: some View {
        GeometryReader { proxy in
            let clusters = cameraKey.clusters(of: places.map(PlaceMarker.init(place:)), size: proxy.size)
            Map(viewport: $viewport) {
                if showsMyLocation && onScreen { Puck2D.myLocation }
                ForEvery(clusters) { cluster in
                    MapViewAnnotation(coordinate: cluster.anchor) {
                        marker(cluster)
                    }
                    .allowOverlap(true)
                    // 기본값은 내 위치 점과 겹치면 마커를 숨긴다. 장소 바로 앞에 서 있으면 그 장소가 사라지므로 겹쳐도 그린다.
                    .allowOverlapWithPuck(true)
                    .variableAnchors([ViewAnnotationAnchorConfig(anchor: .bottom)])
                }
            }
            .mapStyle(.standard(lightPreset: .day, show3dObjects: shows3DObjects))
            // 축척과 나침반은 띄우지 않는다. 로고와 저작권 표시는 약관상 남기되, 상세에서는 시트 밑에 깔린다.
            .ornamentOptions(OrnamentOptions(
                scaleBar: ScaleBarViewOptions(visibility: .hidden),
                compass: CompassViewOptions(visibility: .hidden)
            ))
            .gestureOptions(GestureOptions(rotateEnabled: allowsRotation, pitchEnabled: allowsRotation))
            .onCameraChanged { event in
                let key = ClusterCameraKey(zoom: event.cameraState.zoom, center: event.cameraState.center)
                if key != cameraKey { cameraKey = key }
                onCameraChanged?(event.cameraState)
            }
        }
        .onAppear { onScreen = true }
        .onDisappear { onScreen = false }
    }

    @ViewBuilder
    private func marker(_ cluster: MarkerCluster) -> some View {
        if cluster.isSingle {
            PlacePhotoMarker(marker: cluster.members[0])
                .onTapGesture { onMarkerTap?(cluster.id) }
                .allowsHitTesting(onMarkerTap != nil)
        } else {
            PlaceFacepileMarker(cluster: cluster)
                .onTapGesture { onClusterTap?(cluster) }
                .allowsHitTesting(onClusterTap != nil)
        }
    }
}

extension Viewport {
    /// 처음 카메라. 여러 곳이면 전부 담기게 맞추되 `maxZoom` 보다 당기지 않는다.
    static func initial(_ camera: InitialCamera, padding: SwiftUI.EdgeInsets, maxZoom: Double = MapCameraDefaults.zoom) -> Viewport {
        switch camera {
        case .fit(let points):
            .overview(geometry: MultiPoint(points), geometryPadding: padding, maxZoom: maxZoom)
        case .center(let point):
            .camera(center: point, zoom: maxZoom)
        }
    }
}
