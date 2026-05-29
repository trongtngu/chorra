//
//  ChorraDesignSystem.swift
//  chorra
//
//  Created by Codex on 29/5/2026.
//

import SwiftUI

private enum ChorraLayout {
    static let pageBodyCornerRadius: CGFloat = 24
}

struct ChorraScreen<HeaderActions: View, Content: View>: View {
    let title: String
    let headerActions: HeaderActions
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) where HeaderActions == EmptyView {
        self.title = title
        headerActions = EmptyView()
        self.content = content()
    }

    init(
        title: String,
        @ViewBuilder headerActions: () -> HeaderActions,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.headerActions = headerActions()
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.chorraBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                GeometryReader { proxy in
                    ZStack(alignment: .top) {
                        Color.chorraSurface

                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                content
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                            .padding(.bottom, 28)
                            .frame(
                                maxWidth: .infinity,
                                minHeight: proxy.size.height,
                                alignment: .topLeading
                            )
                        }
                        .scrollContentBackground(.hidden)
                        .tint(.chorraPrimary)
                    }
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(
                                topLeading: ChorraLayout.pageBodyCornerRadius,
                                topTrailing: ChorraLayout.pageBodyCornerRadius
                            ),
                            style: .continuous
                        )
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(Color.chorraSurface)

            Spacer(minLength: 12)

            headerActions
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.chorraBackground)
    }
}

struct ChorraCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.chorraSoftSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
    }
}

struct ChorraSectionHeader: View {
    let title: String
    var actionTitle: String?
    var systemImage: String?
    var isDisabled = false
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.chorraTextPrimary)

            Spacer()

            if let action, let actionTitle {
                Button(action: action) {
                    Label(actionTitle, systemImage: systemImage ?? "plus")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(ChorraHeaderActionButtonStyle())
                .disabled(isDisabled)
            }
        }
        .padding(.top, 4)
    }
}

struct ChorraEmptyState: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(Color.chorraTextMuted)

            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color.chorraTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

struct ChorraDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.chorraBorder)
            .frame(height: 1)
    }
}

struct ChorraPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(Color.chorraSurface)
            .background(configuration.isPressed ? Color.chorraPrimaryDark : Color.chorraPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ChorraSecondaryButtonStyle: ButtonStyle {
    var tint: Color = .chorraPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(tint)
            .background(tint.opacity(configuration.isPressed ? 0.18 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ChorraHeaderActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .foregroundStyle(Color.chorraPrimary)
            .background(Color.chorraSurface.opacity(configuration.isPressed ? 0.82 : 1))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.chorraBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ChorraToolbarIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.chorraSurface)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
    }
}

struct ChorraPill: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct ChorraPointAmountLabel: View {
    let amount: Int
    var iconSize: CGFloat = 14
    var iconPadding: CGFloat = 0
    var spacing: CGFloat = 4

    init(_ amount: Int, iconSize: CGFloat = 14, iconPadding: CGFloat = 0, spacing: CGFloat = 4) {
        self.amount = amount
        self.iconSize = iconSize
        self.iconPadding = iconPadding
        self.spacing = spacing
    }

    init(amount: Int, iconSize: CGFloat = 14, iconPadding: CGFloat = 0, spacing: CGFloat = 4) {
        self.init(amount, iconSize: iconSize, iconPadding: iconPadding, spacing: spacing)
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            ChorraIconView(
                iconName: ChorraIconCatalog.pointIconName,
                size: iconSize,
                padding: iconPadding
            )
            .accessibilityHidden(true)

            Text("\(amount)")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let unit = abs(amount) == 1 ? "point" : "points"
        return "\(amount) \(unit)"
    }
}

struct ChorraStatPill: View {
    let title: String
    let value: String
    let systemImage: String?
    let iconName: String?

    init(title: String, value: String, systemImage: String) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        iconName = nil
    }

    init(title: String, value: String, iconName: String) {
        self.title = title
        self.value = value
        systemImage = nil
        self.iconName = iconName
    }

    var body: some View {
        HStack(spacing: 8) {
            if let iconName {
                ChorraIconView(iconName: iconName, size: 18, padding: 0)
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.headline.weight(.bold))
                Text(title)
                    .font(.caption)
            }
        }
        .foregroundStyle(Color.chorraPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.chorraPrimarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ChorraInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .foregroundStyle(Color.chorraTextPrimary)
            .background(Color.chorraSoftSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.chorraBorder, lineWidth: 1)
            }
    }
}

extension View {
    func chorraNavigationBar() -> some View {
        self
            .toolbarBackground(Color.chorraBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func chorraTabBar() -> some View {
        self
            .tint(.chorraPrimary)
            .toolbarBackground(Color.chorraSurface, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }

    func chorraFormBackground() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.chorraSurface.ignoresSafeArea())
    }

    func chorraInput() -> some View {
        modifier(ChorraInputModifier())
    }
}
