import SwiftUI
import UIKit

/// 번들에 넣은 폰트의 PostScript 이름. 파일명이 아니라 이 이름으로 불러야 한다.
nonisolated enum MoaMapFontName {
    static let nanumSquareLight = "NanumSquareOTFL"
    static let nanumSquareRegular = "NanumSquareOTFR"
    static let nanumSquareBold = "NanumSquareOTFB"
    static let nanumSquareExtraBold = "NanumSquareOTFEB"
    static let pretendardRegular = "Pretendard-Regular"
}

nonisolated struct MoaMapTextStyle: Sendable {
    let fontName: String
    let size: CGFloat
    let lineHeight: CGFloat
    let letterSpacing: CGFloat

    /// SwiftUI 의 `lineSpacing` 은 줄 사이에 "더할" 간격이라, 폰트가 이미 차지하는
    /// 줄 높이를 빼야 시안의 line height 와 맞는다.
    var lineSpacing: CGFloat {
        let natural = UIFont(name: fontName, size: size)?.lineHeight ?? size
        return max(0, lineHeight - natural)
    }
}

nonisolated struct MoaMapTypography: Sendable {
    let display1: MoaMapTextStyle
    let display2: MoaMapTextStyle
    let title1: MoaMapTextStyle
    let title2: MoaMapTextStyle
    let title3: MoaMapTextStyle
    let subtitle1: MoaMapTextStyle
    let subtitle2: MoaMapTextStyle
    let subtitle3: MoaMapTextStyle
    let subtitle4: MoaMapTextStyle
    let body1: MoaMapTextStyle
    let body2: MoaMapTextStyle
    let body3: MoaMapTextStyle
    let button0: MoaMapTextStyle
    let button1: MoaMapTextStyle
    let button2: MoaMapTextStyle
    let button3: MoaMapTextStyle
    let button4: MoaMapTextStyle
    let caption0: MoaMapTextStyle
    let caption1: MoaMapTextStyle
    let caption2: MoaMapTextStyle
}

private nonisolated func nanumSquare(
    _ size: CGFloat,
    _ fontName: String,
    _ lineHeightRatio: CGFloat,
    _ letterSpacing: CGFloat
) -> MoaMapTextStyle {
    MoaMapTextStyle(
        fontName: fontName,
        size: size,
        lineHeight: size * lineHeightRatio,
        letterSpacing: letterSpacing
    )
}

nonisolated extension MoaMapTypography {
    static let tokens = MoaMapTypography(
        display1: nanumSquare(32, MoaMapFontName.nanumSquareExtraBold, 1.3, 0.0),
        display2: nanumSquare(28, MoaMapFontName.nanumSquareExtraBold, 1.3, 0.0),
        title1: nanumSquare(24, MoaMapFontName.nanumSquareExtraBold, 1.3, -0.48),
        title2: nanumSquare(20, MoaMapFontName.nanumSquareExtraBold, 1.3, -0.40),
        title3: nanumSquare(18, MoaMapFontName.nanumSquareExtraBold, 1.3, -0.36),
        subtitle1: nanumSquare(18, MoaMapFontName.nanumSquareBold, 1.3, -0.36),
        subtitle2: nanumSquare(16, MoaMapFontName.nanumSquareBold, 1.3, -0.32),
        subtitle3: nanumSquare(16, MoaMapFontName.nanumSquareExtraBold, 1.3, -0.32),
        subtitle4: nanumSquare(15, MoaMapFontName.nanumSquareBold, 1.3, -0.30),
        body1: nanumSquare(15, MoaMapFontName.nanumSquareRegular, 1.5, -0.30),
        body2: nanumSquare(14, MoaMapFontName.nanumSquareRegular, 1.5, -0.28),
        body3: nanumSquare(14, MoaMapFontName.nanumSquareBold, 1.5, -0.28),
        button0: nanumSquare(16, MoaMapFontName.nanumSquareBold, 1.4, -0.32),
        button1: nanumSquare(16, MoaMapFontName.nanumSquareRegular, 1.4, -0.32),
        button2: nanumSquare(14, MoaMapFontName.nanumSquareBold, 1.3, 0.0),
        button3: nanumSquare(14, MoaMapFontName.nanumSquareRegular, 1.3, -0.28),
        button4: nanumSquare(12, MoaMapFontName.nanumSquareRegular, 1.4, -0.24),
        caption0: nanumSquare(12, MoaMapFontName.nanumSquareRegular, 1.3, -0.24),
        caption1: nanumSquare(12, MoaMapFontName.nanumSquareLight, 1.3, -0.24),
        caption2: MoaMapTextStyle(
            fontName: MoaMapFontName.pretendardRegular,
            size: 11,
            lineHeight: 14.3,
            letterSpacing: -0.22
        )
    )
}

extension View {
    func moaTextStyle(_ style: MoaMapTextStyle) -> some View {
        self
            .font(.custom(style.fontName, size: style.size))
            .tracking(style.letterSpacing)
            .lineSpacing(style.lineSpacing)
    }
}
