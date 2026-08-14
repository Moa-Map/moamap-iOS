import SwiftUI

nonisolated extension Color {
    init(argb: UInt32) {
        self.init(
            .sRGB,
            red: Double((argb >> 16) & 0xFF) / 255,
            green: Double((argb >> 8) & 0xFF) / 255,
            blue: Double(argb & 0xFF) / 255,
            opacity: Double((argb >> 24) & 0xFF) / 255
        )
    }
}

/// 팔레트 원색. 화면에서 직접 쓰지 않고 `MoaMapColors` 를 거친다.
nonisolated enum MoaMapPrimitiveColors {
    static let black = Color(argb: 0xFF00_0000)
    static let white = Color(argb: 0xFFFF_FFFF)
    static let transparentBlack = Color(argb: 0xBF00_0000)

    static let gray50 = Color(argb: 0xFFEC_EDED)
    static let gray100 = Color(argb: 0xFFC5_C7C7)
    static let gray200 = Color(argb: 0xFFA9_ABAC)
    static let gray300 = Color(argb: 0xFF82_8586)
    static let gray400 = Color(argb: 0xFF69_6D6F)
    static let gray500 = Color(argb: 0xFF4A_4F52)
    static let gray600 = Color(argb: 0xFF3E_4244)
    static let gray700 = Color(argb: 0xFF30_3435)
    static let gray800 = Color(argb: 0xFF25_2829)
    static let gray900 = Color(argb: 0xFF1D_1F20)

    static let yellow50 = Color(argb: 0xFFFF_FAEA)
    static let yellow100 = Color(argb: 0xFFFF_EEBF)
    static let yellow200 = Color(argb: 0xFFFF_E6A0)
    static let yellow300 = Color(argb: 0xFFFF_DA75)
    static let yellow400 = Color(argb: 0xFFFF_D35A)
    static let yellow500 = Color(argb: 0xFFFF_C831)
    static let yellow600 = Color(argb: 0xFFE8_B62D)
    static let yellow700 = Color(argb: 0xFFB5_8E23)
    static let yellow800 = Color(argb: 0xFF8C_6E1B)
    static let yellow900 = Color(argb: 0xFF6B_5415)

    static let blue50 = Color(argb: 0xFFE6_F6FF)
    static let blue100 = Color(argb: 0xFFB3_E4FD)
    static let blue200 = Color(argb: 0xFF8E_D7FD)
    static let blue300 = Color(argb: 0xFF5A_C5FC)
    static let blue400 = Color(argb: 0xFF3A_B9FB)
    static let blue500 = Color(argb: 0xFF09_A8FA)
    static let blue600 = Color(argb: 0xFF08_99E4)
    static let blue700 = Color(argb: 0xFF06_77B2)
    static let blue800 = Color(argb: 0xFF05_5C8A)
    static let blue900 = Color(argb: 0xFF04_4769)

    static let textNormal = Color(argb: 0xFF15_1617)
    static let backgroundSecondary = Color(argb: 0xFFF7_F9FA)
    static let statusAlert = Color(argb: 0xFFFB_1921)
    static let statusCaution = Color(argb: 0xFFFC_912F)
    static let statusPositive = Color(argb: 0xFF1E_9E6A)
    static let lineNormal = Color(argb: 0xFFD5_DBDB)

    // 혼잡도 램프. 지도 폴리곤 위에서 4단계가 균일한 무게로 읽히도록 명도를
    // 38~50% 대에 모아둔 별도 세트다.
    static let congestionRelaxed = Color(argb: 0xFF10_B39A)
    static let congestionNormal = Color(argb: 0xFFE0_A21A)
    static let congestionSlightlyBusy = Color(argb: 0xFFEA_6A17)
    static let congestionBusy = Color(argb: 0xFFD0_1620)
}

nonisolated struct MoaMapColors: Sendable {
    let primary: Color
    let secondary: Color
    let textNormal: Color
    let textAlternative: Color
    let textAssistive: Color
    let textDisable: Color
    let textWhite: Color
    let backgroundPrimary: LinearGradient
    let backgroundSecondary: Color
    let statusAlert: Color
    let statusCaution: Color
    let statusPositive: Color
    let lineNormal: Color
    let lineAlternative: Color
}

nonisolated extension MoaMapColors {
    /// 다크 테마는 없다.
    static let light = MoaMapColors(
        primary: MoaMapPrimitiveColors.blue500,
        secondary: MoaMapPrimitiveColors.yellow500,
        textNormal: MoaMapPrimitiveColors.textNormal,
        textAlternative: MoaMapPrimitiveColors.gray500,
        textAssistive: MoaMapPrimitiveColors.gray300,
        textDisable: MoaMapPrimitiveColors.gray100,
        textWhite: MoaMapPrimitiveColors.white,
        backgroundPrimary: LinearGradient(
            colors: [MoaMapPrimitiveColors.blue100, MoaMapPrimitiveColors.white],
            startPoint: .top,
            endPoint: .bottom
        ),
        backgroundSecondary: MoaMapPrimitiveColors.backgroundSecondary,
        statusAlert: MoaMapPrimitiveColors.statusAlert,
        statusCaution: MoaMapPrimitiveColors.statusCaution,
        statusPositive: MoaMapPrimitiveColors.statusPositive,
        lineNormal: MoaMapPrimitiveColors.lineNormal,
        lineAlternative: MoaMapPrimitiveColors.gray50
    )
}
