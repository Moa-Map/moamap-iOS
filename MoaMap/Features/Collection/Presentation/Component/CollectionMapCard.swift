import SwiftUI

struct CollectionMapCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    let map: MyMap
    let showsMembers: Bool
    /// 커뮤니티 탭 카드만 방장·관리자 뱃지를 단다.
    var showsRoleBadge = false
    /// nil 이 아니면 체크박스를 붙이고, 고르면 파란 테두리를 두른다.
    var selected: Bool?
    /// 끌어서 순서를 바꿀 수 있다는 표시.
    var showsDragHandle = false

    var body: some View {
        HStack(spacing: 12) {
            if showsDragHandle {
                Image(systemName: "equal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(colors.textAssistive)
                    .frame(width: 24, height: 24)
                    .padding(.trailing, -8)
                    .accessibilityHidden(true)
            }
            MapThumbnail(imageURL: map.imageURL, size: 64)
                .overlay(alignment: .bottomTrailing) {
                    if showsRoleBadge, let badge = map.roleBadge { roleBadge(badge) }
                }
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
            if let selected { SelectionCheckBox(checked: selected) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(colors.textWhite, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            if selected == true { RoundedRectangle(cornerRadius: 12).strokeBorder(colors.primary, lineWidth: 1) }
        }
        .shadow(color: .black.opacity(0.04), radius: 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected == true ? .isSelected : [])
    }

    /// 테두리까지 담은 23 칸 그림을 25.3 으로 그려, 사진 오른쪽 아래 모서리 밖으로 내민다.
    private func roleBadge(_ badge: MapRoleBadge) -> some View {
        let (asset, label) = switch badge {
        case .owner: ("Icons/role-badge-owner", "방장")
        case .admin: ("Icons/role-badge-admin", "관리자")
        }
        return Image(asset)
            .resizable()
            .frame(width: 25.3, height: 25.3)
            .offset(x: 6.65, y: 4.65)
            .accessibilityLabel(label)
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
