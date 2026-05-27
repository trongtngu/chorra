//
//  AppShellView.swift
//  chorra
//
//  Created by Tommy Nguyen on 27/5/2026.
//

import SwiftUI

struct AppShellView: View {
    @State private var selectedRoute: AppRoute = .home

    var body: some View {
        TabView(selection: $selectedRoute) {
            ForEach(AppRoute.allCases) { route in
                view(for: route)
                    .tag(route)
                    .tabItem {
                        Label(route.title, systemImage: route.systemImage)
                    }
            }
        }
        .tint(.chorraPrimary)
        .toolbarBackground(Color.chorraSurface, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .background(Color.chorraBackground)
    }

    @ViewBuilder
    private func view(for route: AppRoute) -> some View {
        switch route {
        case .home:
            HomeView()
        }
    }
}

#Preview {
    AppShellView()
}
