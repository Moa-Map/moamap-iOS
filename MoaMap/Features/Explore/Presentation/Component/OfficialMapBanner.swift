import SwiftUI

struct OfficialMapBanner: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                Image("Icons/verified")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("공공데이터 기반")
                        .moaTextStyle(typography.body1)
                        .foregroundStyle(MoaMapPrimitiveColors.yellow800)
                    Text("공식 지도 보러가기")
                        .moaTextStyle(typography.subtitle2)
                        .foregroundStyle(colors.textNormal)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image("Icons/arrow-outward")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .frame(height: 72)
            .background(MoaMapPrimitiveColors.yellow100, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.04), radius: 4)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OfficialMapBanner()
        .padding()
}
