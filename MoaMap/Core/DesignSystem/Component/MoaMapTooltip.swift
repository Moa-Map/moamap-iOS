import SwiftUI

/// 위에 꼬리가 달린 파란 말풍선. 꼬리는 왼쪽에서 `tailInset` 만큼 떨어진다.
struct MoaMapTooltip<Content: View>: View {
    var tailInset: CGFloat = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: -4) {
            TooltipTail()
                .fill(MoaMapPrimitiveColors.blue800)
                .frame(width: 16, height: 12)
                .padding(.leading, tailInset)
            HStack(alignment: .top, spacing: 10) { content() }
                .padding(16)
                .background(MoaMapPrimitiveColors.blue800, in: RoundedRectangle(cornerRadius: 12))
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
