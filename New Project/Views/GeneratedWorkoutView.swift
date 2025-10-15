import SwiftUI

// MARK: - Local theme
fileprivate enum GenTheme {
    static let corner: CGFloat = 10
    static let chipCorner: CGFloat = 8
    static let spacing: CGFloat = 16

    static let pageBG = Color(uiColor: .systemGroupedBackground)
    static let cardBG = Color(uiColor: .secondarySystemGroupedBackground)
    static let separator = Color(uiColor: .separator)

    static let accent1 = Color.indigo
    static let accent2 = Color.blue
    static var accentGradient: LinearGradient {
        LinearGradient(colors: [accent1, accent2], startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Background blobs
fileprivate struct BlobBackground: View {
    var body: some View {
        ZStack {
            GenTheme.pageBG.ignoresSafeArea()
            RadialGradient(colors: [GenTheme.accent1.opacity(0.22), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 360)
                .blur(radius: 50)
                .offset(x: -80, y: -120)
            RadialGradient(colors: [GenTheme.accent2.opacity(0.18), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 420)
                .blur(radius: 60)
                .offset(x: 100, y: 140)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - View
struct GeneratedWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var isGenerating = false

    private let tips = ["Warm up 5–10 min", "Rest 60–90 s between sets", "Cool down & stretch"]

    // — Your original focus logic (unchanged) —
    private var trainingFocusData: (title: String, rows: [(muscle: String, score: Int)])? {
        guard viewModel.selectedSkills.count == 1,
              let chosen = viewModel.selectedSkills.first,
              let reference = viewModel.allExercises.first(where: { $0.name == chosen })
        else { return nil }

        let keyMuscles = Set(reference.muscles.primary
                             + reference.muscles.secondary
                             + reference.muscles.tertiary)

        var tally: [String: Int] = [:]
        for ex in viewModel.generatedWorkout {
            for m in ex.muscles.primary   where keyMuscles.contains(m) { tally[m, default: 0] += 3 }
            for m in ex.muscles.secondary where keyMuscles.contains(m) { tally[m, default: 0] += 2 }
            for m in ex.muscles.tertiary  where keyMuscles.contains(m) { tally[m, default: 0] += 1 }
        }

        let rows = tally
            .sorted { ($0.value, $0.key) > ($1.value, $1.key) }
            .map { (muscle: $0.key, score: $0.value) }

        return (title: chosen, rows: rows)
    }

    private var withRepsCount: Int {
        viewModel.generatedWorkout.filter { ($0.reps?.isEmpty == false) }.count
    }
    private var targetedMuscleCount: Int {
        let all = viewModel.generatedWorkout.flatMap { $0.muscles.primary + $0.muscles.secondary + $0.muscles.tertiary }
        return Set(all).count
    }

    var body: some View {
        ZStack {
            BlobBackground()

            ScrollView {
                VStack(spacing: GenTheme.spacing) {

                    // Header + Generate button (calls your method exactly)
                    HeaderCard(
                        exerciseCount: viewModel.generatedWorkout.count,
                        withRepsCount: withRepsCount,
                        targetedMuscleCount: targetedMuscleCount,
                        skillTitle: viewModel.selectedSkills.first
                    )

                    Button {
                        Task {
                            isGenerating = true
                            await viewModel.generateWorkoutWithAI()   // ✅ same call as your working view
                            isGenerating = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isGenerating { ProgressView().tint(.white) }
                            Text(isGenerating ? "Generating…" : "Generate Workout")
                                .fontWeight(.semibold)
                                .padding(.horizontal, 4)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(GenTheme.accent1)
                    .padding(.horizontal, 16)

                    if viewModel.generatedWorkout.isEmpty {
                        EmptyStateCard {
                            Task {
                                isGenerating = true
                                await viewModel.generateWorkoutWithAI()
                                isGenerating = false
                            }
                        }
                    } else {
                        // “Your Workout” in card style (direct ForEach on your published array)
                        WorkoutListCard(viewModel: viewModel)

                        // Training Focus (only if exactly one skill)
                        if let focus = trainingFocusData, !focus.rows.isEmpty {
                            TrainingFocusCard(title: focus.title, rows: focus.rows)
                        }

                        // Notes
                        TipsCard(tips: tips)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.vertical, GenTheme.spacing)
            }
        }
        .navigationTitle("Generated Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Cards

fileprivate struct HeaderCard: View {
    let exerciseCount: Int
    let withRepsCount: Int
    let targetedMuscleCount: Int
    let skillTitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(GenTheme.accent1)
                Text("Your Session").font(.headline)
                Spacer()
            }
            if let skill = skillTitle, !skill.isEmpty {
                HStack(spacing: 8) {
                    Text("Focus:").font(.subheadline.weight(.semibold))
                    Text(skill.capitalized)
                        .font(.subheadline)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: GenTheme.chipCorner).fill(GenTheme.accent1.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: GenTheme.chipCorner).stroke(GenTheme.accent1, lineWidth: 1))
                }
            }
            HStack(spacing: 12) {
                MetricTile(label: "Exercises", value: "\(exerciseCount)")
                MetricTile(label: "With Reps", value: "\(withRepsCount)")
                MetricTile(label: "Muscles", value: "\(targetedMuscleCount)")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: GenTheme.corner)
                .fill(GenTheme.cardBG)
                .overlay(RoundedRectangle(cornerRadius: GenTheme.corner).stroke(GenTheme.separator.opacity(0.35), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}

fileprivate struct WorkoutListCard: View {
    @ObservedObject var viewModel: WorkoutViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GenTheme.accentGradient.frame(width: 3, height: 16).clipShape(RoundedRectangle(cornerRadius: 1.5))
                Text("Your Workout").font(.title3.weight(.semibold))
                Spacer()
            }
            VStack(spacing: 10) {
                ForEach(viewModel.generatedWorkout) { exercise in
                    ExerciseCard(name: exercise.name,
                                 reps: exercise.reps,
                                 primary: exercise.muscles.primary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: GenTheme.corner)
                .fill(GenTheme.cardBG)
                .overlay(RoundedRectangle(cornerRadius: GenTheme.corner).stroke(GenTheme.separator.opacity(0.35), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}

fileprivate struct TrainingFocusCard: View {
    let title: String
    let rows: [(muscle: String, score: Int)]
    var maxScore: CGFloat { CGFloat(rows.map(\.score).max() ?? 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                GenTheme.accentGradient.frame(width: 3, height: 16).clipShape(RoundedRectangle(cornerRadius: 1.5))
                Text("Training Focus: \(title.capitalized)").font(.title3.weight(.semibold))
                Spacer()
            }
            VStack(spacing: 10) {
                ForEach(rows, id: \.muscle) { row in
                    FocusBarRow(label: row.muscle, value: CGFloat(row.score), maxValue: maxScore)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: GenTheme.corner)
                .fill(GenTheme.cardBG)
                .overlay(RoundedRectangle(cornerRadius: GenTheme.corner).stroke(GenTheme.separator.opacity(0.35), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}

fileprivate struct TipsCard: View {
    let tips: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                GenTheme.accentGradient.frame(width: 3, height: 16).clipShape(RoundedRectangle(cornerRadius: 1.5))
                Text("Notes").font(.title3.weight(.semibold))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(GenTheme.accent1.opacity(0.4)).frame(width: 6, height: 6).padding(.top, 7)
                        Text(tip).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: GenTheme.corner)
                .fill(GenTheme.cardBG)
                .overlay(RoundedRectangle(cornerRadius: GenTheme.corner).stroke(GenTheme.separator.opacity(0.35), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - Components

fileprivate struct MetricTile: View {
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
            RoundedRectangle(cornerRadius: GenTheme.chipCorner)
                .fill(GenTheme.pageBG)
                .overlay(RoundedRectangle(cornerRadius: GenTheme.chipCorner).stroke(GenTheme.separator.opacity(0.35), lineWidth: 1))
        )
    }
}

fileprivate struct ExerciseCard: View {
    let name: String
    let reps: String?
    let primary: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GenTheme.accentGradient.frame(width: 3).clipShape(RoundedRectangle(cornerRadius: 1.5))
            VStack(alignment: .leading, spacing: 6) {
                Text(name).font(.headline)
                if let r = reps, !r.isEmpty {
                    Text(r).font(.subheadline).foregroundStyle(.secondary)
                }
                if !primary.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(Array(primary.prefix(3)), id: \.self) { m in
                            TagChip(text: m)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: GenTheme.corner)
                .fill(GenTheme.pageBG)
                .overlay(RoundedRectangle(cornerRadius: GenTheme.corner).stroke(GenTheme.separator.opacity(0.35), lineWidth: 1))
        )
    }
}

fileprivate struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: GenTheme.chipCorner).fill(GenTheme.accent1.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: GenTheme.chipCorner).stroke(GenTheme.accent1.opacity(0.6), lineWidth: 1))
    }
}

fileprivate struct FocusBarRow: View {
    let label: String
    let value: CGFloat
    let maxValue: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.subheadline)
                Spacer()
                Text("+\(Int(value))").font(.footnote).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                let w = max(0, min(1, maxValue == 0 ? 0 : value / maxValue))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(GenTheme.pageBG)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(GenTheme.separator.opacity(0.35), lineWidth: 1))
                    RoundedRectangle(cornerRadius: 6)
                        .fill(GenTheme.accentGradient)
                        .frame(width: geo.size.width * w)
                }
            }
            .frame(height: 10)
        }
    }
}

fileprivate struct EmptyStateCard: View {
    let action: () -> Void
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(GenTheme.accent1)
            Text("No workout yet").font(.headline)
            Text("Tap Generate to build a session based on your selections.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text("Generate Workout")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(GenTheme.accent1)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: GenTheme.corner)
                .fill(GenTheme.cardBG)
                .overlay(RoundedRectangle(cornerRadius: GenTheme.corner).stroke(GenTheme.separator.opacity(0.35), lineWidth: 1))
        )
        .padding(.horizontal, 16)
    }
}
