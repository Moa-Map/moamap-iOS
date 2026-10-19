import SwiftUI

/// 세그먼트의 선택 표시. 칸 너비가 모두 같다고 보고 알약 하나를 고른 칸으로 옆으로 옮긴다.
///
/// 알약을 칸마다 지웠다 새로 그리면 두 장이 겹쳐 흐려지고, 글자 굵기까지 같이 애니메이션되면 매 프레임
/// 다시 배치돼 버벅인다. 위치만 옮겨야 매끄럽다. 세그먼트 `HStack` 의 `background` 에 둔다.
struct SegmentSelectionCapsule: View {
    let count: Int
    let index: Int
    let spacing: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            let width = (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count)
            Capsule()
                .fill(color)
                .frame(width: width)
                .offset(x: CGFloat(index) * (width + spacing))
        }
        .animation(.easeOut(duration: 0.25), value: index)
    }
}

#Preview {
    HStack(spacing: 2) {
        Text("커뮤니티").frame(maxWidth: .infinity).padding(.vertical, 14)
        Text("프라이빗").frame(maxWidth: .infinity).padding(.vertical, 14)
    }
    .background { SegmentSelectionCapsule(count: 2, index: 0, spacing: 2, color: MoaMapPrimitiveColors.yellow100) }
    .padding(4)
    .background(MoaMapPrimitiveColors.yellow50, in: Capsule())
    .padding()
}
