//
//  PastelCardColor.swift
//  chorra
//
//  Created by Codex on 29/5/2026.
//

import Foundation
import SwiftUI

enum PastelCardColor {
    static let fallbackHex = "#FFD5F5"
    static let defaultHex = "#C7E4F4"
    static let allowedHexes = [
        "#FFD5F5",
        "#FFDFBD",
        "#FFEC7F",
        "#D7F5B3",
        "#C7E4F4",
        "#BBF2E8",
        "#E5D5FB"
    ]

    static func isValidHex(_ hex: String) -> Bool {
        allowedHexes.contains(normalizedRawHex(hex))
    }

    static func normalizedPaletteHex(_ hex: String) -> String {
        let normalized = normalizedRawHex(hex)
        return allowedHexes.contains(normalized) ? normalized : fallbackHex
    }

    static func color(from hex: String) -> Color {
        guard let rgb = parseHex(normalizedPaletteHex(hex)) ?? parseHex(fallbackHex) else {
            return Color(.sRGB, red: 1, green: 0.84, blue: 0.96, opacity: 1)
        }

        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }

    private static func normalizedRawHex(_ hex: String) -> String {
        hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func parseHex(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        let normalized = normalizedRawHex(hex)
        guard normalized.count == 7, normalized.first == "#" else {
            return nil
        }

        let digits = String(normalized.dropFirst())
        guard let value = UInt32(digits, radix: 16) else {
            return nil
        }

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        return (red, green, blue)
    }
}
