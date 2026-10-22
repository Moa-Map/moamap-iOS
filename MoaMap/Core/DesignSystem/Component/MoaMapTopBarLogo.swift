import SwiftUI

/// 탭(탐색·모음) 상단 바 높이.
nonisolated let moaMapTabTopBarHeight: CGFloat = 58

/// 탭(탐색·모음) 상단 바 왼쪽의 로고 버튼.
///
/// 그림은 그림자까지 담은 48 틀이다. 상단 바가 왼쪽 20 을 주고 세로 가운데에 둔다.
struct MoaMapTopBarLogo: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("moa-symbol")
                .resizable()
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MoaMapTopBarLogo {}
        .padding()
}
