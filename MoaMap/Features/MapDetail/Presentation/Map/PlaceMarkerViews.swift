import SwiftUI

/// 장소 한 곳짜리 사진 마커. 꼬리가 지면을 가리킨다.
struct PlacePhotoMarker: View {
    let marker: PlaceMarker

    var body: some View {
        VStack(spacing: 0) {
            MarkerAvatar(marker: marker, size: 56, ringWidth: 3)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            MarkerTail()
                .fill(MoaMapPrimitiveColors.white)
                .frame(width: 12, height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(marker.name)
    }
}

/// 여러 곳이 묶인 마커. 앞의 몇 곳을 겹쳐 보여 주고 나머지는 수로 표시한다.
struct PlaceFacepileMarker: View {
    @Environment(\.moaTypography) private var typography

    let cluster: MarkerCluster
    var maxVisible = 3

    private static let avatarSize: CGFloat = 40

    var body: some View {
        let visible = Array(cluster.members.prefix(maxVisible))
        let overflow = cluster.members.count - visible.count
        HStack(spacing: -14) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, member in
                MarkerAvatar(marker: member, size: Self.avatarSize, ringWidth: 2)
                    .zIndex(Double(visible.count - index))
            }
            if overflow > 0 {
                Text("+\(overflow)")
                    .moaTextStyle(typography.caption0)
                    .foregroundStyle(MoaMapPrimitiveColors.white)
                    .lineLimit(1)
                    .frame(width: Self.avatarSize - 4, height: Self.avatarSize - 4)
                    .background(MoaMapPrimitiveColors.gray500, in: Circle())
                    .padding(2)
                    .background(MoaMapPrimitiveColors.white, in: Circle())
                    .zIndex(Double(visible.count + 1))
            }
        }
        .padding(3)
        .background(MoaMapPrimitiveColors.white, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("장소 \(cluster.members.count)곳")
    }
}

/// 흰 테두리 원 안의 사진. 사진이 없거나 받기 전·실패면 카테고리 아이콘이나 기본 그림을 깐다.
private struct MarkerAvatar: View {
    let marker: PlaceMarker
    let size: CGFloat
    let ringWidth: CGFloat

    var body: some View {
        ZStack {
            placeholder
            if let photoURL = marker.photoURL {
                AsyncImage(url: photoURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
            }
        }
        .frame(width: size - ringWidth * 2, height: size - ringWidth * 2)
        .clipShape(Circle())
        .padding(ringWidth)
        .background(MoaMapPrimitiveColors.white, in: Circle())
    }

    @ViewBuilder
    private var placeholder: some View {
        if let group = marker.categoryGroup {
            ZStack {
                MoaMapPrimitiveColors.gray50
                Image(group.iconName)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(MoaMapPrimitiveColors.textNormal)
                    .frame(width: (size - ringWidth * 2) * 0.56)
            }
        } else {
            Image("marker-placeholder").resizable().scaledToFill()
        }
    }
}

private nonisolated struct MarkerTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private extension PlaceCategoryGroup {
    var iconName: String {
        let name = switch self {
        case .mart: "mart"
        case .convenienceStore: "convenience-store"
        case .childcare: "childcare"
        case .school: "school"
        case .academy: "academy"
        case .parking: "parking"
        case .gasStation: "gas-station"
        case .subway: "subway"
        case .bank: "bank"
        case .culture: "culture"
        case .realEstate: "real-estate"
        case .publicOffice: "public-office"
        case .attraction: "attraction"
        case .lodging: "lodging"
        case .restaurant: "restaurant"
        case .cafe: "cafe"
        case .hospital: "hospital"
        case .pharmacy: "pharmacy"
        }
        return "Icons/category-\(name)"
    }
}

#Preview {
    let markers = [
        PlaceMarker(place: MapPlace(id: 1, name: "커피나무", address: "", latitude: 37.4960, longitude: 126.9570, photoURL: nil, category: "음식점 > 카페")),
        PlaceMarker(place: MapPlace(id: 2, name: "달빛정원", address: "", latitude: 37.4966, longitude: 126.9578, photoURL: nil)),
        PlaceMarker(place: MapPlace(id: 3, name: "약국", address: "", latitude: 37.4966, longitude: 126.9578, photoURL: nil, category: "의료,건강 > 약국")),
        PlaceMarker(place: MapPlace(id: 4, name: "학교", address: "", latitude: 37.4966, longitude: 126.9578, photoURL: nil, category: "교육,학문 > 학교"))
    ]
    VStack(spacing: 24) {
        PlacePhotoMarker(marker: markers[0])
        PlaceFacepileMarker(cluster: MarkerCluster(members: Array(markers.prefix(2))))
        PlaceFacepileMarker(cluster: MarkerCluster(members: markers))
    }
    .padding()
    .background(Color.gray.opacity(0.3))
}
