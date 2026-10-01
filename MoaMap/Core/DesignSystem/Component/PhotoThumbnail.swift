import SwiftUI

/// 지도·장소 사진 칸. 사진이 없거나 받지 못하면 기본 사진을 채운다.
struct PhotoThumbnail: View {
    let imageURL: URL?
    let size: CGFloat

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                Image("photo-placeholder").resizable().scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }
}

#Preview {
    PhotoThumbnail(imageURL: nil, size: 64)
        .padding()
}
