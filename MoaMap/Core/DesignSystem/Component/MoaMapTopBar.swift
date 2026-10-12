import SwiftUI

/// 가운데 제목과 왼쪽 뒤로가기가 있는 상단바. 오른쪽에 버튼 하나를 더 둘 수 있다.
struct MoaMapTopBar<Trailing: View>: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    var height: CGFloat = 58
    /// 시안마다 24 와 32 가 섞여 있다.
    var backIconSize: CGFloat = 32
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            Text(title)
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: onBack) { MoaMapTopBarIcon(name: "arrow-left", size: backIconSize) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("뒤로가기")
                    // 아이콘은 44 칸 가운데에 놓이므로 남는 만큼 덜 띄워야 아이콘이 화면 여백에 맞는다.
                    .padding(.leading, MoaMapDimens.screenHorizontalPadding - (44 - backIconSize) / 2)
                Spacer()
                trailing()
                    .padding(.trailing, MoaMapDimens.screenHorizontalPadding - 6)
            }
        }
        .frame(height: height)
    }
}

extension MoaMapTopBar where Trailing == EmptyView {
    init(title: String, height: CGFloat = 58, backIconSize: CGFloat = 32, onBack: @escaping () -> Void) {
        self.init(title: title, height: height, backIconSize: backIconSize, onBack: onBack, trailing: { EmptyView() })
    }
}

/// 상단바 버튼 아이콘. 44 터치 영역 가운데에 둔다.
struct MoaMapTopBarIcon: View {
    @Environment(\.moaColors) private var colors

    let name: String
    var size: CGFloat = 32

    var body: some View {
        Image("Icons/\(name)")
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
            .foregroundStyle(colors.textNormal)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}
