//
//  AppViewModel.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import Combine
import Foundation

@MainActor
final class AppViewModel: ObservableObject {
    @Published private(set) var session: AppSession = .signedOut
    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    @Published private(set) var configurationError: String?

    private let service: ChorraService?

    init() {
        do {
            let config = try SupabaseConfig.load()
            service = ChorraService(client: config.makeClient())
        } catch {
            service = nil
            configurationError = error.localizedDescription
            isLoading = false
        }
    }

    func restoreSession() async {
        guard let service else {
            isLoading = false
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            session = try await decorate(try await service.restoreSession())
        } catch {
            session = .signedOut
        }
    }

    func signUpParent(email: String, password: String, displayName: String, householdName: String) async {
        await run {
            let data = try await serviceOrThrow().signUpParent(
                email: email,
                password: password,
                displayName: displayName,
                householdName: householdName
            )
            session = .parent(try await decorate(data))
        }
    }

    func signInParent(email: String, password: String) async {
        await run {
            let data = try await serviceOrThrow().signInParent(email: email, password: password)
            session = .parent(try await decorate(data))
        }
    }

    func claimChildSession(householdCode: String, loginName: String, pin: String) async {
        await run {
            let data = try await serviceOrThrow().claimChildSession(
                householdCode: householdCode,
                loginName: loginName,
                pin: pin
            )
            session = .child(data)
        }
    }

    func signOut() async {
        await run {
            try await serviceOrThrow().signOut()
            session = .signedOut
        }
    }

    func addChild(displayName: String, loginName: String, pin: String) async {
        await run {
            let data = try await serviceOrThrow().addChild(
                displayName: displayName,
                loginName: loginName,
                pin: pin
            )
            session = .parent(try await decorate(data))
        }
    }

    func createAssignedTask(childId: UUID, title: String, description: String, pointValue: Int) async {
        await run {
            let data = try await serviceOrThrow().createAssignedTask(
                childId: childId,
                title: title,
                description: description,
                pointValue: pointValue
            )
            session = .parent(try await decorate(data))
        }
    }

    func submitTaskCompletion(assignment: TaskAssignment, child: Child, jpegData: Data) async {
        await run {
            let data = try await serviceOrThrow().submitTaskCompletion(
                assignment: assignment,
                child: child,
                jpegData: jpegData
            )
            session = .child(data)
        }
    }

    func approveSubmission(_ submission: TaskSubmission) async {
        await review(submission, decision: .approved, rejectionReason: nil)
    }

    func rejectSubmission(_ submission: TaskSubmission, reason: String?) async {
        await review(submission, decision: .rejected, rejectionReason: reason)
    }

    func refresh() async {
        guard service != nil else {
            return
        }

        switch session {
        case .signedOut:
            await restoreSession()
        case .parent:
            await run {
                let restored = try await serviceOrThrow().restoreSession()
                session = try await decorate(restored)
            }
        case .child:
            await run {
                let restored = try await serviceOrThrow().restoreSession()
                session = try await decorate(restored)
            }
        }
    }

    private func review(_ submission: TaskSubmission, decision: SubmissionStatus, rejectionReason: String?) async {
        await run {
            let data = try await serviceOrThrow().reviewSubmission(
                submissionId: submission.id,
                decision: decision,
                rejectionReason: rejectionReason
            )
            session = .parent(try await decorate(data))
        }
    }

    private func decorate(_ session: AppSession) async throws -> AppSession {
        switch session {
        case .signedOut:
            return .signedOut
        case .parent(let data):
            return .parent(try await decorate(data))
        case .child(let data):
            return .child(data)
        }
    }

    private func decorate(_ data: ParentDashboardData) async throws -> ParentDashboardData {
        guard let service else {
            return data
        }

        var items = data.taskItems

        for index in items.indices {
            guard let image = items[index].image else {
                continue
            }

            items[index].signedImageURL = try? await service.signedTaskPhotoURL(path: image.storagePath)
        }

        return ParentDashboardData(
            profile: data.profile,
            household: data.household,
            children: data.children,
            balances: data.balances,
            taskItems: items
        )
    }

    private func run(_ operation: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func serviceOrThrow() throws -> ChorraService {
        guard let service else {
            throw AppViewModelError.missingService
        }

        return service
    }
}

enum AppViewModelError: LocalizedError {
    case missingService

    var errorDescription: String? {
        switch self {
        case .missingService:
            return "Supabase is not configured."
        }
    }
}
