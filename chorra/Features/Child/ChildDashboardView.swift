//
//  ChildDashboardView.swift
//  chorra
//
//  Created by Codex on 27/5/2026.
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

struct ChildDashboardView: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ChildDashboardData

    @State private var selectedTab: ChildDashboardTab = .home
    @State private var rewardToUnlock: RewardItem?
    @State private var rewardWithoutEnoughPoints: RewardItem?

    var body: some View {
        TabView(selection: $selectedTab) {
            ChildHomeTab(data: data)
                .environmentObject(appModel)
                .tag(ChildDashboardTab.home)
                .tabItem {
                    Label(ChildDashboardTab.home.title, systemImage: ChildDashboardTab.home.systemImage)
                }

            ChildRewardsTab(
                data: data,
                rewardToUnlock: $rewardToUnlock,
                rewardWithoutEnoughPoints: $rewardWithoutEnoughPoints
            )
            .environmentObject(appModel)
            .tag(ChildDashboardTab.rewards)
            .tabItem {
                Label(ChildDashboardTab.rewards.title, systemImage: ChildDashboardTab.rewards.systemImage)
            }
        }
        .chorraTabBar()
        .background(Color.chorraBackground)
        .overlay {
            if let rewardToUnlock {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    ChildRewardRedemptionDialog(
                        item: rewardToUnlock,
                        isWorking: appModel.isWorking
                    ) {
                        Task {
                            await appModel.redeemReward(rewardToUnlock.reward)
                            self.rewardToUnlock = nil
                        }
                    } onCancel: {
                        self.rewardToUnlock = nil
                    }
                    .padding(24)
                }
                .transition(.opacity)
            } else if let rewardWithoutEnoughPoints {
                ZStack {
                    Color.black.opacity(0.34)
                        .ignoresSafeArea()

                    ChildRewardNotEnoughPointsDialog(
                        item: rewardWithoutEnoughPoints
                    ) {
                        self.rewardWithoutEnoughPoints = nil
                    }
                    .padding(24)
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: rewardToUnlock?.id)
        .animation(.easeInOut(duration: 0.18), value: rewardWithoutEnoughPoints?.id)
    }
}

private enum ChildDashboardTab: Hashable, CaseIterable {
    case home
    case rewards

    var title: String {
        switch self {
        case .home:
            return "Home"
        case .rewards:
            return "Rewards"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        case .rewards:
            return "gift.fill"
        }
    }
}

