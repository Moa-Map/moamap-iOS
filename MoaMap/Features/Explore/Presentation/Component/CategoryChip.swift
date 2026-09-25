import SwiftUI

struct CategoryChip: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .moaTextStyle(typography.button3)
                .foregroundStyle(isSelected ? colors.textWhite : colors.textNormal)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isSelected ? MoaMapPrimitiveColors.gray800 : colors.textWhite, in: Capsule())
                .shadow(color: .black.opacity(0.08), radius: 5)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    HStack {
        CategoryChip(title: "전체", isSelected: true) {}
        CategoryChip(title: "맛집", isSelected: false) {}
    }
    .padding()
}
