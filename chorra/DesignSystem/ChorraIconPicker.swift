//
//  ChorraIconPicker.swift
//  chorra
//
//  Created by Codex on 29/5/2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ChorraIconView: View {
    let iconName: String
    var size: CGFloat?
    var background: Color = .clear
    var padding: CGFloat = 8

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .foregroundStyle(Color.chorraPrimary)
            .padding(padding)
            .frame(width: size, height: size)
            .frame(
                maxWidth: size == nil ? .infinity : nil,
                maxHeight: size == nil ? .infinity : nil
            )
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel(ChorraIconCatalog.accessibilityLabel(for: iconName))
    }

    private var image: Image {
        #if canImport(UIKit)
        if let uiImage = ChorraIconCatalog.image(named: iconName) {
            return Image(uiImage: uiImage)
        }
        #endif

        return Image(systemName: "star.fill")
    }
}

struct IconPickerPanel: View {
    @Binding var selectedIconName: String

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 42), spacing: 10),
        count: 5
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(ChorraIconCatalog.selectableIconNames, id: \.self) { iconName in
                Button {
                    selectedIconName = iconName
                } label: {
                    ZStack(alignment: .topTrailing) {
                        ChorraIconView(
                            iconName: iconName,
                            size: nil,
                            background: .clear,
                            padding: 4
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(
                                    isSelected(iconName) ? Color.chorraPrimary : Color.chorraBorder,
                                    lineWidth: isSelected(iconName) ? 2 : 1
                                )
                        }

                        if isSelected(iconName) {
                            Circle()
                                .fill(Color.chorraPrimary)
                                .frame(width: 18, height: 18)
                                .overlay {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(Color.chorraSurface)
                                }
                                .offset(x: 5, y: -5)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ChorraIconCatalog.accessibilityLabel(for: iconName))
                .accessibilityValue(isSelected(iconName) ? "Selected" : "Not selected")
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            selectedIconName = ChorraIconCatalog.normalizedSelectableIconName(selectedIconName)
        }
    }

    private func isSelected(_ iconName: String) -> Bool {
        ChorraIconCatalog.normalizedSelectableIconName(selectedIconName) == iconName
    }
}
