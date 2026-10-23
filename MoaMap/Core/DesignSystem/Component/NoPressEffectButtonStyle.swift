import SwiftUI

/// 눌러도 모양이 바뀌지 않는 버튼.
struct NoPressEffectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { configuration.label }
}

extension ButtonStyle where Self == NoPressEffectButtonStyle {
    static var noPressEffect: NoPressEffectButtonStyle { NoPressEffectButtonStyle() }
}
