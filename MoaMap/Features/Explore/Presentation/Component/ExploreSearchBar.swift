import SwiftUI

/// 검색창 모양만 둔다. 서버에 지도 검색 API 가 없어 누르지 않는다.
struct ExploreSearchBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    var body: some View {
        HStack(spacing: 4) {
            Image("Icons/search")
                .renderingMode(.template)
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(colors.textNormal)
                .accessibilityHidden(true)
            Text("장소,지도를 검색해보세요")
                .moaTextStyle(typography.body2)
                .foregroundStyle(colors.textAssistive)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(colors.textWhite, in: Capsule())
        .shadow(color: .black.opacity(0.04), radius: 8)
    }
}

#Preview {
    ExploreSearchBar()
        .padding()
}
