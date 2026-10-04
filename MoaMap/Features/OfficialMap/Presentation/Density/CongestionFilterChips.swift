import SwiftUI

/// 혼잡도 필터. 붐빔 → 여유 순서는 Android 와 같다.
struct CongestionFilterChips: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let selected: CongestionLevel?
    let onSelect: (CongestionLevel?) -> Void

    private static let levels: [CongestionLevel] = [.busy, .slightlyBusy, .normal, .relaxed]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: "전체", level: nil)
                ForEach(Self.levels, id: \.self) { chip(title: $0.label, level: $0) }
            }
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
            // 칩 그림자가 스크롤 영역에 잘리지 않게 한다.
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, -8)
    }

    private func chip(title: String, level: CongestionLevel?) -> some View {
        let isSelected = selected == level
        return Button { onSelect(level) } label: {
            HStack(spacing: 4) {
                if let level {
                    Circle()
                        .fill(level.color)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .moaTextStyle(typography.button3)
                    .foregroundStyle(isSelected ? colors.textWhite : colors.textNormal)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(isSelected ? MoaMapPrimitiveColors.gray800 : MoaMapPrimitiveColors.white, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    CongestionFilterChips(selected: .busy) { _ in }
        .padding(.vertical)
        .background(MoaMapPrimitiveColors.backgroundSecondary)
}
