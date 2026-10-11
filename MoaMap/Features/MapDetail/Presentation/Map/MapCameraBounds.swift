import MapboxMaps

extension CameraBoundsOptions {
    /// 국내 밖으로 이동·축소하지 못하게 막는 범위. 지도를 그리는 모든 화면이 `Map` 에 건다.
    static var korea: CameraBoundsOptions {
        CameraBoundsOptions(
            bounds: CoordinateBounds(
                southwest: MapCameraDefaults.boundsSouthWest,
                northeast: MapCameraDefaults.boundsNorthEast
            ),
            minZoom: MapCameraDefaults.minZoom
        )
    }
}
