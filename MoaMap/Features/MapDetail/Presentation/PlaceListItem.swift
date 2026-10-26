import SwiftUI

/// 지도 상세 장소 목록 카드. `showsReactions` 가 false 면 이름·주소만 있는 공식지도 카드다.
struct PlaceListItem: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let place: MapPlace
    var showsReactions = true
    let onClick: () -> Void
    var onLikeClick: () -> Void = {}

    /// 목록이 첫 카드 위에 이만큼은 남겨야 그림자가 잘리지 않는다.
    static let shadowRadius: CGFloat = 4

    var body: some View {
        Button(action: onClick) {
            if showsReactions {
                card
            } else {
                MapIntroPlaceItem(place: place)
            }
        }
        .buttonStyle(.plain)
    }

    private var card: some View {
        HStack(spacing: 12) {
            PhotoThumbnail(imageURL: place.photoURL, size: 68, cornerRadius: 8)
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(colors.lineAlternative, lineWidth: 1) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(place.name)
                            .moaTextStyle(typography.subtitle2)
                            .lineLimit(1)
                        Text(place.description)
                            .moaTextStyle(typography.caption0)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    likeButton
                }
                HStack(spacing: 4) {
                    Image("Icons/comment")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .foregroundStyle(MoaMapPrimitiveColors.blue500)
                        .accessibilityHidden(true)
                    Text("\(place.reviewCount)")
                        .moaTextStyle(typography.caption2)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("댓글 수 \(place.reviewCount)")
            }
            .padding(.vertical, 2)
            .foregroundStyle(colors.textNormal)
        }
        .padding(16)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: Self.shadowRadius)
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    /// 카드와 따로 받아 하트를 눌러도 상세로 넘어가지 않게 한다.
    private var likeButton: some View {
        Button(action: onLikeClick) {
            VStack(spacing: 0) {
                Image(place.liked ? "Icons/favorite-filled" : "Icons/favorite-outline")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(place.liked ? colors.statusAlert : MoaMapPrimitiveColors.gray100)
                Text("\(place.likeCount)")
                    .moaTextStyle(typography.caption2)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(-10)
        .accessibilityLabel(place.liked ? "하트 취소하기" : "하트 누르기")
        .accessibilityValue("\(place.likeCount)")
    }
}

#Preview {
    VStack(spacing: 8) {
        PlaceListItem(
            place: MapPlace(
                id: 1, name: "커피나무", address: "서울 성동구 성수이로 12", latitude: 0, longitude: 0, photoURLs: [],
                description: "따뜻한 분위기에서 스페셜티 커피를 즐길 수 있는 카페", reviewCount: 124, likeCount: 32, liked: true
            ),
            onClick: {}
        )
        PlaceListItem(
            place: MapPlace(id: 2, name: "달빛정원", address: "서울 용산구 한남대로 21", latitude: 0, longitude: 0, photoURLs: []),
            showsReactions: false,
            onClick: {}
        )
    }
    .padding(20)
    .background(MoaMapPrimitiveColors.backgroundSecondary)
}
