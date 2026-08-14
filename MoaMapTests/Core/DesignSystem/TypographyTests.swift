import Testing
import UIKit
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