private struct ChildTabContainer<Content: View>: View {
    @EnvironmentObject private var appModel: AppViewModel

    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ChorraScreen(title: title) {
                HStack(spacing: 8) {
                    Button {
                        Task { await appModel.refresh() }
                    } label: {
                        ChorraToolbarIcon(systemImage: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh")
                    .disabled(appModel.isWorking)

                    Button {
                        Task { await appModel.signOut() }
                    } label: {
                        ChorraToolbarIcon(systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Sign out")
                    .disabled(appModel.isWorking)
                }
            } content: {
                content
            }
        }
    }
}

private struct ChildHomeTab: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ChildDashboardData

    var body: some View {
        ChildTabContainer(title: "Home") {
            VStack(alignment: .leading, spacing: 0) {
                pointsHeroCard

                ChorraSectionHeader(title: "Tasks")
                    .padding(.top, -4)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if incompleteTasks.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No tasks assigned", systemImage: "checklist")
                }
            } else {
                ForEach(incompleteTasks) { item in
                    NavigationLink {
                        ChildTaskDetailView(child: data.child, item: item)
                            .environmentObject(appModel)
                    } label: {
                        ChildTaskCardView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var pointsHeroCard: some View {
        VStack(spacing: 8) {
            ChorraPointAmountLabel(amount: data.balance?.points ?? 0, iconSize: 42, spacing: 10)
                .font(.system(size: 58, weight: .black, design: .rounded))
                .foregroundStyle(Color.chorraTextPrimary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var incompleteTasks: [ChildTaskItem] {
        data.tasks.filter { $0.assignment.status == .assigned || $0.assignment.status == .rejected }
    }

}

private struct ChildRewardsTab: View {
    @EnvironmentObject private var appModel: AppViewModel
    let data: ChildDashboardData
    @Binding var rewardToUnlock: RewardItem?
    @Binding var rewardWithoutEnoughPoints: RewardItem?
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ChildTabContainer(title: "Rewards") {
            if !data.redemptions.isEmpty {
                ChorraSectionHeader(title: "Reward history")

                RewardHistoryCarouselView(
                    items: data.redemptions
                )
            }

            ChorraSectionHeader(title: "Rewards")

            if data.rewards.isEmpty {
                ChorraCard {
                    ChorraEmptyState(title: "No rewards available", systemImage: "gift")
                }
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(data.rewards) { item in
                        ChildRewardCardView(
                            item: item,
                            balance: data.balance?.points ?? 0
                        ) {
                            if (data.balance?.points ?? 0) >= item.reward.pointCost {
                                rewardToUnlock = item
                            } else {
                                rewardWithoutEnoughPoints = item
                            }
                        }
                        .disabled(appModel.isWorking)
                    }
                }
            }

        }
    }
}

private struct ChildRewardCardView: View {
    let item: RewardItem
    let balance: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)

                ChorraIconView(iconName: item.reward.iconName, size: 60)

                Text(item.reward.name)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)

                ChorraPointAmountLabel(amount: item.reward.pointCost, iconSize: 12)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(canUnlock ? Color.chorraPrimary : Color.chorraTextSecondary)

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(PastelCardColor.color(from: item.reward.cardColorHex))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.chorraBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var canUnlock: Bool {
        balance >= item.reward.pointCost
    }
}

private struct ChildRewardNotEnoughPointsDialog: View {
    let item: RewardItem
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.chorraTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.chorraSoftSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            ChorraIconView(iconName: item.reward.iconName, size: 64)

            Text("Earn more points to unlock reward!")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.chorraTextPrimary)
                .multilineTextAlignment(.center)

            Button(action: onClose) {
                Text("Ok")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ChorraPrimaryButtonStyle())
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(Color.chorraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
    }
}

private struct ChildRewardRedemptionDialog: View {
    let item: RewardItem
    let isWorking: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Spacer()

                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.chorraTextSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.chorraSoftSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            ChorraIconView(iconName: item.reward.iconName, size: 64)

            VStack(spacing: 6) {
                Text("Do you want to redeem this reward?")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .multilineTextAlignment(.center)

                Text(item.reward.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chorraTextSecondary)
                    .multilineTextAlignment(.center)

                ChorraPointAmountLabel(amount: item.reward.pointCost, iconSize: 12)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.chorraPrimary)
            }

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("No")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChorraSecondaryButtonStyle())

                Button(action: onConfirm) {
                    Text("Yes")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ChorraPrimaryButtonStyle())
                .disabled(isWorking)
            }
        }
        .padding(18)
        .frame(maxWidth: 340)
        .background(Color.chorraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
    }
}

private struct ChildTaskCardView: View {
    let item: ChildTaskItem

    var body: some View {
        HStack(spacing: 12) {
            ChorraIconView(
                iconName: item.assignment.iconName,
                size: 46,
                background: .clear,
                padding: 7
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(item.assignment.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .lineLimit(2)

                ChorraPointAmountLabel(amount: item.assignment.pointValue, iconSize: 15)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.chorraTextPrimary.opacity(0.82))

                if let rejectionText {
                    Text(rejectionText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.chorraError)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.chorraTextPrimary.opacity(0.54))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PastelCardColor.color(from: item.assignment.cardColorHex))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var rejectionText: String? {
        guard let submission = item.latestSubmission, submission.status == .rejected else {
            return nil
        }

        return submission.rejectionReason ?? "Needs more work"
    }

}

private struct ChildTaskDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel

    let child: Child
    let item: ChildTaskItem

    @StateObject private var camera = TaskCameraModel()

    private let cameraAspectRatio: CGFloat = 3.0 / 4.0

    var body: some View {
        GeometryReader { proxy in
            let cameraWidth = cameraWidth(for: proxy.size)

            VStack(spacing: 0) {
                taskHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer(minLength: 18)

                cameraSurface
                    .frame(width: cameraWidth, height: cameraWidth / cameraAspectRatio)

                Spacer(minLength: 28)

                controls
                    .frame(maxWidth: 430)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(taskColor.ignoresSafeArea())
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    private var taskHeader: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 8) {
                ChorraIconView(
                    iconName: item.assignment.iconName,
                    size: 64,
                    background: .clear,
                    padding: 6
                )

                Text(item.assignment.title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 56)
            .frame(maxWidth: .infinity)

            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.chorraTextPrimary)
                    .frame(width: 44, height: 44)
                    .background(Color.chorraSurface.opacity(0.36))
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .top)
    }

    private var cameraSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black)

