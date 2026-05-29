//
//  ContentView.swift
//  chorra
//
//  Created by Tommy Nguyen on 27/5/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var appModel = AppViewModel()

    var body: some View {
        RootView()
            .environmentObject(appModel)
            .task {
                await appModel.restoreSession()
            }
            .overlay {
                if appModel.isWorking {
                    ZStack {
                        Color.chorraPrimaryDark.opacity(0.24)
                            .ignoresSafeArea()

                        ProgressView()
                            .padding(20)
                            .background(Color.chorraSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .alert("Chorra", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    appModel.errorMessage = nil
                }
            } message: {
                Text(appModel.errorMessage ?? "")
            }
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            appModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                appModel.errorMessage = nil
            }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject private var appModel: AppViewModel

    var body: some View {
        Group {
            if let configurationError = appModel.configurationError {
                ConfigurationErrorView(message: configurationError)
            } else if appModel.isLoading {
                ChorraScreen(title: "Chorra") {
                    ProgressView()
                        .tint(.chorraPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                }
            } else {
                switch appModel.session {
                case .signedOut:
                    AuthView()
                case .parent(let data):
                    ParentDashboardView(data: data)
                case .child(let data):
                    ChildDashboardView(data: data)
                }
            }
        }
    }
}

private struct ConfigurationErrorView: View {
    let message: String

    var body: some View {
        NavigationStack {
            ChorraScreen(title: "Configuration") {
                ChorraCard {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(Color.chorraWarning)

                    Text("Supabase is not configured")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.chorraTextPrimary)

                    Text(message)
                        .foregroundStyle(Color.chorraTextSecondary)

                    Text("Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY in the target build settings or launch environment.")
                        .font(.footnote)
                        .foregroundStyle(Color.chorraTextSecondary)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
