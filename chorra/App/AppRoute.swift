//
//  AppRoute.swift
//  chorra
//
//  Created by Tommy Nguyen on 27/5/2026.
//

import Foundation

enum AppRoute: Hashable, Identifiable, CaseIterable {
    case home

    var id: Self { self }

    var title: String {
        switch self {
        case .home:
            return "Home"
        }
    }

    var systemImage: String {
        switch self {
        case .home:
            return "house.fill"
        }
    }
}
