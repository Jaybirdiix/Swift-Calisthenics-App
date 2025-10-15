//
//  ExerciseDetailView.swift
//  New Project
//
//  Branded detail page to match WorkoutGeneratorView / ExerciseListView:
//  - Soft blob background
//  - Carded sections with subtle strokes
//  - Accent gradient headers + chips for muscles
//

import SwiftUI

// MARK: - Local theme tokens (avoid name collisions)
private enum DetailBrandTheme {
    static let cardCorner: CGFloat = 10
    static let chipCorner: CGFloat = 8
    static let spacing: CGFloat = 16
    static let gridSpacing: CGFloat = 10

    static let pageBG = Color(uiColor: .systemGroupedBackground)
    static let cardBG = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)

    static let accent1 = Color.indigo
    static let accent2 = Color.blue
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent1, accent2], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Background (soft blobs)
private struct BlobBackgroundDetail: View {
    var body: some View {
        ZStack {
            DetailBrandTheme.pageBG.ignoresSafeArea()

            RadialGradient(
                colors: [DetailBrandTheme.accent1.opacity(0.22), .clear],
                center: .topLeading, startRadius: 0, endRadius: 360
            )
            .blur(radius: 50)
            .offset(x: -80, y: -120)

            RadialGradient(
                colors: [DetailBrandTheme.accent2.opacity(0.18), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 420
            )
            .blur(radius: 60)
            .offset(x: 100, y: 140)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Generic card shell
private struct SectionCard<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(DetailBrandTheme.accent1)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(DetailBrandTheme.accent1.opacity(0.10))
                    )
                Text(title)
                    .font(.headline)
                Spacer(minLength: 4)
            }

            content

            // Accent underline
            DetailBrandTheme.accentGradient
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: DetailBrandTheme.cardCorner, style: .continuous)
                .fill(DetailBrandTheme.cardBG)
                .overlay(
                    RoundedRectangle(cornerRadius: DetailBrandTheme.cardCorner, style: .continuous)
                        .stroke(DetailBrandTheme.separator.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 3)
    }
}

// MARK: - Non-interactive chip
private struct TagChip: View {
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.system(size: 6, weight: .semibold))
                .opacity(0.7)
            Text(text)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: DetailBrandTheme.chipCorner, style: .continuous)
                .fill(DetailBrandTheme.accent1.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: DetailBrandTheme.chipCorner, style: .continuous)
                        .stroke(DetailBrandTheme.accent1.opacity(0.55), lineWidth: 1)
                )
        )
    }
}

// MARK: - Chip grid
private struct ChipGrid: View {
    let items: [String]
    private let columns = [GridItem(.adaptive(minimum: 120), spacing: DetailBrandTheme.gridSpacing)]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: DetailBrandTheme.gridSpacing) {
            ForEach(items, id: \.self) { item in
                TagChip(text: item)
            }
        }
    }
}

// MARK: - Main view
struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ZStack {
            BlobBackgroundDetail()

            ScrollView {
                VStack(spacing: DetailBrandTheme.spacing) {
                    // HERO / SUMMARY
                    SectionCard(icon: "figure.strengthtraining.traditional", title: exercise.name) {
                        // Small info line with muscle counts
                        let p = exercise.muscles.primary.count
                        let s = exercise.muscles.secondary.count
                        let t = exercise.muscles.tertiary.count
                        Text(summaryLine(primary: p, secondary: s, tertiary: t))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // DESCRIPTION
                    if !exercise.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        SectionCard(icon: "text.alignleft", title: "Description") {
                            Text(exercise.description)
                                .font(.body)
                                .multilineTextAlignment(.leading)
                                .lineSpacing(2)
                        }
                    }

                    // MUSCLE GROUPS
                    if !exercise.muscles.primary.isEmpty {
                        SectionCard(icon: "bolt.fill", title: "Primary Muscles") {
                            ChipGrid(items: exercise.muscles.primary)
                        }
                    }
                    if !exercise.muscles.secondary.isEmpty {
                        SectionCard(icon: "bolt", title: "Secondary Muscles") {
                            ChipGrid(items: exercise.muscles.secondary)
                        }
                    }
                    if !exercise.muscles.tertiary.isEmpty {
                        SectionCard(icon: "bolt.slash", title: "Tertiary Muscles") {
                            ChipGrid(items: exercise.muscles.tertiary)
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, DetailBrandTheme.spacing)
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryLine(primary: Int, secondary: Int, tertiary: Int) -> String {
        var parts: [String] = []
        if primary > 0 { parts.append("Primary: \(primary)") }
        if secondary > 0 { parts.append("Secondary: \(secondary)") }
        if tertiary > 0 { parts.append("Tertiary: \(tertiary)") }
        return parts.isEmpty ? "No muscle data" : parts.joined(separator: " • ")
    }
}
