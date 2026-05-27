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
            Form {
                Section {
                    Picker("Mode", selection: $authMode) {
                        Text("Parent").tag(AuthMode.parent)
                        Text("Child").tag(AuthMode.child)
                    }
                    .pickerStyle(.segmented)
                }

                switch authMode {
                case .parent:
                    parentSection
                case .child:
                    childSection
                }
            }
            .navigationTitle("Chorra")
        }
    }

    private var parentSection: some View {
        Group {
            Section {
                Picker("Parent mode", selection: $parentMode) {
                    Text("Sign in").tag(ParentAuthMode.signIn)
                    Text("Create account").tag(ParentAuthMode.signUp)
                }
                .pickerStyle(.segmented)
            }

            Section("Parent account") {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)

                SecureField("Password", text: $password)
                    .textContentType(parentMode == .signIn ? .password : .newPassword)

                if parentMode == .signUp {
                    TextField("Your name", text: $displayName)
                        .textContentType(.name)

                    TextField("Household name", text: $householdName)
                }
            }

            Section {
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
                .disabled(appModel.isWorking || !canSubmitParent)
            }
        }
    }

    private var childSection: some View {
        Group {
            Section("Child login") {
                TextField("Household code", text: $householdCode)
                    .textInputAutocapitalization(.characters)

                TextField("Child login name", text: $childLoginName)
                    .textInputAutocapitalization(.never)

                SecureField("PIN", text: $childPIN)
                    .keyboardType(.numberPad)
            }

            Section {
                Button("Continue as child") {
                    Task {
                        await appModel.claimChildSession(
                            householdCode: householdCode,
                            loginName: childLoginName,
                            pin: childPIN
                        )
                    }
                }
                .disabled(appModel.isWorking || !canSubmitChild)
            }
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

