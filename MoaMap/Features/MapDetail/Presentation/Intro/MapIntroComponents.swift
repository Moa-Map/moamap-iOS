import SwiftUI

/// 대표 이미지 위에 아래로 짙어지는 그라데이션을 덮어 흰 글자가 읽히게 한다.
struct MapIntroHero: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    static let height: CGFloat = 295

    let title: String
    let ownerName: String?
    let imageURL: URL?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            MoaMapPrimitiveColors.gray50
            // 사진이 없거나 받지 못하면 이 아이콘이 드러난다.
            Image("Icons/image")
                .resizable()
                .frame(width: 40, height: 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            if let imageURL {
                // 꽉 채운 사진은 영역보다 커진다. 크기는 빈 뷰가 정하고 사진은 그 위에 얹어 잘라야
                // 세로로 긴 사진이 영역을 늘려 제목과 아래 섹션을 밀어내지 않는다.
                Color.clear
                    .overlay {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.clear
                        }
                    }
                    .clipped()
                    .accessibilityHidden(true)
            }
            LinearGradient(colors: [.clear, Color(argb: 0xFF66_6666)], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .moaTextStyle(typography.title1)
                    .lineLimit(2)
                if let ownerName {
                    HStack(spacing: 4) {
                        Image("Icons/person")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 20, height: 20)
                            .accessibilityLabel("제작자")
                        Text(ownerName)
                            .moaTextStyle(typography.body3)
                            .lineLimit(1)
                    }
                }
            }
            .foregroundStyle(colors.textWhite)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
    }
}

struct MapIntroSectionTitle: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let text: String

    var body: some View {
        Text(text)
            .moaTextStyle(typography.title3)
            .foregroundStyle(colors.textNormal)
    }
}

struct MapIntroDivider: View {
    var body: some View {
        MoaMapPrimitiveColors.gray50
            .frame(height: 1)
    }
}

/// 태그 수가 지도마다 달라 줄바꿈 대신 가로 스크롤로 흘려보낸다.
struct MapIntroTagRow: View {
    @Environment(\.moaTypography) private var typography

    let tags: [String]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                    Text(tag)
                        .moaTextStyle(typography.caption0)
                        .foregroundStyle(MoaMapPrimitiveColors.blue900)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(MoaMapPrimitiveColors.blue50, in: Capsule())
                        .overlay { Capsule().strokeBorder(MoaMapPrimitiveColors.blue500, lineWidth: 1) }
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// 썸네일·이름·주소만 있는 가벼운 장소 카드.
struct MapIntroPlaceItem: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let place: MapPlace

    var body: some View {
        HStack(spacing: 12) {
            PhotoThumbnail(imageURL: place.photoURL, size: 64)
            VStack(alignment: .leading, spacing: 6) {
                Text(place.name)
                    .moaTextStyle(typography.subtitle2)
                    .lineLimit(1)
                if !place.address.isEmpty {
                    Text(place.address)
                        .moaTextStyle(typography.caption0)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(colors.textNormal)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        MapIntroHero(title: "성수 카페 투어", ownerName: "모아", imageURL: nil)
        MapIntroTagRow(tags: ["카페", "데이트", "성수"])
        MapIntroPlaceItem(place: MapPlace(id: 1, name: "커피나무", address: "서울 성동구 성수이로 1", latitude: 0, longitude: 0, photoURL: nil))
            .padding(.horizontal, 20)
    }
}
