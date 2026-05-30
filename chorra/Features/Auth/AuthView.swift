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
    @State private var parentSignUpMode: ParentSignUpMode = .createHousehold

    @State private var email = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var householdName = ""
    @State private var parentHouseholdCode = ""

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

                    Picker("Account setup", selection: $parentSignUpMode) {
                        Text("Create household").tag(ParentSignUpMode.createHousehold)
                        Text("Join household").tag(ParentSignUpMode.joinHousehold)
                    }
                    .pickerStyle(.segmented)
                    .tint(.chorraPrimary)

                    switch parentSignUpMode {
                    case .createHousehold:
                        TextField("Household name", text: $householdName)
                            .chorraInput()
                    case .joinHousehold:
                        TextField("Home code", text: $parentHouseholdCode)
                            .textInputAutocapitalization(.characters)
                            .chorraInput()
                    }
                }
            }

            Button(parentButtonTitle) {
                Task {
                    switch parentMode {
                    case .signIn:
                        await appModel.signInParent(email: email, password: password)
                    case .signUp:
                        switch parentSignUpMode {
                        case .createHousehold:
                            await appModel.signUpParent(
                                email: email,
                                password: password,
                                displayName: displayName,
                                householdName: householdName
                            )
                        case .joinHousehold:
                            await appModel.signUpParentToHousehold(
                                email: email,
                                password: password,
                                displayName: displayName,
                                householdCode: parentHouseholdCode
                            )
                        }
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

                Text("Use the home code and PIN from your parent.")
                    .font(.subheadline)
                    .foregroundStyle(Color.chorraTextSecondary)
            }

            VStack(spacing: 10) {
                TextField("Home code", text: $householdCode)
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
            && (parentMode == .signIn || canSubmitParentSignUp)
    }

    private var canSubmitParentSignUp: Bool {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        switch parentSignUpMode {
        case .createHousehold:
            return !householdName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .joinHousehold:
            return !parentHouseholdCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var parentButtonTitle: String {
        switch parentMode {
        case .signIn:
            return "Sign in"
        case .signUp:
            switch parentSignUpMode {
            case .createHousehold:
                return "Create parent account"
            case .joinHousehold:
                return "Join household"
            }
        }
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

private enum ParentSignUpMode {
    case createHousehold
    case joinHousehold
}

#Preview {
    AuthView()
        .environmentObject(AppViewModel())
}
