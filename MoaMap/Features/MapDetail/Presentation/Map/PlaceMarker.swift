import CoreLocation

/// 지도에 사진 마커로 표시할 장소.
nonisolated struct PlaceMarker: Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    let coordinate: CLLocationCoordinate2D
    /// 없으면 카테고리 아이콘이나 기본 그림을 띄운다.
    let photoURL: URL?
    let categoryGroup: PlaceCategoryGroup?

    init(place: MapPlace) {
        id = place.id
        name = place.name
        coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        photoURL = place.photoURL
        categoryGroup = PlaceCategoryGroup(categoryPath: place.category)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.photoURL == rhs.photoURL
            && lhs.categoryGroup == rhs.categoryGroup
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

nonisolated enum MapCameraDefaults {
    /// 장소도 위치도 없을 때 기대는 좌표. 숭실대 캠퍼스 중심이다.
    static let center = CLLocationCoordinate2D(latitude: 37.4963, longitude: 126.9574)
    /// 동네 몇 개가 한눈에 들어오는 배율.
    static let zoom = 14.0
}

/// 처음 지도를 열 때 카메라를 어디에 둘지.
nonisolated enum InitialCamera: Equatable, Sendable {
    /// 여러 장소가 한 화면에 담기게 맞춘다.
    case fit([CLLocationCoordinate2D])
    /// 한 지점을 기본 배율로 본다.
    case center(CLLocationCoordinate2D)

    /// 장소를 현재 위치보다 앞에 둔다. 이 화면은 그 지도의 장소를 보러 들어온 자리다.
    /// (0, 0) 은 좌표가 비어 온 장소라 세지 않는다.
    init(places: [MapPlace], deviceLocation: CLLocationCoordinate2D?) {
        let points = places
            .filter { $0.latitude != 0 || $0.longitude != 0 }
            .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        if points.count >= 2 {
            self = .fit(points)
        } else if let point = points.first ?? deviceLocation {
            self = .center(point)
        } else {
            self = .center(MapCameraDefaults.center)
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.fit(let l), .fit(let r)):
            l.count == r.count && zip(l, r).allSatisfy { $0.latitude == $1.latitude && $0.longitude == $1.longitude }
        case (.center(let l), .center(let r)):
            l.latitude == r.latitude && l.longitude == r.longitude
        default:
            false
        }
    }
}