            if let capturedImage = camera.capturedImage {
                Image(uiImage: capturedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch camera.cameraState {
                case .idle, .configuring:
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(Color.chorraSurface)

                        Text("Starting camera")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.chorraSurface.opacity(0.78))
                    }
                case .ready:
                    TaskCameraPreview(session: camera.session)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .unavailable(let message):
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.largeTitle)

                        Text(message)
                            .font(.subheadline.weight(.semibold))
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(Color.chorraSurface.opacity(0.82))
                    .padding(24)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .clipped()
        .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }

    @ViewBuilder
    private var controls: some View {
        if camera.capturedJPEGData == nil {
            captureButton
        } else {
            reviewActions
        }
    }

    private var captureButton: some View {
        Button {
            camera.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .stroke(Color.chorraSurface, lineWidth: 7)
                    .frame(width: 96, height: 96)

                Circle()
                    .fill(Color.chorraSurface.opacity(canCapture ? 0.16 : 0.08))
                    .frame(width: 74, height: 74)
            }
            .opacity(canCapture ? 1 : 0.48)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canCapture || appModel.isWorking)
        .accessibilityLabel("Take photo")
    }

    private var reviewActions: some View {
        HStack(spacing: 12) {
            Button("Retake") {
                camera.retake()
            }
            .buttonStyle(ChorraSecondaryButtonStyle())
            .disabled(appModel.isWorking)

            Button("Submit for review") {
                guard let jpegData = camera.capturedJPEGData else {
                    return
                }

                Task {
                    await appModel.submitTaskCompletion(
                        assignment: item.assignment,
                        child: child,
                        jpegData: jpegData
                    )

                    if appModel.errorMessage == nil {
                        dismiss()
                    }
                }
            }
            .buttonStyle(ChorraPrimaryButtonStyle())
            .disabled(appModel.isWorking || camera.capturedJPEGData == nil)
        }
        .frame(maxWidth: .infinity)
    }

    private var canCapture: Bool {
        camera.cameraState.isReady && camera.capturedJPEGData == nil
    }

    private var taskColor: Color {
        PastelCardColor.color(from: item.assignment.cardColorHex)
    }

    private func cameraWidth(for size: CGSize) -> CGFloat {
        let availableWidth = max(0, size.width - 32)
        let heightConstrainedWidth = max(240, (size.height - 320) * cameraAspectRatio)
        return min(availableWidth, min(500, heightConstrainedWidth))
    }
}

private enum TaskCameraState {
    case idle
    case configuring
    case ready
    case unavailable(String)

    var isReady: Bool {
        if case .ready = self {
            return true
        }

        return false
    }
}

private final class TaskCameraModel: NSObject, ObservableObject {
    let session = AVCaptureSession()

    @Published private(set) var cameraState: TaskCameraState = .idle
    @Published private(set) var capturedImage: UIImage?
    @Published private(set) var capturedJPEGData: Data?

    private let sessionQueue = DispatchQueue(label: "com.trongpapaya.chorra.task-camera")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var photoDelegate: TaskPhotoCaptureDelegate?

    func start() {
        guard capturedJPEGData == nil else {
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart()
        case .notDetermined:
            cameraState = .configuring
            AVCaptureDevice.requestAccess(for: .video) { [weak self] isGranted in
                DispatchQueue.main.async {
                    if isGranted {
                        self?.configureAndStart()
                    } else {
                        self?.cameraState = .unavailable("Camera access is off.")
                    }
                }
            }
        case .denied, .restricted:
            cameraState = .unavailable("Camera access is off.")
        @unknown default:
            cameraState = .unavailable("Camera is unavailable.")
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func capturePhoto() {
        guard cameraState.isReady, capturedJPEGData == nil else {
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .balanced

        let delegate = TaskPhotoCaptureDelegate { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                switch result {
                case .success(let photo):
                    self.capturedImage = photo.image
                    self.capturedJPEGData = photo.jpegData
                    self.stop()
                case .failure:
                    self.cameraState = .unavailable("Could not take photo. Try again.")
                }

                self.photoDelegate = nil
            }
        }

        photoDelegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    func retake() {
        capturedImage = nil
        capturedJPEGData = nil
        start()
    }

    private func configureAndStart() {
        cameraState = .configuring

        sessionQueue.async { [weak self] in
            guard let self else {
                return
            }

            if !self.isConfigured {
                do {
                    try self.configureSession()
                } catch {
                    DispatchQueue.main.async {
                        self.cameraState = .unavailable("Camera is unavailable.")
                    }
                    return
                }
            }

            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.cameraState = .ready
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video) else {
            throw TaskCameraError.unavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)

        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw TaskCameraError.unavailable
        }

        session.addInput(input)
        session.addOutput(photoOutput)

        photoOutput.maxPhotoQualityPrioritization = .balanced
        isConfigured = true
    }
}

private final class TaskPhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    struct CapturedPhoto {
        let image: UIImage
        let jpegData: Data
    }

    private let completion: (Result<CapturedPhoto, Error>) -> Void

    init(completion: @escaping (Result<CapturedPhoto, Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            completion(.failure(error))
            return
        }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.82) else {
            completion(.failure(TaskCameraError.invalidPhoto))
            return
        }

        completion(.success(CapturedPhoto(image: image, jpegData: jpegData)))
    }
}

