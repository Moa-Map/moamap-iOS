import SwiftUI

/// 서버 사진. 사진이 없거나 받지 못하면 모아맵 기본 이미지로 채운다. 크기와 모양은 부르는 쪽이 정한다.
struct RemoteImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            // 받는 동안 기본 이미지를 띄우면 사진이 있는 사람도 잠깐 사진이 없는 것처럼 보인다.
            case .empty where url != nil:
                Color.clear
            default:
                Image("default-image").resizable().scaledToFill()
            }
        }
    }
}

#Preview {
    RemoteImage(url: nil)
        .frame(width: 50, height: 50)
        .clipShape(Circle())
}
