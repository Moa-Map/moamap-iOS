//
//  MoaMapApp.swift
//  MoaMap
//
//  Created by jungee on 8/14/26.
//

import SwiftUI

@main
struct MoaMapApp: App {
    @State private var container: AppContainer?

    init() {
        // 설정 오류가 나면 서버 주소나 키를 노출하지 않고 앱 진입을 막는다.
        do {
            _container = State(initialValue: try AppContainer(bundle: .main))
        } catch {
            _container = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView(container: container)
            } else {
                ContentUnavailableView(
                    "앱을 시작할 수 없습니다",
                    systemImage: "exclamationmark.triangle",
                    description: Text("앱을 업데이트한 뒤 다시 실행해 주세요.")
                )
            }
        }
    }
}
