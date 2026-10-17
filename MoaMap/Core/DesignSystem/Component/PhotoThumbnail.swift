import SwiftUI

/// 지도·장소 사진 칸. 사진이 없거나 받지 못하면 기본 사진을 채운다.
struct PhotoThumbnail: View {
    let imageURL: URL?
    let size: CGFloat

    var body: some View {
        PlacePhoto(url: imageURL)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .accessibilityHidden(true)
    }
}

/// 장소 사진. 받는 동안은 로딩 표시를, 사진이 없거나 받지 못하면 기본 사진을 띄운다. 크기와 모양은 부르는 쪽이 정한다.
struct PlacePhoto: View {
    let url: URL?

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            // 받는 동안 기본 사진을 띄우면 사진이 있는 장소도 사진이 없는 것처럼 보인다.
            case .empty where url != nil:
                MoaMapPrimitiveColors.gray50.overlay { ProgressView() }
            default:
                Image("photo-placeholder").resizable().scaledToFill()
            }
        }
    }
}

#Preview {
    PhotoThumbnail(imageURL: nil, size: 64)
        .padding()
}
