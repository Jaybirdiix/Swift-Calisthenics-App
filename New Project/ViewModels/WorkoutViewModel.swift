//
//  WorkoutViewModel.swift
//  New Project
//
//  Created by Celeste van Dokkum on 8/6/25.
//

import Foundation
import SwiftUI

// MARK: - API config (dev vs prod)
private enum API {
    #if DEBUG
    static let baseURL = URL(string: "http://127.0.0.1:8000")!
    #else
    static let baseURL = URL(string: "https://YOUR-PROD-URL")!
    #endif
}

// MARK: - DTOs matching FastAPI /plan
private struct PlanRequestDTO: Codable {
    let target_muscles: [String]
    let number_of_exercises: Int
    let min_difficulty: Int
    let max_difficulty: Int
    let user_skills: [String]
    let gate_by_skills: Bool
    let use_llm: Bool                 // AI selection + AI reps
    let goal: String?                 // optional coaching context
    let session_minutes: Int?         // optional
}

private struct PlanExerciseDTO: Codable, Identifiable {
    var id: String { name }           // use name as a stable id
    let name: String
    let description: String
    let difficulty: Int
    let reps: String?
}

private struct PlanResponseDTO: Codable {
    let plan: [PlanExerciseDTO]
    let focus_scores: [String: Int]
    let notes: [String]
}

// MARK: - ViewModel
@MainActor
final class WorkoutViewModel: ObservableObject {
    // Data
    @Published var allExercises: [Exercise] = []
    @Published var generatedWorkout: [Exercise] = []

    // Selections
    @Published var selectedMuscles: [String] = []
    @Published var selectedSkills: [String] = []

    // Focus summary used by your UI
    @Published var trainingFocusScores: [String: Int] = [:]

    var trainingFocusSkillName: String? {
        selectedSkills.count == 1 ? selectedSkills.first : nil
    }

    var sortedTrainingFocus: [(String, Int)] {
        trainingFocusScores.sorted { $0.value > $1.value }
    }

    // Persisted skill progressions
    @AppStorage("skillProgressions.v1") private var savedProgressionData: Data = Data()

    // Init
    init() {
        loadExercises()
    }

