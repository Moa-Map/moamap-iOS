import CoreLocation
import Testing
import Turf
@testable import MoaMap

struct CongestionStyleTests {
    @Test func 경계가_있는_지역만_코드와_레벨을_담은_피처로_만든다() throws {
        let polygon = Geometry.polygon(Polygon([[
            LocationCoordinate2D(latitude: 37.50, longitude: 126.89),
            LocationCoordinate2D(latitude: 37.50, longitude: 126.90),
            LocationCoordinate2D(latitude: 37.51, longitude: 126.90),
            LocationCoordinate2D(latitude: 37.50, longitude: 126.89)
        ]]))
        let areas = [
            DensityArea(code: "A", name: "A", latitude: 37.5, longitude: 126.9, boundary: polygon, congestion: nil),
            DensityArea(code: "B", name: "B", latitude: 37.5, longitude: 126.9, boundary: nil, congestion: nil)
        ]
        let features = areas.densityFeatures()
        #expect(features.count == 1)
        #expect(features[0].geometry == polygon)
        #expect(features[0].properties?["code"] == .string("A"))
        #expect(features[0].properties?["level"] == .string("unknown"))
    }
}
