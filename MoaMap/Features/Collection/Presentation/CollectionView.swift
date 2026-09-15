import SwiftUI

struct CollectionView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("모음")
                .moaTextStyle(typography.title2)
                .foregroundStyle(colors.textNormal)
                .padding(.horizontal, MoaMapDimens.screenHorizontalPadding)
                .frame(height: 52)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background { colors.backgroundPrimary.ignoresSafeArea() }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    CollectionView()
}
