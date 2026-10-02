import SwiftUI

/// 멤버 관리. 상단바 메뉴에서 들어와 지도 상세 위에 겹쳐 그린다.
struct MemberView: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let viewModel: MemberViewModel
    let roleDisplay: MemberRoleDisplay
    let canGrantRole: Bool
    let onBack: () -> Void

    @State private var guideVisible = false
    @State private var grantError: String?

    private var state: MemberUiState { viewModel.uiState }

    var body: some View {
        VStack(spacing: 0) {
            MapOverlayTopBar(title: "멤버 관리", height: 52, onBack: onBack)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    header
                        // 목록 간격 8 과 합쳐 머리글과 목록 사이가 20 이 된다.
                        .padding(.bottom, 12)
                        .zIndex(1)
                    content
                }
                .padding(EdgeInsets(top: 11, leading: 20, bottom: 32, trailing: 20))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(colors.backgroundSecondary)
        // 뒤에 깔린 지도로 터치가 새지 않게 하고, 말풍선 밖을 누르면 닫는다.
        .contentShape(Rectangle())
        .onTapGesture { guideVisible = false }
        .task { viewModel.loadOnce() }
        .moaSnackbar($grantError)
        .onChange(of: state.grantErrorMessage, initial: true) { _, message in
            guard let message else { return }
            grantError = message
            viewModel.consumeGrantError()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 아직 못 읽었으면 인원수를 감춘다. 0명은 참여자가 없다는 뜻이 되어 버린다.
            if !state.loading && state.errorMessage == nil {
                Text("\(state.members.count)명 참여 중")
                    .moaTextStyle(typography.subtitle1)
                    .foregroundStyle(colors.textNormal)
            }
            // 역할이 나뉘는 지도에서만 띄운다.
            if roleDisplay == .all { roleGuide }
        }
    }

    private var roleGuide: some View {
        Button { guideVisible.toggle() } label: {
            HStack(spacing: 4) {
                Image("Icons/info")
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                Text("어떤 역할이 있는지 궁금하신가요?")
                    .moaTextStyle(typography.body2)
            }
            .foregroundStyle(colors.textAssistive)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            if guideVisible {
                RoleGuideTooltip()
                    // 꼬리가 ⓘ 가운데를 가리키도록 당기고, 안내 줄 바로 아래에 띄운다.
                    .offset(x: -12, y: 23)
                    .fixedSize()
                    .transition(.opacity)
            }
        }
        .accessibilityHint("역할 안내를 엽니다")
    }

    @ViewBuilder
    private var content: some View {
        if state.loading {
            notice { ProgressView() }
        } else if let message = state.errorMessage {
            notice {
                VStack(spacing: 4) {
                    Text(message)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textAssistive)
                        .multilineTextAlignment(.center)
                    Button("다시 시도", action: viewModel.retry)
                        .moaTextStyle(typography.body2)
                        .foregroundStyle(colors.textNormal)
                        .buttonStyle(.plain)
                        .frame(minHeight: 44)
                }
            }
        } else {
            ForEach(state.members) { member in
                MemberCard(
                    member: member,
                    tag: roleDisplay.tag(for: member.role),
                    // 방장·관리자는 이미 권한이 있다.
                    canGrant: canGrantRole && (member.role == .member || member.role == .none),
                    // 오가는 중에는 다른 카드의 버튼도 잠근다.
                    grantEnabled: !state.granting,
                    onGrant: { viewModel.grantAdmin(userID: member.id) }
                )
            }
        }
    }

    private func notice(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
    }
}

private struct MemberCard: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let member: MapMember
    let tag: MapRole?
    let canGrant: Bool
    let grantEnabled: Bool
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 12) {
                AsyncImage(url: member.imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    MoaMapPrimitiveColors.blue50
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(member.name)
                            .moaTextStyle(typography.subtitle2)
                            .foregroundStyle(colors.textNormal)
                            .lineLimit(1)
                        if let tag { roleTag(tag) }
                    }
                    // 태그가 없어도 줄 높이는 태그 높이에 맞춘다.
                    .frame(height: 24)
                    if let count = member.placeCount {
                        Text("등록한 장소 수: \(count)")
                            .moaTextStyle(typography.caption0)
                            .foregroundStyle(colors.textAlternative)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)
            if canGrant {
                Button(action: onGrant) {
                    Text("권한 부여")
                        .moaTextStyle(typography.button2)
                        .foregroundStyle(colors.textWhite)
                        .padding(8)
                        .background(MoaMapPrimitiveColors.blue500, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!grantEnabled)
                .accessibilityLabel("\(member.name) 관리자 권한 부여")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(MoaMapPrimitiveColors.white, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 4)
    }

    /// 방장은 파란 태그, 관리자는 회색 태그.
    private func roleTag(_ role: MapRole) -> some View {
        let owner = role == .owner
        return Text(owner ? "방장" : "관리자")
            .moaTextStyle(typography.caption0)
            .foregroundStyle(owner ? MoaMapPrimitiveColors.blue900 : MoaMapPrimitiveColors.gray900)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(owner ? MoaMapPrimitiveColors.blue50 : MoaMapPrimitiveColors.gray50, in: Capsule())
            .overlay {
                Capsule().strokeBorder(owner ? MoaMapPrimitiveColors.blue500 : MoaMapPrimitiveColors.gray500, lineWidth: 1)
            }
    }
}

/// 역할별로 무엇을 할 수 있는지. 꼬리는 ⓘ 가운데 아래에 온다.
private struct RoleGuideTooltip: View {
    @Environment(\.moaTypography) private var typography

    var body: some View {
        MoaMapTooltip(tailInset: 14) {
            column("방장", "장소 신청 수락·거절,\n권한 위임, 강퇴")
            column("관리자", "장소 신청 수락·거절")
            column("멤버", "장소 신청,\n댓글")
        }
    }

    private func column(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).moaTextStyle(typography.body3)
            Text(description).moaTextStyle(typography.caption0)
        }
        .foregroundStyle(MoaMapPrimitiveColors.white)
    }
}

/// 지도 상세 위에 겹친 화면의 상단바. 가운데 제목과 왼쪽 뒤로가기.
struct MapOverlayTopBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography

    let title: String
    var height: CGFloat = 58
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .moaTextStyle(typography.title3)
                .foregroundStyle(colors.textNormal)
                .accessibilityAddTraits(.isHeader)
            HStack {
                Button(action: onBack) {
                    Image("Icons/arrow-left")
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(colors.textNormal)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")
                .padding(.leading, 6)
                Spacer()
            }
        }
        .frame(height: height)
    }
}

#if DEBUG
#Preview {
    MemberView(
        viewModel: MemberViewModel(mapID: 1, repository: PreviewMapMemberRepository()),
        roleDisplay: .all, canGrantRole: true, onBack: {}
    )
}
#endif
