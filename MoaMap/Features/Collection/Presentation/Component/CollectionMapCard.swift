import SwiftUI

struct CollectionMapCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    let map: MyMap
    let showsMembers: Bool

    var body: some View {
        HStack(spacing: 12) {
            MapThumbnail(imageURL: map.imageURL, size: 64, cornerRadius: 4, placeholderHorizontalPadding: 18)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 2) {
                    Text(map.title)
                        .moaTextStyle(typography.subtitle2)
                        .lineLimit(1)
                    if map.official {
                        Image("Icons/verify-filled")
                            .resizable().frame(width: 20, height: 20)
                            .accessibilityLabel("공식 인증")
                    }
                }
                .foregroundStyle(colors.textNormal)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    if showsMembers { meta("Icons/person", text: "\(map.memberCount)명") }
                    meta("Icons/location", text: "\(map.placeCount)곳")
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 64)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
        .accessibilityElement(children: .combine)
    }

    private func meta(_ icon: String, text: String) -> some View {
        HStack(spacing: showsMembers ? 2 : 4) {
            Image(icon).renderingMode(.template).resizable()
                .frame(width: showsMembers ? 14 : 12, height: showsMembers ? 14 : 12)
                .accessibilityHidden(true)
            Text(text).moaTextStyle(typography.caption0)
        }
        .foregroundStyle(colors.textAssistive)
    }
}