    // MARK: - Loading local dataset
    func loadExercises() {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Exercise].self, from: data) else {
            print("🚨 Failed to load exercises.json")
            return
        }
        print("✅ Loaded \(decoded.count) exercises")
        self.allExercises = decoded
    }

    // MARK: - AI plan (FastAPI)
    /// Derive key muscles from the single selected skill (returns [] if 0 or >1 skills selected)
    private func keyMusclesFromSelectedSkill() -> [String] {
        guard selectedSkills.count == 1,
              let chosen = selectedSkills.first,
              let reference = allExercises.first(where: { $0.name == chosen })
        else { return [] }

        let keys = Set(reference.muscles.primary + reference.muscles.secondary + reference.muscles.tertiary)
        return Array(keys)
    }

    /// Calls the FastAPI /plan endpoint and maps results back to your Exercise model
    func generateWorkoutWithAI() async {
        // Use target muscles from single selected skill if present;
        // otherwise fall back to whatever is in selectedMuscles.
        let targets = keyMusclesFromSelectedSkill().isEmpty ? selectedMuscles : keyMusclesFromSelectedSkill()
        guard !targets.isEmpty else {
            print("⚠️ AI: no targets. Select a skill or some muscles.")
            self.generatedWorkout = []
            self.trainingFocusScores = [:]
            return
        }

        let body = PlanRequestDTO(
            target_muscles: targets,
            number_of_exercises: 8,               // tweak to taste
            min_difficulty: 1,
            max_difficulty: 10,
            user_skills: Array(unlockedSkillsFromProgressions()),
            gate_by_skills: true,                 // hide items requiring locked skills
            use_llm: true,                        // 🔹 AI selection + reps
            goal: trainingFocusSkillName ?? "Balanced, fun session with variety",
            session_minutes: 45
        )

        var req = URLRequest(url: API.baseURL.appendingPathComponent("plan"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let dto = try JSONDecoder().decode(PlanResponseDTO.self, from: data)

            print("✅ AI returned \(dto.plan.count) items: \(dto.plan.map { $0.name })")

            // ---- NAME-NORMALIZED MATCH WITH FALLBACK ----
            func normalize(_ s: String) -> String {
                s.lowercased()
                 .replacingOccurrences(of: "–", with: "-")
                 .replacingOccurrences(of: "’", with: "'")
                 .replacingOccurrences(of: " push ups", with: " push up")
                 .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let mapped: [Exercise] = dto.plan.map { item in
                // try exact, then normalized name match
                if let ref = allExercises.first(where: { $0.name == item.name }) {
                    var e = ref; e.reps = item.reps; return e
                } else if let ref = allExercises.first(where: { normalize($0.name) == normalize(item.name) }) {
                    var e = ref; e.reps = item.reps; return e
                } else {
                    // fallback: still show it so UI isn’t empty
                    return Exercise(
                        id: UUID(),
                        name: item.name,
                        description: item.description,
                        difficulty: item.difficulty,
                        muscles: Exercise.Muscles(primary: [], secondary: [], tertiary: []),
                        reps: item.reps,
                        requiredSkills: []
                    )
                }
            }
            self.generatedWorkout = mapped
            self.trainingFocusScores = dto.focus_scores

            print("📋 mapped \(self.generatedWorkout.count) items.")
        } catch {
            print("❌ AI plan fetch failed:", error)
            self.generatedWorkout = []
            self.trainingFocusScores = [:]
        }
    }

    // MARK: - Local generator (fallback / offline)
    func generateWorkout(count: Int = 8) {
        defer { if selectedSkills.count != 1 { trainingFocusScores = [:] } }

        if let skill = selectedSkills.first,
           let skillExercise = allExercises.first(where: { $0.name == skill }) {

            let primaryMuscles   = Set(skillExercise.muscles.primary)
            let secondaryMuscles = Set(skillExercise.muscles.secondary)
            let tertiaryMuscles  = Set(skillExercise.muscles.tertiary)

            func score(_ ex: Exercise) -> Int {
                var total = 0
                total += ex.muscles.primary.filter   { primaryMuscles.contains($0)   }.count * 3
                total += ex.muscles.secondary.filter { secondaryMuscles.contains($0) }.count * 2
                total += ex.muscles.tertiary.filter  { tertiaryMuscles.contains($0)  }.count * 1
                return total
            }

            let unlocked = unlockedSkillsFromProgressions()
            let eligibleExercises = allExercises.filter { ex in
                ex.requiredSkills.allSatisfy { unlocked.contains($0) }
            }

            guard !eligibleExercises.isEmpty else {
                print("⚠️ No eligible exercises available for current skill unlocks.")
                generatedWorkout = []
                return
            }

            let ranked = eligibleExercises
                .map { ($0, score($0)) }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }

            let pool = Array(ranked.prefix(max(count * 2, 12)))
            generatedWorkout = Array(pool.shuffled().prefix(count))

            // Compute Training Focus from the generated workout
            var scores: [String: Int] = [:]
            let important = primaryMuscles.union(secondaryMuscles).union(tertiaryMuscles)
            for ex in generatedWorkout {
                for m in ex.muscles.primary   where important.contains(m) { scores[m, default: 0] += 3 }
                for m in ex.muscles.secondary where important.contains(m) { scores[m, default: 0] += 2 }
                for m in ex.muscles.tertiary  where important.contains(m) { scores[m, default: 0] += 1 }
            }
            trainingFocusScores = scores
            return
        }

        // Fallback: muscle-based, filtered by unlocked skills
        let unlocked = unlockedSkillsFromProgressions()
        let muscleSet = Set(selectedMuscles)

        let eligibleExercises = allExercises.filter { ex in
            ex.requiredSkills.allSatisfy { unlocked.contains($0) }
        }

        generatedWorkout = eligibleExercises
            .filter { ex in
                muscleSet.isEmpty
                ? true
                : !Set(ex.muscles.primary + ex.muscles.secondary + ex.muscles.tertiary).isDisjoint(with: muscleSet)
            }
            .shuffled()
            .prefix(count)
            .map { $0 }
    }

    // MARK: - Grouping helpers (unchanged)
    struct MuscleGroupSection: Identifiable {
        let id = UUID()
        let groupName: String
        let muscleName: String
        let exercises: [Exercise]
    }

    func groupedByMuscle() -> [MuscleGroupSection] {
        var grouped: [String: [String: [Exercise]]] = [:]
        for exercise in allExercises {
            for muscle in exercise.muscles.primary {
                let group = muscleGroup(for: muscle)
                grouped[group, default: [:]][muscle, default: []].append(exercise)
            }
        }
        return grouped.flatMap { groupName, musclesDict in
            musclesDict.map { muscle, exercises in
                MuscleGroupSection(groupName: groupName, muscleName: muscle, exercises: exercises)
            }
        }.sorted { $0.groupName < $1.groupName }
    }

    var allMuscleGroups: [String] {
        let all = allExercises.flatMap { $0.muscles.primary + $0.muscles.secondary + $0.muscles.tertiary }
        return Array(Set(all)).sorted()
    }

    func muscleGroup(for muscle: String) -> String {
        switch muscle {
        case "Rectus Abdominis", "Obliques", "Transversus Abdominis": return "Core"
        case "Anterior Deltoid", "Lateral Deltoid", "Posterior Deltoid": return "Shoulders"
        case "Latissimus Dorsi", "Upper Trapezius", "Rhomboids", "Lower Trapezius", "Middle Trapezius": return "Back"
        case "Gluteus Maximus", "Gluteus Medius": return "Glutes"
        case "Rectus Femoris", "Sartorius", "Quadriceps": return "Legs"
        case "Forearm Flexors", "Forearm Extensors": return "Forearms"
        case "Triceps Brachii", "Biceps Brachii": return "Arms"
        case "Pectoralis Major", "Pectoralis Minor": return "Chest"
        default: return "Other"
        }
    }

    // MARK: - Progressions
    func unlockedSkillsFromProgressions() -> Set<String> {
        guard let saved = try? JSONDecoder().decode([String: [Progression]].self, from: savedProgressionData) else {
            return []
        }
        var unlocked: Set<String> = []
        for (_, progressions) in saved {
            for progression in progressions {
                for step in progression.steps where step.isUnlocked {
                    unlocked.insert(step.name)
                }
            }
        }
        return unlocked
    }
}
