import SwiftUI

/// 서버 사진. 사진이 없거나 받지 못하면 모아맵 기본 이미지로 채운다. 크기와 모양은 부르는 쪽이 정한다.
struct RemoteImage: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Image("default-image").resizable().scaledToFill()
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    RemoteImage(url: nil)
        .frame(width: 50, height: 50)
        .clipShape(Circle())
}