private enum TaskCameraError: Error {
    case unavailable
    case invalidPhoto
}

private struct TaskCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> TaskCameraPreviewView {
        let view = TaskCameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: TaskCameraPreviewView, context: Context) {
        uiView.previewLayer.session = session
    }
}

private final class TaskCameraPreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

#Preview("Child Home") {
    ChildHomeTab(data: .preview)
        .environmentObject(AppViewModel())
}

#Preview("Child Rewards") {
    ChildRewardsTab(
        data: .preview,
        rewardToUnlock: .constant(nil),
        rewardWithoutEnoughPoints: .constant(nil)
    )
        .environmentObject(AppViewModel())
}

#Preview("Child Shell") {
    ChildDashboardView(data: .preview)
        .environmentObject(AppViewModel())
}

private extension ChildDashboardData {
    static var preview: ChildDashboardData {
        let householdId = UUID()
        let child = Child(
            id: UUID(),
            householdId: householdId,
            authUserId: UUID(),
            displayName: "Ava",
            loginName: "ava",
            createdBy: UUID(),
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let task = ChorraTask(
            id: UUID(),
            householdId: householdId,
            createdBy: UUID(),
            title: "Tidy bedroom",
            pointValue: 10,
            cardColorHex: PastelCardColor.fallbackHex,
            iconName: "Icon_Hanger",
            isArchived: false,
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let assignment = TaskAssignment(
            id: UUID(),
            householdId: householdId,
            taskId: task.id,
            childId: child.id,
            assignedBy: UUID(),
            title: task.title,
            pointValue: task.pointValue,
            cardColorHex: task.cardColorHex,
            iconName: task.iconName,
            status: .assigned,
            isArchived: false,
            assignedAt: "2026-05-29"
        )
        let reward = Reward(
            id: UUID(),
            householdId: householdId,
            createdBy: UUID(),
            name: "Extra screen time",
            iconName: "Icon_Film",
            pointCost: 25,
            cardColorHex: PastelCardColor.allowedHexes[2],
            isArchived: false,
            createdAt: "2026-05-29",
            updatedAt: "2026-05-29"
        )
        let redemption = RewardRedemption(
            id: UUID(),
            householdId: householdId,
            childId: child.id,
            rewardId: reward.id,
            redeemedBy: child.id,
            rewardName: "Sticker pack",
            rewardIconName: ChorraIconCatalog.defaultIconName,
            rewardPointCost: 12,
            rewardCardColorHex: PastelCardColor.allowedHexes[3],
            redeemedAt: "2026-05-29"
        )

        return ChildDashboardData(
            child: child,
            tasks: [
                ChildTaskItem(
                    assignment: assignment,
                    latestSubmission: nil,
                    pointsEarned: 0
                )
            ],
            balance: ChildPointsBalance(
                childId: child.id,
                householdId: householdId,
                points: 18,
                lastEarnedAt: "2026-05-29"
            ),
            ledger: [
                PointsLedgerEntry(
                    id: UUID(),
                    householdId: householdId,
                    childId: child.id,
                    taskId: task.id,
                    assignmentId: assignment.id,
                    submissionId: UUID(),
                    amount: 8,
                    reason: .taskApproved,
                    createdBy: UUID(),
                    createdAt: "2026-05-29"
                )
            ],
            rewards: [RewardItem(reward: reward)],
            redemptions: [RewardRedemptionItem(redemption: redemption, child: child)]
        )
    }
}
