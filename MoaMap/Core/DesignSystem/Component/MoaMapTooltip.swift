import SwiftUI

/// 위에 꼬리가 달린 말풍선. 꼬리는 왼쪽에서 `tailInset` 만큼 떨어진다.
struct MoaMapTooltip<Content: View>: View {
    enum Fill {
        /// 시안의 `color/modal`. 뒤를 흐린 어두운 반투명.
        case modal
        case solid(Color)
    }

    var tailInset: CGFloat = 0
    var fill: Fill = .modal
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        // 반투명이라 꼬리와 몸통을 겹치면 겹친 곳만 짙어진다. 맞붙여 둔다.
        VStack(alignment: .leading, spacing: 0) {
            background(TooltipTail())
                .frame(width: 16, height: 8)
                .padding(.leading, tailInset)
            HStack(alignment: .top, spacing: 10) { content() }
                .padding(16)
                .background { background(shape) }
        }
    }

    /// 몸통과 꼬리에 같은 블러를 깔아야 꼬리만 옅어 보이지 않는다.
    @ViewBuilder
    private func background(_ shape: some Shape) -> some View {
        switch fill {
        case .modal:
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(MoaMapPrimitiveColors.gray500.opacity(0.7))
            }
        case .solid(let color):
            shape.fill(color)
        }
    }
}

/// 「ⓘ ○○이 궁금하신가요?」 안내 줄. 누르면 바로 아래에 꼬리가 ⓘ 를 가리키는 말풍선이 뜨고, 다시 누르면 닫힌다.
///
/// 바깥을 눌러 닫는 건 화면이 `isPresented` 를 내려 처리한다. 말풍선이 뒤 내용 위에 그려지도록 이 줄에 `zIndex` 를 준다.
struct MoaMapGuideRow<Tooltip: View>: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let text: String
    @Binding var isPresented: Bool
    var accessibilityHint: String = ""
    @ViewBuilder let tooltip: () -> Tooltip

    var body: some View {
        Button { isPresented.toggle() } label: {
            HStack(spacing: 4) {
                Image("Icons/info")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text(text)
                    .moaTextStyle(typography.body2)
            }
            .foregroundStyle(colors.textAssistive)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if isPresented {
                tooltip()
                    // 꼬리가 ⓘ 가운데를 가리키도록 당기고, 안내 줄과 3 띄운다.
                    .offset(x: -12, y: 23)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .accessibilityHint(accessibilityHint)
    }
}

private nonisolated struct TooltipTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
