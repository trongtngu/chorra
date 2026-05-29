//
//  ChorraIconCatalog.swift
//  chorra
//
//  Created by Codex on 29/5/2026.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum ChorraIconCatalog {
    static let defaultIconName = "Icon_Star"
    static let pointIconName = "Icon_Diamond"

    static let allIconNames = [
        "Icon_Star",
        "Icon_Camera",
        "Icon_Cart",
        "Icon_Crown",
        "Icon_Diamond",
        "Icon_FLag",
        "Icon_Film",
        "Icon_Flower",
        "Icon_Food",
        "Icon_Fork",
        "Icon_Ghost",
        "Icon_Globe",
        "Icon_Hanger",
        "Icon_Heart",
        "Icon_Image",
        "Icon_Key",
        "Icon_Lightning",
        "Icon_Magic",
        "Icon_Plant",
        "Icon_Sun"
    ]

    static let selectableIconNames = allIconNames.filter { $0 != pointIconName }

    static func normalizedIconName(_ iconName: String) -> String {
        let trimmed = iconName.trimmingCharacters(in: .whitespacesAndNewlines)
        return allIconNames.contains(trimmed) ? trimmed : defaultIconName
    }

    static func normalizedSelectableIconName(_ iconName: String) -> String {
        let normalized = normalizedIconName(iconName)
        return selectableIconNames.contains(normalized) ? normalized : defaultIconName
    }

    static func accessibilityLabel(for iconName: String) -> String {
        normalizedIconName(iconName)
            .replacingOccurrences(of: "Icon_", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
            .capitalized
    }

    #if canImport(UIKit)
    static func image(named iconName: String) -> UIImage? {
        let normalized = normalizedIconName(iconName)

        if let image = UIImage(named: normalized) ?? UIImage(named: "\(normalized).png") {
            return image
        }

        let resourceURLs = [
            Bundle.main.url(forResource: normalized, withExtension: "png"),
            Bundle.main.url(forResource: normalized, withExtension: "png", subdirectory: "Icons")
        ].compactMap { $0 }

        for url in resourceURLs {
            if let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }

        return nil
    }
    #endif
}
