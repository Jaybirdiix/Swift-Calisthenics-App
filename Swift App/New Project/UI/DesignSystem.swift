//
//  DesignSystem.swift
//  New Project
//
//  Created by Celeste van Dokkum on 10/15/25.
//

import SwiftUI

// MARK: - AppUI: one home for all tokens + shared components
enum AppUI {

    // MARK: Tokens
    enum Tokens {
        static let chipCorner: CGFloat = 8
        static let cardCorner: CGFloat = 10
        static let spacing: CGFloat = 16
        static let gridSpacing: CGFloat = 12

        static let pageBG = Color(uiColor: .systemGroupedBackground)
        static let cardBG = Color(uiColor: .secondarySystemGroupedBackground)
        static let separator = Color(uiColor: .separator)

        static let accent1 = Color.indigo
        static let accent2 = Color.blue
        static var accentGradient: LinearGradient {
            LinearGradient(colors: [accent1, accent2], startPoint: .leading, endPoint: .trailing)
        }
    }

    // MARK: Background (soft blobs)
    struct BlobBackground: View {
        var body: some View {
            ZStack {
                Tokens.pageBG.ignoresSafeArea()
                RadialGradient(colors: [Tokens.accent1.opacity(0.22), .clear],
                               center: .topLeading, startRadius: 0, endRadius: 360)
                    .blur(radius: 50).offset(x: -80, y: -120)
                RadialGradient(colors: [Tokens.accent2.opacity(0.18), .clear],
                               center: .bottomTrailing, startRadius: 0, endRadius: 420)
                    .blur(radius: 60).offset(x: 100, y: 140)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: Card background modifier (use on any container)
    struct CardBackground: ViewModifier {
        var corner: CGFloat = Tokens.cardCorner
        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .fill(Tokens.cardBG)
                        .overlay(
                            RoundedRectangle(cornerRadius: corner, style: .continuous)
                                .stroke(Tokens.separator.opacity(0.35), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 4, y: 3)
        }
    }

    // One-liner sugar
    static func card(corner: CGFloat = Tokens.cardCorner) -> some ViewModifier { CardBackground(corner: corner) }

    // MARK: Section header (bar + title + optional subtitle)
    struct SectionHeader: View {
        let title: String
        var subtitle: String? = nil
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Tokens.accentGradient
                        .frame(width: 3, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                    Text(title).font(.title3.weight(.semibold))
                }
                if let s = subtitle, !s.isEmpty {
                    Text(s).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: Section card (icon + title + accent underline + content)
    struct SectionCard<Content: View>: View {
        let icon: String
        let title: String
        @ViewBuilder var content: Content

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Tokens.accent1)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Tokens.accent1.opacity(0.12))
                        )
                    Text(title).font(.headline)
                    Spacer(minLength: 4)
                }

                content

                Tokens.accentGradient
                    .frame(height: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.top, 2)
            }
            .padding(14)
            .modifier(CardBackground())
        }
    }

    // MARK: Chips / Pills / Tiles
    struct TagChip: View {
        let text: String
        var body: some View {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: Tokens.chipCorner)
                    .fill(Tokens.accent1.opacity(0.10)))
                .overlay(RoundedRectangle(cornerRadius: Tokens.chipCorner)
                    .stroke(Tokens.accent1.opacity(0.55), lineWidth: 1))
        }
    }

    struct MetricTile: View {
        let label: String
        let value: String
        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(value).font(.title3.weight(.semibold))
                Text(label).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: Tokens.chipCorner)
                    .fill(Tokens.pageBG)
                    .overlay(RoundedRectangle(cornerRadius: Tokens.chipCorner)
                        .stroke(Tokens.separator.opacity(0.35), lineWidth: 1))
            )
        }
    }
}

// MARK: - Sugar extensions
extension View {
    func appCard(corner: CGFloat = AppUI.Tokens.cardCorner) -> some View {
        modifier(AppUI.CardBackground(corner: corner))
    }
}
