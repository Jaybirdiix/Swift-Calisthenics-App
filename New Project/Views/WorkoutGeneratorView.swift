//
//  WorkoutGeneratorView.swift
//  New Project
//
//  Branded UI: soft gradient blobs, slim corners, exclusive selection logic,
//  FIXED: Generate now programmatically navigates (can’t get stuck disabled)
//

import SwiftUI

// MARK: - Theme tokens
private enum BrandTheme {
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

struct WorkoutGeneratorView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @Namespace private var selectionNamespace
    @State private var navigateToGenerated = false   // <- programmatic nav flag

    private var canGenerate: Bool {
        !viewModel.selectedMuscles.isEmpty || !viewModel.selectedSkills.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background (soft blobs)
                BrandedBlobBackground()

                ScrollView {
                    VStack(spacing: BrandTheme.spacing) {
                        IntroCard()
                        MuscleGroupSection(viewModel: viewModel, selectionNamespace: selectionNamespace)
                        SkillSection(viewModel: viewModel, selectionNamespace: selectionNamespace)
                        Spacer(minLength: 60)
                    }
                    .padding(.vertical, BrandTheme.spacing)
                }
                .navigationTitle("Generate Workout")
                .navigationBarTitleDisplayMode(.inline)

                // Hidden NavigationLink that we trigger with a button
                NavigationLink(
                    destination: GeneratedWorkoutView(viewModel: viewModel),
                    isActive: $navigateToGenerated
                ) { EmptyView() }
                .hidden()
            }
        }
        // Bottom action bar
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Label {
                    Text(summaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    navigateToGenerated = true
                } label: {
                    Text("Generate")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.accent1)
                .disabled(!canGenerate)  // <- enables as soon as you pick a muscle OR a skill
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var summaryText: String {
        let m = viewModel.selectedMuscles.count
        let s = viewModel.selectedSkills.count
        switch (m, s) {
        case (0, 0): return "Choose muscles or one skill"
        case (_, 0): return "\(m) muscle\(m == 1 ? "" : "s") selected"
        case (0, _): return "Skill: \(viewModel.selectedSkills.first ?? "")"
        default:     return "Skill overrides muscles (cleared)"
        }
    }
}

// MARK: - Background (soft blobs only)

