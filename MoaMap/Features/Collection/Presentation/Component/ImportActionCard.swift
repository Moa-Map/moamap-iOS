import SwiftUI

/// 인스타그램·외부 지도에서 장소를 가져오는 진입 카드.
struct ImportActionCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let iconName: String
    /// nil 이면 아이콘 원래 색을 쓴다.
    var iconTint: Color?
    let title: String
    let subtitle: String
    let background: Color
    let titleColor: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).moaTextStyle(typography.subtitle2).foregroundStyle(titleColor)
                    Text(subtitle).moaTextStyle(typography.body1).foregroundStyle(colors.textNormal)
                }
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image("Icons/arrow-outward").renderingMode(.template).resizable()
                    .frame(width: 24, height: 24).accessibilityHidden(true)
                    .foregroundStyle(colors.textNormal)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity).frame(height: 72)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var icon: some View {
        if let iconTint {
            Image("Icons/\(iconName)").renderingMode(.template).resizable()
                .frame(width: 24, height: 24).foregroundStyle(iconTint).accessibilityHidden(true)
        } else {
            Image("Icons/\(iconName)").resizable()
                .frame(width: 24, height: 24).accessibilityHidden(true)
        }
    }
}
