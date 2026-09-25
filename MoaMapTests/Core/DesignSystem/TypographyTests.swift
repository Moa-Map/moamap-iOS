import Testing
import UIKit
import SwiftUI
@testable import MoaMap

/// 폰트 파일 · Info.plist 의 UIAppFonts · PostScript 이름 셋 중 하나만 어긋나도
/// 글자가 시스템 폰트로 조용히 대체된다. 눈으로는 늦게 발견되므로 여기서 잡는다.
@Test(arguments: [
    MoaMapFontName.nanumSquareLight,
    MoaMapFontName.nanumSquareRegular,
    MoaMapFontName.nanumSquareBold,
    MoaMapFontName.nanumSquareExtraBold,
    MoaMapFontName.pretendardRegular,
])
func 등록한_폰트를_이름으로_찾을_수_있다(name: String) {
    #expect(UIFont(name: name, size: 16) != nil, "폰트를 찾지 못했다: \(name)")
}

@Test
func title1_토큰이_원본_값과_같다() {
    let style = MoaMapTypography.tokens.title1

    #expect(style.fontName == MoaMapFontName.nanumSquareExtraBold)
    #expect(style.size == 24)
    #expect(style.lineHeight == 24 * 1.3)
    #expect(style.letterSpacing == -0.48)
}

@Test
func caption2만_Pretendard를_쓴다() {
    #expect(MoaMapTypography.tokens.caption2.fontName == MoaMapFontName.pretendardRegular)
    #expect(MoaMapTypography.tokens.caption1.fontName == MoaMapFontName.nanumSquareLight)
}

/// 시안의 line height 는 한 줄짜리 글자에도 적용된다. 줄 사이 간격만 넣으면 한 줄 텍스트가 폰트 기본 높이로 줄어든다.
@MainActor
@Test(arguments: [
    MoaMapTypography.tokens.title2,
    MoaMapTypography.tokens.subtitle2,
    MoaMapTypography.tokens.body1,
    MoaMapTypography.tokens.button3,
    MoaMapTypography.tokens.caption0,
])
func 텍스트_높이가_시안의_줄_높이와_같다(style: MoaMapTextStyle) {
    func height(_ text: String) -> CGFloat {
        let host = UIHostingController(rootView: Text(text).moaTextStyle(style).fixedSize())
        return host.sizeThatFits(in: CGSize(width: 1000, height: 1000)).height
    }
    // 3배율 화면은 1/3pt 단위로 그려져 글자와 위아래 여백이 각각 한 픽셀씩 올림될 수 있다.
    let tolerance: CGFloat = 2.0 / 3.0
    #expect(abs(height("지도 이름") - style.lineHeight) <= tolerance)
    #expect(abs(height("지도 이름\n두 번째 줄") - style.lineHeight * 2) <= tolerance)
}
