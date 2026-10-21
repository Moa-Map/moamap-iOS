import SwiftUI

/// 콘텐츠 위에 떠 있는 알약형 하단 탭. 시안 「NavigationBar」: 고른 칸은 연한 회색 바탕에 검정 글자.
///
/// 탭마다 하단 탭이 따로 붙어 있어, 탭을 바꾸면 새 탭의 하단 탭이 나타난다.
/// 같은 바 안에서 움직이는 게 아니라서, 나타날 때 직전 탭 자리에서 출발해 고른 칸으로 미끄러져 온다.
struct MoaMapBottomBar: View {
    @Environment(\.moaColors) private var colors
    @Environment(\.moaTypography) private var typography
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selection: MainTab
    /// 하단 탭을 눌러 넘어왔으면 직전 탭. 나타날 때 한 번 쓰고 비운다.
    @Binding var slideFrom: MainTab?

    /// 미끄러지는 동안 선택 표시가 있는 칸. 비어 있으면 고른 칸이다.
    @State private var sliding: MainTab?

    private var highlighted: MainTab { sliding ?? selection }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(MainTab.allCases) { tab in
                // 글자는 고른 칸을 바로 따른다. 미끄러지는 건 선택 표시뿐이다.
                let selected = selection == tab
                Button {
                    guard tab != selection else { return }
                    slideFrom = selection
                    selection = tab
                } label: {
                    Text(tab.title)
                        .moaTextStyle(selected ? typography.button0 : typography.button1)
                        .foregroundStyle(selected ? colors.textNormal : colors.textAssistive)
                        .frame(width: 100, height: 50)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("main-tab-\(tab.rawValue)")
            }
        }
        .background {
            SegmentSelectionCapsule(
                count: MainTab.allCases.count,
                index: MainTab.allCases.firstIndex(of: highlighted) ?? 0,
                spacing: 8,
                color: MoaMapPrimitiveColors.gray50
            )
        }
        .padding(4)
        .background(colors.textWhite, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("하단 내비게이션")
        .onAppear {
            guard let from = slideFrom else { return }
            slideFrom = nil
            guard from != selection, !reduceMotion else { return }
            // 직전 탭 자리로 애니메이션 없이 한 번 그린 뒤에 움직여야 미끄러져 보인다.
            var jump = Transaction()
            jump.disablesAnimations = true
            withTransaction(jump) { sliding = from }
            DispatchQueue.main.async { sliding = nil }
        }
    }
}

#Preview {
    @Previewable @State var selection: MainTab = .explore
    MoaMapBottomBar(selection: $selection, slideFrom: .constant(nil))
        .padding()
}
