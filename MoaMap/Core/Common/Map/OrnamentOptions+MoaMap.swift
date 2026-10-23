@_spi(Restricted) import MapboxMaps

extension OrnamentOptions {
    /// 지도 위 장식을 모두 숨긴다. 출처 표기는 설정의 지도 데이터 출처 화면에 둔다.
    static var moaMap: OrnamentOptions {
        var logo = LogoViewOptions()
        logo.visibility = .hidden
        var attributionButton = AttributionButtonOptions()
        attributionButton.visibility = .hidden
        return OrnamentOptions(
            scaleBar: ScaleBarViewOptions(visibility: .hidden),
            compass: CompassViewOptions(visibility: .hidden),
            logo: logo,
            attributionButton: attributionButton
        )
    }
}
