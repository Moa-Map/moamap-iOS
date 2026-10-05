import SwiftUI
import Turf

extension CongestionLevel {
    var color: Color {
        switch self {
        case .relaxed: MoaMapPrimitiveColors.congestionRelaxed
        case .normal: MoaMapPrimitiveColors.congestionNormal
        case .slightlyBusy: MoaMapPrimitiveColors.congestionSlightlyBusy
        case .busy: MoaMapPrimitiveColors.congestionBusy
        case .unknown: MoaMapPrimitiveColors.gray200
        }
    }

    /// 카드 헤더 태그 색. 배경·글자는 레벨 색과 색상(hue)이 같고 명도만 다르다. Android 와 같은 값이다.
    var tagColors: (background: Color, border: Color, content: Color) {
        switch self {
        case .relaxed: (Color(argb: 0xFFEA_FFFC), color, Color(argb: 0xFF15_6B5E))
        case .normal: (Color(argb: 0xFFFF_F8EA), color, Color(argb: 0xFF6B_5015))
        case .slightlyBusy: (Color(argb: 0xFFFF_F2EA), color, Color(argb: 0xFF6B_3715))
        case .busy: (Color(argb: 0xFFFF_EAEB), color, Color(argb: 0xFF6B_151A))
        // 무채색은 같은 규칙을 쓰면 엉뚱한 색이 나와 중립 토큰을 쓴다.
        case .unknown: (MoaMapPrimitiveColors.gray50, MoaMapPrimitiveColors.gray200, MoaMapPrimitiveColors.gray500)
        }
    }
}

nonisolated extension [DensityArea] {
    /// 지도 소스에 넣을 피처. 레이어가 `level` 로 색을, 탭이 `code` 로 지역을 찾는다.
    func densityFeatures() -> [Feature] {
        compactMap { area in
            guard let boundary = area.boundary else { return nil }
            var feature = Feature(geometry: boundary)
            feature.properties = [
                "code": .string(area.code),
                "level": .string((area.congestion?.level ?? .unknown).rawValue)
            ]
            return feature
        }
    }
}
