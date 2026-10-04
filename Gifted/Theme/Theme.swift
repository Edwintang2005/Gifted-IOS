//
//  Theme.swift
//  Gifted
//
//  Brand colours carried over from the original design: deep green ink, teal
//  accent and the green gradient title.
//

import SwiftUI
import UIKit

extension Color {
    /// Headline/body tint. Deep green in light mode, soft mint in dark mode.
    static let brandInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.73, green: 0.87, blue: 0.84, alpha: 1)
            : UIColor(red: 36 / 255, green: 74 / 255, blue: 71 / 255, alpha: 1)
    })

    /// Buttons, prices and highlights. Same value as the asset catalogue's AccentColor,
    /// applied explicitly as the app's tint so it doesn't depend on that being picked up.
    static let brandAccent = Color(red: 76 / 255, green: 159 / 255, blue: 148 / 255)

    static let cardBackground = Color(UIColor.secondarySystemGroupedBackground)
}

extension ShapeStyle where Self == LinearGradient {
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.196, green: 0.400, blue: 0.380),
                Color(red: 0.329, green: 0.698, blue: 0.643),
                Color(red: 0.701, green: 0.851, blue: 0.467),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// The large green-gradient heading used at the top of main screens.
struct GradientTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.largeTitle.bold())
            .foregroundStyle(.brandGradient)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// Placeholder shown wherever an item has no photo.
struct ItemImagePlaceholder: View {
    var body: some View {
        ZStack {
            Rectangle().fill(Color.brandAccent.opacity(0.12))
            Image(systemName: "gift")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.brandAccent)
        }
    }
}