private struct BrandedBlobBackground: View {
    var body: some View {
        ZStack {
            BrandTheme.pageBG.ignoresSafeArea()

            RadialGradient(
                colors: [BrandTheme.accent1.opacity(0.22), .clear],
                center: .topLeading, startRadius: 0, endRadius: 360
            )
            .blur(radius: 50)
            .offset(x: -80, y: -120)

            RadialGradient(
                colors: [BrandTheme.accent2.opacity(0.18), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 420
            )
            .blur(radius: 60)
            .offset(x: 100, y: 140)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Intro

private struct IntroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(BrandTheme.accent1)
                Text("Session Composer")
                    .font(.headline)
                Spacer()
            }
            Text("Pick one skill or any set of muscles. Selecting a skill clears muscles; selecting any muscle clears the skill.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Accent underline
            BrandTheme.accentGradient
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: BrandTheme.cardCorner, style: .continuous)
                .fill(BrandTheme.cardBG)
                .overlay(
                    RoundedRectangle(cornerRadius: BrandTheme.cardCorner, style: .continuous)
                        .stroke(BrandTheme.separator.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Chips

private struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let selectionNamespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrandTheme.accent1)
                        .matchedGeometryEffect(id: "\(title)-icon", in: selectionNamespace)
                }
                Text(title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: BrandTheme.chipCorner, style: .continuous)
                    .fill(isSelected ? BrandTheme.accent1.opacity(0.12) : BrandTheme.cardBG)
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandTheme.chipCorner, style: .continuous)
                            .stroke(isSelected ? BrandTheme.accent1 : BrandTheme.separator.opacity(0.35), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1)
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Muscle Groups (multi-select; selecting a muscle clears skill)

extension WorkoutGeneratorView {
    struct MuscleGroupSection: View {
        @ObservedObject var viewModel: WorkoutViewModel
        let selectionNamespace: Namespace.ID

        private let columns = [GridItem(.adaptive(minimum: 120), spacing: BrandTheme.gridSpacing)]

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "Muscle Groups",
                    subtitle: "Selecting a muscle will clear any selected skill."
                )

                LazyVGrid(columns: columns, spacing: BrandTheme.gridSpacing) {
                    ForEach(viewModel.allMuscleGroups.sorted(), id: \.self) { muscle in
                        let isSelected = viewModel.selectedMuscles.contains(muscle)
                        SelectableChip(
                            title: muscle,
                            isSelected: isSelected,
                            isDisabled: false,
                            selectionNamespace: selectionNamespace
                        ) {
                            withHaptics {
                                if isSelected {
                                    viewModel.selectedMuscles.removeAll { $0 == muscle }
                                } else {
                                    if !viewModel.selectedMuscles.contains(muscle) {
                                        viewModel.selectedMuscles.append(muscle)
                                    }
                                    // clear any selected skill when a muscle is chosen
                                    if !viewModel.selectedSkills.isEmpty {
                                        viewModel.selectedSkills = []
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: BrandTheme.cardCorner, style: .continuous)
                        .fill(BrandTheme.cardBG)
                        .overlay(
                            RoundedRectangle(cornerRadius: BrandTheme.cardCorner, style: .continuous)
                                .stroke(BrandTheme.separator.opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Skills (exclusive; selecting a skill clears all muscles)

extension WorkoutGeneratorView {
    struct SkillSection: View {
        @ObservedObject var viewModel: WorkoutViewModel
        let selectionNamespace: Namespace.ID

        @Environment(\.horizontalSizeClass) private var hSize
        private var columns: [GridItem] {
            Array(repeating: GridItem(.flexible(), spacing: BrandTheme.gridSpacing),
                  count: (hSize == .compact) ? 2 : 3)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "Skills",
                    subtitle: "Tap to focus the session. Selecting a skill clears muscles."
                )

                LazyVGrid(columns: columns, spacing: BrandTheme.gridSpacing) {
                    ForEach(Skill.allCases, id: \.self) { skill in
                        let name = skill.rawValue
                        let isSelected = viewModel.selectedSkills.contains(name)

                        SkillCard(
                            title: name.capitalized,
                            icon: icon(for: skill),
                            isSelected: isSelected,
                            isDimmed: (!isSelected && !viewModel.selectedSkills.isEmpty)
                        ) {
                            withHaptics {
                                if isSelected {
                                    viewModel.selectedSkills = []
                                } else {
                                    viewModel.selectedSkills = [name] // exclusive
                                    viewModel.selectedMuscles = []    // clear muscles
                                }
                            }
                        }
                        .matchedGeometryEffect(id: "skill-\(name)", in: selectionNamespace)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: BrandTheme.cardCorner, style: .continuous)
                        .fill(BrandTheme.cardBG)
                        .overlay(
                            RoundedRectangle(cornerRadius: BrandTheme.cardCorner, style: .continuous)
                                .stroke(BrandTheme.separator.opacity(0.35), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 16)
        }

        private func icon(for skill: Skill) -> String {
            switch skill.rawValue.lowercased() {
            case let s where s.contains("planche"): return "figure.strengthtraining.traditional"
            case let s where s.contains("front"):   return "figure.pullup"
            case let s where s.contains("lever"):   return "figure.pullup"
            case let s where s.contains("hand"):    return "hand.point.up.left.fill"
            case let s where s.contains("flag"):    return "flag.checkered"
            default: return "wand.and.stars"
            }
        }
    }
}

private struct SkillCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let isDimmed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? BrandTheme.accent1 : .primary)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(BrandTheme.accent1.opacity(isSelected ? 0.12 : 0.06))
                    )

                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                Text(isSelected ? "Selected" : "Tap to focus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: BrandTheme.cardCorner, style: .continuous)
                    .fill(BrandTheme.cardBG)
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandTheme.cardCorner, style: .continuous)
                            .stroke(isSelected ? BrandTheme.accent1 : BrandTheme.separator.opacity(0.35), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0.03), radius: isSelected ? 6 : 4, y: 4)
        }
        .buttonStyle(.plain)
        .opacity(isDimmed ? 0.78 : 1)
        .scaleEffect(isSelected ? 1.005 : 1.0)
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: isSelected)
        .accessibilityLabel("\(title) skill card")
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select this skill and deselect muscles")
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                BrandTheme.accentGradient
                    .frame(width: 3, height: 16)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5))
                Text(title)
                    .font(.title3.weight(.semibold))
            }
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Haptics

@MainActor
private func withHaptics(_ perform: () -> Void) {
    perform()
    #if os(iOS)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #endif
}
