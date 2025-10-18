//
//  WorkoutGeneratorView.swift
//  New Project
//
//  Branded UI + Collapsible muscle groups with group-select,
//  exclusive selection logic (muscle clears skill; skill clears muscles),
//  and programmatic Generate navigation.
//

import SwiftUI

// MARK: - Muscle grouping model (hard-coded)

fileprivate enum MuscularRegion: String, CaseIterable, Hashable {
    case shoulders, chest, back, arms, core, legs, other

    var displayName: String {
        switch self {
        case .shoulders: return "Shoulders"
        case .chest:     return "Chest"
        case .back:      return "Back"
        case .arms:      return "Arms"
        case .core:      return "Core"
        case .legs:      return "Legs"
        case .other:     return "Other"
        }
    }

    static var displayOrder: [MuscularRegion] {
        [.shoulders, .chest, .back, .arms, .core, .legs, .other]
    }
}

fileprivate struct MuscleGrouping {
    // Canonical, normalized names → region
    // (See `normalize(_:)`. Add/edit lines here if you want to tweak placement.)
    private static let HARD_MAP: [String: MuscularRegion] = [
        // Shoulders
        "anterior deltoid": .shoulders,
        "lateral deltoid": .shoulders,
        "posterior deltoid": .shoulders,
        "rotator cuff": .shoulders,
        "serratus anterior": .shoulders,

        // Chest
        "pectoralis major": .chest,
        "pectoralis minor": .chest,

        // Back / upper back
        "erector spinae": .back,
        "latissimus dorsi": .back,
        "lower trapezius": .back,
        "middle trapezius": .back,
        "upper trapezius": .back,
        "trapezius": .back,   // fallback
        "rhomboids": .back,
        "teres major": .back,

        // Arms & forearms
        "biceps brachii": .arms,
        "triceps brachii": .arms,
        "triceps brachii longhead": .arms,
        "forearm flexors": .arms,
        "forearm extension": .arms,
        "forearm extensors": .arms,

        // Core
        "obliques": .core,
        "rectus abdominis": .core,
        "transversus abdominis": .core,
        "quadratus lumborum": .core,  // choose Core; switch to .back if you prefer

        // Legs / hips
        "gluteus maximus": .legs,
        "gluteus medius": .legs,
        "hamstrings": .legs,
        "quadriceps": .legs,
        "rectus femoris": .legs,
        "calves": .legs,
        "iliopsoas": .legs,
        "sartorius": .legs,
        "tensor fasciae latae": .legs
    ]

    static func groups(from allMuscleNames: [String]) -> [MuscularRegion: [String]] {
        var result: [MuscularRegion: [String]] = [:]
        for original in allMuscleNames {
            let region = regionFor(original)
            result[region, default: []].append(original)
        }
        for key in result.keys { result[key]?.sort() }
        return result
    }

    // Robust lookup: exact normalized match first, then tolerant substring fallbacks
    private static func regionFor(_ name: String) -> MuscularRegion {
        let n = normalize(name)
        if let exact = HARD_MAP[n] { return exact }

        // tolerate truncated or slightly different labels (e.g., “tensor fasciae…”, “transversus abdomi…”)
        if n.contains("tensor fasciae") || n == "tfl" { return .legs }
        if n.contains("transversus abdom") || n.contains("transverse abdom") { return .core }
        if n.contains("latissimus") { return .back }
        if n.contains("erector spinae") { return .back }
        if n.contains("trapezius") { return .back }
        if n.contains("rhomboid") { return .back }
        if n.contains("deltoid") { return .shoulders }
        if n.contains("pec") { return .chest }
        if n.contains("oblique") { return .core }
        if n.contains("rectus abdom") { return .core }
        if n.contains("gluteus") { return .legs }
        if n.contains("hamstring") { return .legs }
        if n.contains("quad") || n.contains("rectus femoris") { return .legs }
        if n.contains("calf") { return .legs }
        if n.contains("iliopsoas") || n.contains("psoas") { return .legs }
        if n.contains("sartorius") { return .legs }
        if n.contains("bicep") || n.contains("tricep") { return .arms }
        if n.contains("forearm") { return .arms }
        if n.contains("rotator cuff") { return .shoulders }
        if n.contains("serratus") { return .shoulders }
        if n.contains("teres major") { return .back }

        return .other
    }

    private static func normalize(_ s: String) -> String {
        var t = s.lowercased()
        t = t.replacingOccurrences(of: "…", with: "")      // unicode ellipsis
        t = t.replacingOccurrences(of: "...", with: "")    // three-dot ellipsis
        // strip punctuation/parentheses/commas/periods
        t = t.replacingOccurrences(of: "[()\\.,]", with: "", options: .regularExpression)
        // collapse whitespace
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


// Replace this whole struct header: add `onGenerate` and REMOVE internal NavigationStack/NavigationLink.
struct WorkoutGeneratorView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    var onGenerate: () -> Void = {}          // <-- NEW: parent-owned push

    @Namespace private var selectionNamespace
    @State private var navigateToGenerated = false  // no longer used; safe to delete

    private var canGenerate: Bool {
        !viewModel.selectedMuscles.isEmpty || !viewModel.selectedSkills.isEmpty
    }

    var body: some View {
        // ⛔️ REMOVE the internal `NavigationStack { ... }`
        ZStack {
            // Background (soft blobs) should never intercept touches
            BrandedBlobBackground().allowsHitTesting(false)

            ScrollView {
                VStack(spacing: BrandTheme.spacing) {
                    IntroCard()
                    MuscleGroupSection(viewModel: viewModel, selectionNamespace: selectionNamespace)
                    SkillSection(viewModel: viewModel, selectionNamespace: selectionNamespace)
                    Spacer(minLength: 60)
                }
                .padding(.vertical, BrandTheme.spacing)
            }
        }
        // ⛔️ REMOVE the hidden NavigationLink ... it’s no longer needed
        // .navigationTitle("Generate Workout")  // now set by the parent stack (GeneratorTab)

        // Bottom action bar stays the same, except the button calls `onGenerate()`
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
                    // was: navigateToGenerated = true
                    onGenerate()                     // <-- NEW: ask parent to push
                } label: {
                    Text("Generate")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(BrandTheme.accent1)
                .disabled(!canGenerate)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)
        }
    }

    private var summaryText: String {
        let muscleCount = viewModel.selectedMuscles.count
        if !viewModel.selectedSkills.isEmpty {
            return "Skill: \(viewModel.selectedSkills.first ?? "")"
        } else if muscleCount > 0 {
            return "\(muscleCount) muscle\(muscleCount == 1 ? "" : "s") selected"
        } else {
            return "Choose muscles or one skill"
        }
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

// MARK: - Muscle Groups (collapsible with group-select)
// Selecting a child muscle clears any selected skill.
// MARK: - Muscle Groups (collapsible with group-select)

extension WorkoutGeneratorView {
    struct MuscleGroupSection: View {
        @ObservedObject var viewModel: WorkoutViewModel
        let selectionNamespace: Namespace.ID

        // which regions are expanded
        @State private var expandedRegions: Set<MuscularRegion> = []

        // layout for child chips
        private let chipColumns = [GridItem(.adaptive(minimum: 120), spacing: BrandTheme.gridSpacing)]

        var body: some View {
            // Build groups once and pre-filter non-empty regions
            let grouped = MuscleGrouping.groups(from: viewModel.allMuscleGroups)
            let regions = MuscularRegion.displayOrder.filter { !(grouped[$0]?.isEmpty ?? true) }

            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "Muscle Groups",
                    subtitle: "Select a whole region or expand to choose specifics."
                )

                VStack(spacing: 10) {
                    ForEach(regions, id: \.self) { region in
                        if let muscles = grouped[region] {
                            let selectedInGroup = muscles.filter { viewModel.selectedMuscles.contains($0) }
                            let isAllSelected = !muscles.isEmpty && selectedInGroup.count == muscles.count
                            let isPartiallySelected = !selectedInGroup.isEmpty && !isAllSelected

                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedRegions.contains(region) },
                                    set: { newValue in
                                        if newValue { expandedRegions.insert(region) }
                                        else { expandedRegions.remove(region) }
                                    }
                                )
                            ) {
                                // CHILD CHIPS
                                LazyVGrid(columns: chipColumns, spacing: BrandTheme.gridSpacing) {
                                    ForEach(muscles, id: \.self) { muscle in
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
                                                    // Clear any selected skill when a muscle is chosen
                                                    if !viewModel.selectedSkills.isEmpty {
                                                        viewModel.selectedSkills = []
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 6)
                            } label: {
                                // HEADER ROW (tri-state select)
                                HStack(spacing: 12) {
                                    Text(region.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(selectedInGroup.count)/\(muscles.count)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)

                                    Button {
                                        withHaptics {
                                            if isAllSelected {
                                                // clear all in this region
                                                for m in muscles {
                                                    viewModel.selectedMuscles.removeAll { $0 == m }
                                                }
                                            } else {
                                                // select all in this region
                                                for m in muscles where !viewModel.selectedMuscles.contains(m) {
                                                    viewModel.selectedMuscles.append(m)
                                                }
                                                if !viewModel.selectedSkills.isEmpty {
                                                    viewModel.selectedSkills = []
                                                }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: isAllSelected
                                              ? "checkmark.square.fill"
                                              : (isPartiallySelected ? "minus.square" : "square"))
                                            .imageScale(.large)
                                            .foregroundStyle(BrandTheme.accent1)
                                    }
                                    .buttonStyle(.plain)
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
                    }
                }
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

        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        private var columns: [GridItem] {
            Array(repeating: GridItem(.flexible(), spacing: BrandTheme.gridSpacing),
                  count: (horizontalSizeClass == .compact) ? 2 : 3)
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

// MARK: - Haptics

@MainActor
private func withHaptics(_ perform: () -> Void) {
    perform()
    #if os(iOS)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #endif
}
