//
//  ContentView.swift
//  MoaMap
//
//  Created by jungee on 8/14/26.
//

import SwiftUI

struct ContentView: View {
    let container: AppContainer

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    if let configuration = try? APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"]) {
        ContentView(container: AppContainer(configuration: configuration) { _ in
            throw URLError(.notConnectedToInternet)
        })
    }
}
