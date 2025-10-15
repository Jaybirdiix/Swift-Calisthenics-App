//
//  ExerciseListView.swift
//  New Project
//
//  Branded UI to match WorkoutGeneratorView:
//  - Soft blob background
//  - Card-based grid/list
//  - Accent gradient section headers
//

import SwiftUI

// MARK: - Local theme tokens (avoid name collisions with WorkoutGeneratorView)
private enum ListBrandTheme {
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

// MARK: - Background (soft blobs)
private struct BlobBackgroundList: View {
    var body: some View {
        ZStack {
            ListBrandTheme.pageBG.ignoresSafeArea()

            RadialGradient(
                colors: [ListBrandTheme.accent1.opacity(0.22), .clear],
                center: .topLeading, startRadius: 0, endRadius: 360
            )
            .blur(radius: 50)
            .offset(x: -80, y: -120)

            RadialGradient(
                colors: [ListBrandTheme.accent2.opacity(0.18), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 420
            )
            .blur(radius: 60)
            .offset(x: 100, y: 140)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Section Header
private struct ListSectionHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ListBrandTheme.accentGradient
                    .frame(width: 3, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Exercise Card
private struct ExerciseCard: View {
    let name: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ListBrandTheme.accent1)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(ListBrandTheme.accent1.opacity(0.10))
                    )

                Text(name)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)

            // Accent underline
            ListBrandTheme.accentGradient
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.top, 2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: ListBrandTheme.cardCorner, style: .continuous)
                .fill(ListBrandTheme.cardBG)
                .overlay(
                    RoundedRectangle(cornerRadius: ListBrandTheme.cardCorner, style: .continuous)
                        .stroke(ListBrandTheme.separator.opacity(0.35), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 3)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name)")
        .accessibilityHint("Opens exercise details")
    }
}

// MARK: - Empty State
private struct EmptyStateView: View {
    let query: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(ListBrandTheme.accent1)
            Text("No matches for “\(query)”")
                .font(.headline)
            Text("Try a different name or keyword.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: ListBrandTheme.cardCorner, style: .continuous)
                .fill(ListBrandTheme.cardBG)
                .overlay(
                    RoundedRectangle(cornerRadius: ListBrandTheme.cardCorner, style: .continuous)
                        .stroke(ListBrandTheme.separator.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Main View
struct ExerciseListView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var searchText = ""

    // Adaptive grid that looks good on phone & iPad
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var columns: [GridItem] {
        let count = (horizontalSizeClass == .compact) ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: ListBrandTheme.gridSpacing), count: count)
    }

    private var filteredExercises: [Exercise] {
        guard !searchText.isEmpty else { return viewModel.allExercises }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return viewModel.allExercises }
        return viewModel.allExercises.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.description.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BlobBackgroundList()

                ScrollView {
                    VStack(spacing: ListBrandTheme.spacing) {
                        // Header with count
                        ListSectionHeader(
                            title: "All Exercises",
                            subtitle: subtitle
                        )
                        // Grid/List of cards
                        if filteredExercises.isEmpty && !searchText.isEmpty {
                            EmptyStateView(query: searchText)
                        } else {
                            LazyVGrid(columns: columns, spacing: ListBrandTheme.gridSpacing) {
                                ForEach(filteredExercises) { exercise in
                                    NavigationLink {
                                        ExerciseDetailView(exercise: exercise)
                                    } label: {
                                        ExerciseCard(
                                            name: exercise.name,
                                            description: exercise.description
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.vertical, ListBrandTheme.spacing)
                }
                .navigationTitle("Exercises")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: filteredExercises.count)
    }

    private var subtitle: String {
        let total = viewModel.allExercises.count
        let showing = filteredExercises.count
        if searchText.isEmpty {
            return "\(total) total"
        } else {
            return "Showing \(showing) of \(total)"
        }
    }
}
