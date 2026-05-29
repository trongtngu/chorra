//
//  PastelCardColor.swift
//  chorra
//
//  Created by Codex on 29/5/2026.
//

import Foundation
import SwiftUI

enum PastelCardColor {
    static let fallbackHex = "#DFF7AF"
    private static let hexDigits = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")

    private enum HueBand: CaseIterable {
        case lime
        case mint
        case aqua
        case peach
        case pink
        case lavender
        case yellow
        case blue

        var range: ClosedRange<Double> {
            switch self {
            case .lime:
                return 75...95
            case .mint:
                return 150...175
            case .aqua:
                return 175...195
            case .peach:
                return 32...42
            case .pink:
                return 305...325
            case .lavender:
                return 255...275
            case .yellow:
                return 48...58
            case .blue:
                return 205...220
            }
        }
    }

    static func randomHex() -> String {
        let band = HueBand.allCases.randomElement() ?? .lime
        let hue = Double.random(in: band.range)
        let saturation = Double.random(in: 0.22...0.42)
        let brightness = Double.random(in: 0.94...1.0)
        let rgb = rgbComponents(hue: hue, saturation: saturation, brightness: brightness)

        return hex(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    static func isValidHex(_ hex: String) -> Bool {
        normalizedHex(hex) != nil
    }

    static func color(from hex: String) -> Color {
        guard let rgb = parseHex(hex) ?? parseHex(fallbackHex) else {
            return Color(.sRGB, red: 0.87, green: 0.97, blue: 0.69, opacity: 1)
        }

        return Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }

    private static func normalizedHex(_ hex: String) -> String? {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 7, trimmed.first == "#" else {
            return nil
        }

        let digits = trimmed.dropFirst().unicodeScalars
        guard digits.allSatisfy({ hexDigits.contains($0) }) else {
            return nil
        }

        return trimmed.uppercased()
    }

    private static func parseHex(_ hex: String) -> (red: Double, green: Double, blue: Double)? {
        guard let normalized = normalizedHex(hex) else {
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

    private static func rgbComponents(
        hue: Double,
        saturation: Double,
        brightness: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let normalizedHue = hue.truncatingRemainder(dividingBy: 360)
        let chroma = brightness * saturation
        let hueSection = normalizedHue / 60
        let x = chroma * (1 - abs(hueSection.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - chroma

        let rgbPrime: (red: Double, green: Double, blue: Double)
        switch hueSection {
        case 0..<1:
            rgbPrime = (chroma, x, 0)
        case 1..<2:
            rgbPrime = (x, chroma, 0)
        case 2..<3:
            rgbPrime = (0, chroma, x)
        case 3..<4:
            rgbPrime = (0, x, chroma)
        case 4..<5:
            rgbPrime = (x, 0, chroma)
        default:
            rgbPrime = (chroma, 0, x)
        }

        return (
            clamp(rgbPrime.red + m),
            clamp(rgbPrime.green + m),
            clamp(rgbPrime.blue + m)
        )
    }

    private static func hex(red: Double, green: Double, blue: Double) -> String {
        String(
            format: "#%02X%02X%02X",
            byte(red),
            byte(green),
            byte(blue)
        )
    }

    private static func byte(_ component: Double) -> Int {
        Int((clamp(component) * 255).rounded())
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
