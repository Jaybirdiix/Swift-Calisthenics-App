import SwiftUI

struct GeneratedWorkoutView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    private let tips = ["Warm up 5–10 min", "Rest 60–90 s between sets", "Cool down & stretch"]
    
    // Builds a focus summary when exactly one skill is selected.
    // Returns the selected skill name and a sorted list of (muscle, score).
    private var trainingFocusData: (title: String, rows: [(muscle: String, score: Int)])? {
        // Require exactly one selected skill and find its reference exercise
        guard viewModel.selectedSkills.count == 1,
              let chosen = viewModel.selectedSkills.first,
              let reference = viewModel.allExercises.first(where: { $0.name == chosen })
        else { return nil }

        // Muscles that matter for this skill
        let keyMuscles = Set(reference.muscles.primary
                           + reference.muscles.secondary
                           + reference.muscles.tertiary)

        // Weighted tally across today's generated workout
        var tally: [String: Int] = [:]
        for ex in viewModel.generatedWorkout {
            for m in ex.muscles.primary   where keyMuscles.contains(m) { tally[m, default: 0] += 3 }
            for m in ex.muscles.secondary where keyMuscles.contains(m) { tally[m, default: 0] += 2 }
            for m in ex.muscles.tertiary  where keyMuscles.contains(m) { tally[m, default: 0] += 1 }
        }

        // Sort by score (desc), then name for stability
        let rows = tally
            .sorted { ($0.value, $0.key) > ($1.value, $1.key) }
            .map { (muscle: $0.key, score: $0.value) }

        return (title: chosen, rows: rows)
    }


    var body: some View {
        VStack(spacing: 20) {
            Button {
                Task { await viewModel.generateWorkoutWithAI() }
            } label: {
                Text("Generate Workout")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }


            if viewModel.generatedWorkout.isEmpty {
                Text("No workout yet. Tap the button!")
                    .foregroundColor(.secondary)
            } else {
                List {
                    // 1) Your Workout
                    Section(header: Text("Your Workout").font(.title2)) {
                        ForEach(viewModel.generatedWorkout) { exercise in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name).font(.headline)
                                if let reps = exercise.reps, !reps.isEmpty {
                                    Text(reps).font(.caption).foregroundColor(.gray)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    // --- Summary ---
                    Section(header: Text("Summary").font(.title3)) {
                        HStack {
                            Text("Exercises")
                            Spacer()
                            Text("\(viewModel.generatedWorkout.count)")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("With reps specified")
                            Spacer()
                            Text("\(viewModel.generatedWorkout.filter { ($0.reps?.isEmpty == false) }.count)")
                                .foregroundColor(.secondary)
                        }
                    }

                    // --- Training Focus (only shows if exactly one skill is selected) ---
                    if let focus = trainingFocusData {
                        Section(
                            header: Text("Training Focus: \(focus.title)").font(.title3)
                        ) {
                            ForEach(focus.rows, id: \.muscle) { row in
                                HStack {
                                    Text(row.muscle)
                                    Spacer()
                                    Text("+\(row.score)").foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    // 2) Second "window" UNDERNEATH — a simple summary/tips list
                    Section(header: Text("Summary").font(.title3)) {
                        HStack {
                            Text("Exercises")
                            Spacer()
                            Text("\(viewModel.generatedWorkout.count)")
                                .foregroundColor(.secondary)
                        }
//                        HStack {
//                            Text("With reps specified")
//                            Spacer()
//                            Text("\(viewModel.generatedWorkout.filter { ($0.reps?.isEmpty == false) }.count)")
//                                .foregroundColor(.secondary)
//                        }
                        // ---- Training Focus (shown when exactly one skill is selected) ----
                        if let focusName = viewModel.trainingFocusSkillName,
                           !viewModel.trainingFocusScores.isEmpty {

                            Section(header: Text("Training Focus: \(focusName.uppercased())")) {
                                ForEach(viewModel.sortedTrainingFocus, id: \.0) { muscle, score in
                                    HStack {
                                        Text(muscle)
                                        Spacer()
                                        Text("+\(score)")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }

                    }

                    Section(header: Text("Notes")) {
                        ForEach(tips, id: \.self) { tip in
                            Text(tip)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Generated Workout")
    }
}

