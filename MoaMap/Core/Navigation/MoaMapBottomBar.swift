import SwiftUI

/// 콘텐츠 위에 떠 있는 알약형 하단 탭. 시안 「NavigationBar」: 고른 칸은 노랑 바탕에 진한 노랑 글자.
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
                        .foregroundStyle(selection == tab ? MoaMapPrimitiveColors.yellow800 : colors.textAssistive)
                        .frame(width: 100, height: 50)
                        .background(selection == tab ? MoaMapPrimitiveColors.yellow200 : .clear, in: Capsule())
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
