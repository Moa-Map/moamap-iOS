import SwiftUI

/// 누르면 검색 화면으로 넘어가는 진입용 검색창.
struct ExploreSearchBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 4) {
                Image("Icons/search")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("장소,지도를 검색해보세요")
                    .moaTextStyle(typography.body2)
            }
            .foregroundStyle(colors.textAssistive)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(colors.textWhite, in: Capsule())
            .shadow(color: .black.opacity(0.04), radius: 8)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ExploreSearchBar()
        .padding()
}
