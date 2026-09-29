import SwiftUI

struct ProfileMenu: View {
    let onProfileClick: () -> Void
    let onSettingsClick: () -> Void

    var body: some View {
        ActionMenu(items: [
            ActionMenuItem(icon: "person", label: "프로필", action: onProfileClick),
            ActionMenuItem(icon: "settings", label: "설정", action: onSettingsClick)
        ])
    }
}

#Preview {
    ProfileMenu(onProfileClick: {}, onSettingsClick: {})
        .padding()
}
