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
            ChorraScreen(title: "Home") {
                ChorraCard {
                    Text("Home")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.chorraTextPrimary)
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
