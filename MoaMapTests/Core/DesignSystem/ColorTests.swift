import SwiftUI
import Testing
import UIKit
@testable import MoaMap

private func components(_ color: Color) -> (r: Int, g: Int, b: Int, a: Int) {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
    return (Int((r * 255).rounded()),
            Int((g * 255).rounded()),
            Int((b * 255).rounded()),
            Int((a * 255).rounded()))
}

@Test
func argb_리터럴을_그대로_읽는다() {
    #expect(components(MoaMapPrimitiveColors.blue500) == (0x09, 0xA8, 0xFA, 0xFF))
}

@Test
func 알파가_있는_값도_읽는다() {
    #expect(components(MoaMapPrimitiveColors.transparentBlack) == (0x00, 0x00, 0x00, 0xBF))
}

@Test
func 시맨틱_색이_팔레트를_가리킨다() {
    #expect(components(MoaMapColors.light.primary) == components(MoaMapPrimitiveColors.blue500))
    #expect(components(MoaMapColors.light.secondary) == components(MoaMapPrimitiveColors.yellow500))
}
