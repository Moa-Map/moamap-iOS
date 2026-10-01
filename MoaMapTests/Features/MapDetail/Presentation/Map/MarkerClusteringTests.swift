import CoreLocation
import Testing
@testable import MoaMap

private func marker(_ id: Int64, latitude: Double, longitude: Double) -> PlaceMarker {
    PlaceMarker(place: MapPlace(id: id, name: "장소 \(id)", address: "", latitude: latitude, longitude: longitude, photoURL: nil))
}

/// 약 100m 떨어진 두 곳.
private let first = marker(1, latitude: 37.4960, longitude: 126.9570)
private let second = marker(2, latitude: 37.4966, longitude: 126.9578)

struct MarkerClusteringTests {
    @Test func 충분히_확대하면_두_마커가_각각_표시된다() {
        let clusters = MarkerClustering.cluster([first, second], zoom: 18)
        #expect(clusters.map(\.members) == [[first], [second]])
    }

    @Test func 줌을_낮추면_하나로_묶인다() {
        let clusters = MarkerClustering.cluster([first, second], zoom: 14)
        #expect(clusters.count == 1)
        #expect(clusters[0].members == [first, second])
    }

    @Test func 묶음의_id_와_앵커는_시드를_따른다() {
        let cluster = MarkerClustering.cluster([first, second], zoom: 14)[0]
        #expect(cluster.id == 1)
        #expect(cluster.anchor.latitude == first.coordinate.latitude)
        #expect(cluster.anchor.longitude == first.coordinate.longitude)
    }

    @Test func 묶이고_갈라져도_시드의_id_는_남는다() {
        let zoomedOut = MarkerClustering.cluster([first, second], zoom: 14).map(\.id)
        let zoomedIn = MarkerClustering.cluster([first, second], zoom: 18).map(\.id)
        #expect(zoomedOut == [1])
        #expect(zoomedIn.contains(1))
    }

    @Test func 앵커끼리는_임계값보다_가까워지지_않는다() {
        var generator = SystemRandomNumberGenerator()
        for _ in 0..<50 {
            let markers = (0..<12).map { index in
                marker(Int64(index), latitude: 37.49 + Double.random(in: 0...0.01, using: &generator),
                       longitude: 126.95 + Double.random(in: 0...0.01, using: &generator))
            }
            let zoom = 15.0
            let anchors = MarkerClustering.cluster(markers, zoom: zoom).map(\.anchor)
            for (index, a) in anchors.enumerated() {
                for b in anchors.dropFirst(index + 1) {
                    let dx = MarkerClustering.worldX(longitude: a.longitude, zoom: zoom) - MarkerClustering.worldX(longitude: b.longitude, zoom: zoom)
                    let dy = MarkerClustering.worldY(latitude: a.latitude, zoom: zoom) - MarkerClustering.worldY(latitude: b.latitude, zoom: zoom)
                    #expect((dx * dx + dy * dy).squareRoot() > MarkerClustering.thresholdPoints)
                }
            }
        }
    }

    @Test func 마커가_없으면_빈_목록이다() {
        #expect(MarkerClustering.cluster([], zoom: 14).isEmpty)
    }

    @Test func 투영을_되돌리면_원래_좌표가_나온다() {
        let zoom = 15.3
        let x = MarkerClustering.worldX(longitude: 126.9574, zoom: zoom)
        let y = MarkerClustering.worldY(latitude: 37.4963, zoom: zoom)
        #expect(abs(MarkerClustering.longitude(worldX: x, zoom: zoom) - 126.9574) < 1e-9)
        #expect(abs(MarkerClustering.latitude(worldY: y, zoom: zoom) - 37.4963) < 1e-9)
    }

    @Test func 화면_경계_안의_마커만_입력_순서대로_남긴다() {
        let far = marker(3, latitude: 37.6, longitude: 127.1)
        let visible = MarkerClustering.cull(
            [second, far, first],
            center: CLLocationCoordinate2D(latitude: 37.4963, longitude: 126.9574),
            zoom: 16,
            size: CGSize(width: 393, height: 600)
        )
        #expect(visible == [second, first])
    }

    @Test(arguments: [14.0, 16.0, 19.0, 21.0])
    func 아무리_확대해도_화면_한복판_마커는_살아남는다(zoom: Double) {
        let center = CLLocationCoordinate2D(latitude: 37.4963, longitude: 126.9574)
        let key = ClusterCameraKey(zoom: zoom, center: center)
        let middle = marker(9, latitude: center.latitude, longitude: center.longitude)
        let clusters = key.clusters(of: [middle], size: CGSize(width: 393, height: 600))
        #expect(clusters.map(\.id) == [9])
    }
}

struct InitialCameraTests {
    private func place(_ id: Int64, _ latitude: Double, _ longitude: Double) -> MapPlace {
        MapPlace(id: id, name: "", address: "", latitude: latitude, longitude: longitude, photoURL: nil)
    }

    private let location = CLLocationCoordinate2D(latitude: 35.1, longitude: 129.0)

    @Test func 장소가_둘_이상이면_전부_담기게_맞춘다() {
        let camera = InitialCamera(places: [place(1, 37.5, 127.0), place(2, 37.6, 127.1)], deviceLocation: location)
        #expect(camera == .fit([.init(latitude: 37.5, longitude: 127.0), .init(latitude: 37.6, longitude: 127.1)]))
    }

    @Test func 장소가_하나면_그_자리를_중심으로_둔다() {
        #expect(InitialCamera(places: [place(1, 37.5, 127.0)], deviceLocation: location) == .center(.init(latitude: 37.5, longitude: 127.0)))
    }

    @Test func 장소가_없으면_현재_위치를_쓰고_그것도_없으면_고정_좌표로_간다() {
        #expect(InitialCamera(places: [], deviceLocation: location) == .center(location))
        #expect(InitialCamera(places: [], deviceLocation: nil) == .center(MapCameraDefaults.center))
    }

    @Test func 좌표가_0인_장소는_빼고_센다() {
        let camera = InitialCamera(places: [place(1, 0, 0), place(2, 37.5, 127.0)], deviceLocation: nil)
        #expect(camera == .center(.init(latitude: 37.5, longitude: 127.0)))
        #expect(InitialCamera(places: [place(1, 0, 0)], deviceLocation: location) == .center(location))
    }
}
