//
//  EchoRouteMainApp.swift
//  EchoRouteMain
//
//  Created by Hamza Mujtaba on 10/3/24.
//

import SwiftUI

@main
struct EchoRouteMainApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("EchoRoute", systemImage: "book")
                    }
                DeveloperView()
                    .tabItem {
                        Label("Developer", systemImage: "gear")
                    }
            }
        }
    }
}
