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

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: ListBrandTheme.gridSpacing),
              count: (horizontalSizeClass == .compact) ? 1 : 2)
    }

    private var filteredExercises: [Exercise] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return viewModel.allExercises }
        return viewModel.allExercises.filter {
            $0.name.localizedCaseInsensitiveContains(q) ||
            $0.description.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        ZStack {
            BlobBackgroundList().allowsHitTesting(false)

            ScrollView {
                VStack(spacing: ListBrandTheme.spacing) {
                    ListSectionHeader(title: "All Exercises", subtitle: subtitle)

                    if filteredExercises.isEmpty && !searchText.isEmpty {
                        EmptyStateView(query: searchText)
                    } else {
                        LazyVGrid(columns: columns, spacing: ListBrandTheme.gridSpacing) {
                            ForEach(filteredExercises) { exercise in
                                NavigationLink {
                                    ExerciseDetailView(exercise: exercise)
                                } label: {
                                    ExerciseCard(name: exercise.name, description: exercise.description)
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
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)

        // 👇 attach searchable to the view that lives INSIDE the owning NavigationStack
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search exercises")
        .onSubmit(of: .search) { /* optional: analytics */ }

        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: filteredExercises.count)
    }

    private var subtitle: String {
        let total = viewModel.allExercises.count
        let showing = filteredExercises.count
        return searchText.isEmpty ? "\(total) total" : "Showing \(showing) of \(total)"
    }
}

