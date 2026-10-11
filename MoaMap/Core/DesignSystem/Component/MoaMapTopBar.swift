import SwiftUI

/// 가운데 제목과 왼쪽 뒤로가기가 있는 상단바. 오른쪽에 버튼 하나를 더 둘 수 있다.
struct MoaMapTopBar<Trailing: View>: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        ZStack {
            Text(title)
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: onBack) { MoaMapTopBarIcon(name: "arrow-left") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("뒤로가기")
                Spacer()
                trailing()
            }
            // 아이콘은 44 칸 가운데에 놓이므로 그만큼 덜 띄워야 시안의 20 에 맞는다.
            .padding(.horizontal, MoaMapDimens.screenHorizontalPadding - 6)
        }
        .frame(height: 58)
    }
}

extension MoaMapTopBar where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack, trailing: { EmptyView() })
    }
}

/// 상단바 버튼 아이콘. 32 아이콘을 44 터치 영역에 둔다.
struct MoaMapTopBarIcon: View {
    @Environment(\.moaColors) private var colors

    let name: String

    var body: some View {
        Image("Icons/\(name)")
            .renderingMode(.template)
            .resizable()
            .frame(width: 32, height: 32)
            .foregroundStyle(colors.textNormal)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }
}
