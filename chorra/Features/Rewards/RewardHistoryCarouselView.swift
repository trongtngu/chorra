//
//  RewardHistoryCarouselView.swift
//  chorra
//
//  Created by Codex on 30/5/2026.
//

import Foundation
import SwiftUI

struct RewardHistoryCarouselView: View {
    let items: [RewardRedemptionItem]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(sortedItems) { item in
                    RewardHistoryCardView(item: item)
                        .containerRelativeFrame(.horizontal, count: 2, spacing: 12)
                        .aspectRatio(1, contentMode: .fit)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }

    private var sortedItems: [RewardRedemptionItem] {
        items.sorted { $0.redemption.redeemedAt > $1.redemption.redeemedAt }
    }
}

private struct RewardHistoryCardView: View {
    let item: RewardRedemptionItem

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            ChorraIconView(iconName: item.redemption.rewardIconName, size: 58)

            Text(item.redemption.rewardName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.chorraTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)

            Text("Redeemed by \(childName)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chorraTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(PastelCardColor.color(from: item.redemption.rewardCardColorHex))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.chorraBorder, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            Text(redeemedDate)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.chorraTextSecondary)
                .padding(10)
        }
        .accessibilityElement(children: .combine)
    }

    private var childName: String {
        item.child?.displayName ?? "Child"
    }

    private var redeemedDate: String {
        RewardHistoryDateFormatter.displayString(from: item.redemption.redeemedAt)
    }

}

private enum RewardHistoryDateFormatter {
    static func displayString(from rawValue: String) -> String {
        let isoWithFractionalSeconds = ISO8601DateFormatter()
        isoWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]

        let dateOnly = DateFormatter()
        dateOnly.calendar = Calendar(identifier: .gregorian)
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnly.dateFormat = "yyyy-MM-dd"

        if let date = isoWithFractionalSeconds.date(from: rawValue)
            ?? iso.date(from: rawValue)
            ?? dateOnly.date(from: rawValue) {
            let display = DateFormatter()
            display.dateFormat = "MMM d"
            return display.string(from: date)
        }

        return String(rawValue.prefix(10))
    }
}
