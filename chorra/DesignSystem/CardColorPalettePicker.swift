//
//  CardColorPalettePicker.swift
//  chorra
//
//  Created by Codex on 29/5/2026.
//

import SwiftUI

struct CardColorPalettePicker: View {
    @Binding var selectedHex: String

    var body: some View {
        HStack(spacing: 7) {
            ForEach(PastelCardColor.allowedHexes, id: \.self) { hex in
                Button {
                    selectedHex = hex
                } label: {
                    ZStack {
                        Circle()
                            .fill(PastelCardColor.color(from: hex))
                            .overlay {
                                Circle()
                                    .stroke(Color.chorraSurface, lineWidth: 2)
                            }
                            .shadow(color: Color.chorraPrimary.opacity(0.18), radius: 1, x: 0, y: 1)

                        if isSelected(hex) {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(Color.chorraTextPrimary)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .overlay {
                        Circle()
                            .stroke(
                                isSelected(hex) ? Color.chorraPrimary : Color.chorraBorder,
                                lineWidth: isSelected(hex) ? 1.5 : 0.5
                            )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Card colour \(hex)")
                .accessibilityValue(isSelected(hex) ? "Selected" : "Not selected")
            }
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            selectedHex = PastelCardColor.normalizedPaletteHex(selectedHex)
        }
    }

    private func isSelected(_ hex: String) -> Bool {
        PastelCardColor.normalizedPaletteHex(selectedHex) == hex
    }
}
