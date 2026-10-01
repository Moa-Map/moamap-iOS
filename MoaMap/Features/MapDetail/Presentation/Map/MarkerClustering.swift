import CoreLocation
import Foundation

/// 화면 거리 기준으로 가까워 하나로 묶인 마커.
nonisolated struct MarkerCluster: Identifiable, Equatable, Sendable {
    let members: [PlaceMarker]

    /// 시드(첫 구성원)의 id. 묶음이 합쳐지거나 갈라져도 유지돼 마커 뷰가 다시 만들어지지 않는다.
    var id: Int64 { members[0].id }
    var isSingle: Bool { members.count == 1 }
    /// 시드 좌표에 고정한다. 평균 좌표를 쓰면 버블끼리 임계값보다 가까워져 겹친다.
    var anchor: CLLocationCoordinate2D { members[0].coordinate }
}

/// 웹 메르카토르 투영과 클러스터링. 단위는 pt 다.
nonisolated enum MarkerClustering {
    /// 마커 버블 지름(56) + 최소 여백(16). 이보다 가까우면 하나로 묶는다.
    static let thresholdPoints = 72.0
    /// 카메라 줌은 제스처 도중 매 프레임 바뀐다. 이 단위로 내려 재계산을 줄인다.
    static let zoomStep = 0.25
    /// 컬링 경계를 다시 계산하는 중심 이동 간격(pt). 경계가 어긋나는 만큼을 `cullMargin` 이 덮어야 한다.
    static let centerStepPoints = 16.0
    /// 기울기·회전을 셈에 넣지 않는 오차를 덮는 경계 여유. 폭·높이의 비율이다.
    static let cullMargin = 0.3

    private static let tileSize = 512.0
    private static let maxLatitude = 85.05112878

    static func worldX(longitude: Double, zoom: Double) -> Double {
        (longitude + 180) / 360 * worldSize(zoom)
    }

    static func worldY(latitude: Double, zoom: Double) -> Double {
        let radians = min(max(latitude, -maxLatitude), maxLatitude) * .pi / 180
        let mercator = log(tan(.pi / 4 + radians / 2))
        return (1 - mercator / .pi) / 2 * worldSize(zoom)
    }

    static func longitude(worldX x: Double, zoom: Double) -> Double {
        x / worldSize(zoom) * 360 - 180
    }

    static func latitude(worldY y: Double, zoom: Double) -> Double {
        let mercator = (1 - 2 * y / worldSize(zoom)) * .pi
        return (2 * atan(exp(mercator)) - .pi / 2) * 180 / .pi
    }

    /// 그 줌에서 화면 1pt 에 해당하는 경도(도).
    static func degreesPerPoint(zoom: Double) -> Double { 360 / worldSize(zoom) }

    static func quantizeZoom(_ zoom: Double) -> Double {
        (zoom / zoomStep).rounded(.down) * zoomStep
    }

    /// 중심을 `centerStepPoints` 격자에 맞춰 내린다. 도가 아니라 화면 거리로 잡아야 확대해도 어긋남이 묶인다.
    static func quantizeCenter(_ degrees: Double, zoom: Double) -> Double {
        let step = centerStepPoints * degreesPerPoint(zoom: zoom)
        return (degrees / step).rounded(.down) * step
    }

    /// 입력 순서를 지키는 그리디. 같은 입력이면 같은 결과라 묶음 id 가 안정적이다.
    static func cluster(_ markers: [PlaceMarker], zoom: Double, threshold: Double = thresholdPoints) -> [MarkerCluster] {
        let xs = markers.map { worldX(longitude: $0.coordinate.longitude, zoom: zoom) }
        let ys = markers.map { worldY(latitude: $0.coordinate.latitude, zoom: zoom) }
        let thresholdSquared = threshold * threshold
        var taken = [Bool](repeating: false, count: markers.count)
        var clusters: [MarkerCluster] = []
        for seed in markers.indices where !taken[seed] {
            taken[seed] = true
            var members = [markers[seed]]
            for candidate in markers.indices.dropFirst(seed + 1) where !taken[candidate] {
                let dx = xs[seed] - xs[candidate]
                let dy = ys[seed] - ys[candidate]
                if dx * dx + dy * dy <= thresholdSquared {
                    taken[candidate] = true
                    members.append(markers[candidate])
                }
            }
            clusters.append(MarkerCluster(members: members))
        }
        return clusters
    }

    /// 화면 경계(여유 포함) 안의 마커만 남긴다. 화면 밖까지 마커 뷰를 만들면 장소가 많은 지도에서 버티지 못한다.
    static func cull(
        _ markers: [PlaceMarker],
        center: CLLocationCoordinate2D,
        zoom: Double,
        size: CGSize,
        margin: Double = cullMargin
    ) -> [PlaceMarker] {
        let halfWidth = size.width / 2 * (1 + margin)
        let halfHeight = size.height / 2 * (1 + margin)
        let centerX = worldX(longitude: center.longitude, zoom: zoom)
        let centerY = worldY(latitude: center.latitude, zoom: zoom)
        let west = longitude(worldX: centerX - halfWidth, zoom: zoom)
        let east = longitude(worldX: centerX + halfWidth, zoom: zoom)
        // 월드 y 는 아래로 갈수록 커져 위도와 반대다.
        let north = latitude(worldY: centerY - halfHeight, zoom: zoom)
        let south = latitude(worldY: centerY + halfHeight, zoom: zoom)
        return markers.filter {
            (west...east).contains($0.coordinate.longitude) && (south...north).contains($0.coordinate.latitude)
        }
    }

    private static func worldSize(_ zoom: Double) -> Double { tileSize * pow(2, zoom) }
}

/// 클러스터링에 넣을 카메라 값. 양자화해 두어 실제로 한 칸 움직였을 때만 다시 센다.
nonisolated struct ClusterCameraKey: Equatable, Sendable {
    let zoom: Double
    /// 카메라가 아직 없으면 nil 이고 컬링을 건너뛴다.
    let centerLatitude: Double?
    let centerLongitude: Double?

    init(zoom: Double, center: CLLocationCoordinate2D?) {
        let zoom = MarkerClustering.quantizeZoom(zoom)
        self.zoom = zoom
        centerLatitude = center.map { MarkerClustering.quantizeCenter($0.latitude, zoom: zoom) }
        centerLongitude = center.map { MarkerClustering.quantizeCenter($0.longitude, zoom: zoom) }
    }

    func clusters(of markers: [PlaceMarker], size: CGSize) -> [MarkerCluster] {
        guard let centerLatitude, let centerLongitude else {
            return MarkerClustering.cluster(markers, zoom: zoom)
        }
        let center = CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
        let visible = MarkerClustering.cull(markers, center: center, zoom: zoom, size: size)
        return MarkerClustering.cluster(visible, zoom: zoom)
    }
}
