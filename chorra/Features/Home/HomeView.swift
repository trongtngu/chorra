//
//  HomeView.swift
//  chorra
//
//  Created by Tommy Nguyen on 27/5/2026.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.chorraBackground
                    .ignoresSafeArea()

                Text("Home")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)
            }
            .navigationTitle("Home")
            .toolbarBackground(Color.chorraBackground, for: .navigationBar)
        }
    }
}

#Preview {
    HomeView()
}
