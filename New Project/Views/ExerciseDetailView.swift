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
