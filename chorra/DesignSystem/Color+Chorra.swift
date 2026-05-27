//
//  Color+Chorra.swift
//  chorra
//
//  Created by Tommy Nguyen on 27/5/2026.
//

import SwiftUI

extension Color {
    static let chorraPrimary = Color(hex: 0x6D4CFF)
    static let chorraPrimaryDark = Color(hex: 0x4B2FD6)
    static let chorraPrimarySoft = Color(hex: 0xEDE9FF)

    static let chorraBackground = Color(hex: 0xFCFBFF)
    static let chorraSurface = Color(hex: 0xFFFFFF)
    static let chorraSoftSurface = Color(hex: 0xF5F2FF)
    static let chorraBorder = Color(hex: 0xDED7FF)

    static let chorraTextPrimary = Color(hex: 0x1D1733)
    static let chorraTextSecondary = Color(hex: 0x6D6780)
    static let chorraTextMuted = Color(hex: 0xA8A1BA)

    static let chorraSuccess = Color(hex: 0x34A853)
    static let chorraWarning = Color(hex: 0xF5A524)
    static let chorraError = Color(hex: 0xE85D75)
    static let chorraMoneyAccent = Color(hex: 0xF2B84B)

    private init(hex: UInt32, alpha: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255

        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
