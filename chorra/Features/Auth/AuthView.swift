//
//  AuthView.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State private var authMode: AuthMode = .parent
    @State private var parentMode: ParentAuthMode = .signIn

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var householdName = ""

    @State private var householdCode = ""
    @State private var childLoginName = ""
    @State private var childPIN = ""

    var body: some View {
        NavigationStack {
            ChorraScreen(title: "Chorra") {
                ChorraCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tasks, points, and rewards for the household.")
                            .font(.subheadline)
                            .foregroundStyle(Color.chorraTextSecondary)
                    }

                    Picker("Mode", selection: $authMode) {
                        Text("Parent").tag(AuthMode.parent)
                        Text("Child").tag(AuthMode.child)
                    }
                    .pickerStyle(.segmented)
                    .tint(.chorraPrimary)
                }

                switch authMode {
                case .parent:
                    parentSection
                case .child:
                    childSection
                }
            }
        }
    }

    private var parentSection: some View {
        ChorraCard {
            Picker("Parent mode", selection: $parentMode) {
                Text("Sign in").tag(ParentAuthMode.signIn)
                Text("Create account").tag(ParentAuthMode.signUp)
            }
            .pickerStyle(.segmented)
            .tint(.chorraPrimary)

            VStack(spacing: 10) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .chorraInput()

                SecureField("Password", text: $password)
                    .textContentType(parentMode == .signIn ? .password : .newPassword)
                    .chorraInput()

                if parentMode == .signUp {
                    TextField("Your name", text: $displayName)
                        .textContentType(.name)
                        .chorraInput()

                    TextField("Household name", text: $householdName)
                        .chorraInput()
                }
            }

            Button(parentMode == .signIn ? "Sign in" : "Create parent account") {
                Task {
                    switch parentMode {
                    case .signIn:
                        await appModel.signInParent(email: email, password: password)
                    case .signUp:
                        await appModel.signUpParent(
                            email: email,
                            password: password,
                            displayName: displayName,
                            householdName: householdName
                        )
                    }
                }
            }
            .buttonStyle(ChorraPrimaryButtonStyle())
            .disabled(appModel.isWorking || !canSubmitParent)
        }
    }

    private var childSection: some View {
        ChorraCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("Child login")
                    .font(.headline)
                    .foregroundStyle(Color.chorraTextPrimary)

                Text("Use the household code and PIN from your parent.")
                    .font(.subheadline)
                    .foregroundStyle(Color.chorraTextSecondary)
            }

            VStack(spacing: 10) {
                TextField("Household code", text: $householdCode)
                    .textInputAutocapitalization(.characters)
                    .chorraInput()

                TextField("Child login name", text: $childLoginName)
                    .textInputAutocapitalization(.never)
                    .chorraInput()

                SecureField("PIN", text: $childPIN)
                    .keyboardType(.numberPad)
                    .chorraInput()
            }

            Button("Continue as child") {
                Task {
                    await appModel.claimChildSession(
                        householdCode: householdCode,
                        loginName: childLoginName,
                        pin: childPIN
                    )
                }
            }
            .buttonStyle(ChorraPrimaryButtonStyle())
            .disabled(appModel.isWorking || !canSubmitChild)
        }
    }

    private var canSubmitParent: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && password.count >= 6
            && (parentMode == .signIn || (
                !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    && !householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ))
    }

    private var canSubmitChild: Bool {
        !householdCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !childLoginName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && childPIN.count >= 4
    }
}

private enum AuthMode {
    case parent
    case child
}

private enum ParentAuthMode {
    case signIn
    case signUp
}

#Preview {
    AuthView()
        .environmentObject(AppViewModel())
}
