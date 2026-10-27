import SwiftUI

extension View {
    /// 꾹 눌러 띄우는 메뉴를 이 화면 위에 그린다. 화면 루트에 한 번만 건다.
    func longPressMenuHost() -> some View {
        modifier(LongPressMenuHost())
    }

    /// 꾹 누르면 화면을 흐리고, 이 줄을 `preview` 로 다시 그린 뒤 옆에 메뉴를 띄운다.
    /// `edge` 쪽에 자리가 없으면 반대쪽에 띄운다. `items` 가 비면 아무것도 하지 않는다.
    func longPressMenu<Preview: View>(
        items: [ActionMenuItem],
        edge: VerticalEdge = .bottom,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        modifier(LongPressMenuTrigger(items: items, edge: edge, preview: AnyView(preview())))
    }
}

@MainActor @Observable
private final class LongPressMenuState {
    struct Presentation {
        let frame: CGRect
        let preview: AnyView
        let items: [ActionMenuItem]
        let edge: VerticalEdge
    }

    var presented: Presentation?
}

private extension EnvironmentValues {
    @Entry var longPressMenuState: LongPressMenuState?
}

private let hostSpace = "longPressMenuHost"

private struct LongPressMenuHost: ViewModifier {
    @State private var state = LongPressMenuState()
    @State private var menuHeight: CGFloat = 0

    /// 줄과 메뉴 사이.
    private static let gap: CGFloat = 8

    func body(content: Content) -> some View {
        content
            .environment(\.longPressMenuState, state)
            .overlay {
                if let presented = state.presented {
                    GeometryReader { proxy in
                        // 안전 영역 때문에 이 영역과 기준 좌표의 원점이 다를 수 있다.
                        let origin = proxy.frame(in: .named(hostSpace)).origin
                        let frame = presented.frame.offsetBy(dx: -origin.x, dy: -origin.y)
                        ZStack(alignment: .topLeading) {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                                .onTapGesture { state.presented = nil }
                                .accessibilityHidden(true)
                            presented.preview
                                .frame(width: frame.width, height: frame.height)
                                .offset(x: frame.minX, y: frame.minY)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                            menu(presented)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { menuHeight = $0 }
                                .offset(x: menuX(frame, width: proxy.size.width), y: menuY(frame, edge: presented.edge, height: proxy.size.height))
                                // 높이를 재기 전에는 자리를 모른다.
                                .opacity(menuHeight == 0 ? 0 : 1)
                        }
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { state.presented = nil }
                }
            }
            .coordinateSpace(.named(hostSpace))
    }

    private func menu(_ presented: LongPressMenuState.Presentation) -> some View {
        let items = presented.items.map { item in
            ActionMenuItem(icon: item.icon, label: item.label, isDestructive: item.isDestructive) {
                state.presented = nil
                item.action()
            }
        }
        return ActionMenu(items: items, dark: true, style: .command)
    }

    /// 오른쪽에 붙은 줄(내 말풍선)은 메뉴도 오른쪽 끝에 맞춘다.
    private func menuX(_ frame: CGRect, width: CGFloat) -> CGFloat {
        let trailing = frame.minX - (width - frame.maxX) > 1
        let x = trailing ? frame.maxX - ActionMenu.width : frame.minX
        return max(0, min(x, width - ActionMenu.width))
    }

    private func menuY(_ frame: CGRect, edge: VerticalEdge, height: CGFloat) -> CGFloat {
        let above = frame.minY - Self.gap - menuHeight
        let below = frame.maxY + Self.gap
        let fitsAbove = above >= 0
        let fitsBelow = below + menuHeight <= height
        switch edge {
        case .top: return fitsAbove || !fitsBelow ? max(0, above) : below
        case .bottom: return fitsBelow || !fitsAbove ? min(below, height - menuHeight) : above
        }
    }
}

private struct LongPressMenuTrigger: ViewModifier {
    @Environment(\.longPressMenuState) private var state

    let items: [ActionMenuItem]
    let edge: VerticalEdge
    let preview: AnyView

    @State private var frame: CGRect = .zero
    @State private var pressed = 0
    /// 손가락을 대고 있는 동안. 꾹 누르는 중이라는 걸 보이게 살짝 어둡게 한다.
    @State private var pressing = false

    func body(content: Content) -> some View {
        if items.isEmpty || state == nil {
            content
        } else {
            content
                // 배경이 비치는 줄은 밝기를 낮춰도 글씨·빈칸이 그대로라, 배경을 칠한 `preview` 를 대신 어둡게 그린다.
                .opacity(pressing ? 0 : 1)
                .overlay {
                    if pressing { preview.brightness(-0.08).allowsHitTesting(false) }
                }
                .animation(.easeOut(duration: 0.15), value: pressing)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(hostSpace)) } action: { frame = $0 }
                .onLongPressGesture {
                    pressed += 1
                    state?.presented = .init(frame: frame, preview: preview, items: items, edge: edge)
                } onPressingChanged: { pressing = $0 }
                .sensoryFeedback(.impact, trigger: pressed)
                // 꾹 누르기는 VoiceOver 에서 찾기 어렵다. 같은 일을 동작으로도 둔다.
                .accessibilityActions {
                    ForEach(items) { item in
                        Button(item.label, action: item.action)
                    }
                }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(0..<8) { index in
                let row = Text("댓글 \(index)")
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                row.longPressMenu(items: [
                    ActionMenuItem(icon: "block", label: "차단하기") {},
                    ActionMenuItem(icon: "report", label: "신고하기", isDestructive: true) {}
                ]) { row }
            }
        }
        .padding(20)
    }
    .background(Color.gray.opacity(0.2))
    .longPressMenuHost()
}
