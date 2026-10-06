import SwiftUI

/// 탭(탐색·모음) 상단 바 왼쪽의 로고 버튼.
///
/// 시안: 높이 52 상단 바에서 로고 본체가 화면 왼쪽 24·위 9. 상단 바가 좌우 20 을 준다고 보고,
/// 그림자가 그림 밖으로 번진 만큼(왼쪽 0.75) 덜 민다. 위아래 여백을 합쳐 52 를 채운다.
struct MoaMapTopBarLogo: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image("moa-symbol")
                .resizable()
                .frame(width: 43.75, height: 35.75)
        }
        .buttonStyle(.plain)
        .padding(.leading, 3.25)
        .padding(.top, 9)
        .padding(.bottom, 7.25)
    }
}

#Preview {
    MoaMapTopBarLogo {}
        .padding()
}
