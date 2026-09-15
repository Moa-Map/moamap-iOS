import SwiftUI

struct MoaMapBottomBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Binding var selection: MainTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    selection = tab
                } label: {
                    Text(tab.title)
                        .moaTextStyle(selection == tab ? typography.button0 : typography.button1)
                        .foregroundStyle(selection == tab ? colors.textNormal : colors.textAssistive)
                        .frame(width: 100, height: 50)
                        .background(selection == tab ? colors.lineAlternative : .clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
                .accessibilityIdentifier("main-tab-\(tab.rawValue)")
            }
        }
        .padding(4)
        .background(colors.textWhite, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("하단 내비게이션")
    }
}

#Preview {
    @Previewable @State var selection: MainTab = .explore
    MoaMapBottomBar(selection: $selection)
        .padding()
}
