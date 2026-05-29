//
//  Color+Chorra.swift
//  chorra
//
//  Created by Tommy Nguyen on 27/5/2026.
//

import SwiftUI

extension Color {
    static let chorraPrimary = Color(hex: 0x30384E)
    static let chorraPrimaryDark = Color(hex: 0x252C3E)
    static let chorraPrimarySoft = Color(hex: 0xEEF1F6)

    static let chorraBackground = Color(hex: 0x30384E)
    static let chorraSurface = Color(hex: 0xFFFFFF)
    static let chorraSoftSurface = Color(hex: 0xF5F7FA)
    static let chorraBorder = Color(hex: 0xDCE2EA)

    static let chorraTextPrimary = Color(hex: 0x30384E)
    static let chorraTextSecondary = Color(hex: 0x728097)
    static let chorraTextMuted = Color(hex: 0xA8B1C0)

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
