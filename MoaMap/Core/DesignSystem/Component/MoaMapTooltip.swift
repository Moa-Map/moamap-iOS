import SwiftUI

/// 위에 꼬리가 달린 어두운 반투명 말풍선. 꼬리는 왼쪽에서 `tailInset` 만큼 떨어진다.
struct MoaMapTooltip<Content: View>: View {
    /// 시안의 `color/modal`.
    private static var fill: Color { MoaMapPrimitiveColors.gray500.opacity(0.7) }

    var tailInset: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12)
        // 반투명이라 꼬리와 몸통을 겹치면 겹친 곳만 짙어진다. 맞붙여 둔다.
        VStack(alignment: .leading, spacing: 0) {
            TooltipTail()
                .fill(Self.fill)
                .frame(width: 16, height: 8)
                .padding(.leading, tailInset)
            HStack(alignment: .top, spacing: 10) { content() }
                .padding(16)
                .background {
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Self.fill)
                }
        }
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
