import SwiftUI

/// 장소·지도 선택에 함께 쓰는 체크박스. 고르면 파랗게 채우고 흰 체크를 보여준다.
struct SelectionCheckBox: View {
    @Environment(\.moaColors) private var colors

    let checked: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4)
        ZStack {
            if checked {
                shape.fill(colors.primary)
                Image("Icons/check").renderingMode(.template).resizable()
                    .foregroundStyle(colors.textWhite)
            } else {
                shape.strokeBorder(MoaMapPrimitiveColors.gray100, lineWidth: 1)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }
}
