//
//  WorkoutViewModel.swift
//  New Project
//
//  Created by Celeste van Dokkum on 8/6/25.
//
import SwiftUI

import Foundation

import Foundation
import SwiftUI

// --- API config (dev vs prod) ---
private enum API {
    #if DEBUG
    static let baseURL = URL(string: "http://127.0.0.1:8000")!
    #else
    static let baseURL = URL(string: "https://YOUR-PROD-URL")!
    #endif
}

// --- DTOs that match the FastAPI /plan endpoint ---
private struct PlanRequestDTO: Codable {
    let target_muscles: [String]
    let number_of_exercises: Int
    let min_difficulty: Int
    let max_difficulty: Int
    let user_skills: [String]
    let gate_by_skills: Bool
}

private struct PlanExerciseDTO: Codable, Identifiable {
    var id: String { name }            // use name as stable id
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


class WorkoutViewModel: ObservableObject {
    @Published var allExercises: [Exercise] = []
    @Published var selectedMuscles: [String] = []
    @Published var selectedSkills: [String] = []
    @Published var generatedWorkout: [Exercise] = []
    
    @Published var trainingFocusScores: [String: Int] = [:]
    
    @Published var aiFocusScores: [(muscle: String, score: Int)] = []
    @Published var aiNotes: [String] = []


    var trainingFocusSkillName: String? {
        selectedSkills.count == 1 ? selectedSkills.first : nil
    }

    var sortedTrainingFocus: [(String, Int)] {
        trainingFocusScores.sorted { $0.value > $1.value }
    }


    init() {
        loadExercises()
    }

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
    
//    added
    private func keyMusclesFromSelectedSkill() -> [String] {
        guard selectedSkills.count == 1,
              let chosen = selectedSkills.first,
              let reference = allExercises.first(where: { $0.name == chosen })
        else { return [] }

        let keys = Set(reference.muscles.primary + reference.muscles.secondary + reference.muscles.tertiary)
        return Array(keys)
    }
    
    func generateWorkoutWithAI() async {
        let targets = keyMusclesFromSelectedSkill()
        guard !targets.isEmpty else {
            // Optional: clear or fall back to your local generator
            self.generatedWorkout = []
            return
        }

        let body = PlanRequestDTO(
            target_muscles: targets,
            number_of_exercises: 6,
            min_difficulty: 1,
            max_difficulty: 10,
            user_skills: [],            // fill if you track unlocked skills
            gate_by_skills: false
        )

        var req = URLRequest(url: API.baseURL.appendingPathComponent("plan"))
        req.httpMethod = "POST"
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            let dto = try JSONDecoder().decode(PlanResponseDTO.self, from: data)

            // Map DTO -> your app's Exercise model
            self.generatedWorkout = dto.plan.map { p in
                Exercise(
                    id: UUID(),  // if your Exercise uses a String id, use p.id
                    name: p.name,
                    reps: p.reps,
                    muscles: .init(primary: [], secondary: [], tertiary: [])
                )
            }

            // Save focus scores and notes if you want to show them
            self.aiFocusScores = dto.focus_scores
                .sorted { ($0.value, $0.key) > ($1.value, $1.key) }
                .map { ($0.key, $0.value) }
            self.aiNotes = dto.notes

        } catch {
            print("AI plan fetch failed:", error)
            // Optional: fall back to local generator on failure
            // self.generateWorkout()
        }
    }

    
        //---------

    

    
    // helper function for generateWorkout
    private func score(exercise: Exercise, primary: Set<String>, secondary: Set<String>, tertiary: Set<String>) -> Int {
        var score = 0
        for m in exercise.muscles.primary { if primary.contains(m) { score += 6 } } // primary muscles line up
        for m in exercise.muscles.secondary { if primary.contains(m) { score += 3 } } // secondary ex is primary in skill
        for m in exercise.muscles.tertiary { if primary.contains(m) { score += 1 } } // tertiary in ex is primary in skill
        for m in exercise.muscles.primary { if secondary.contains(m) { score += 4 } } // primary in ex is secondary in skill
        for m in exercise.muscles.secondary { if secondary.contains(m) { score += 3 } } // secondaries line up
        for m in exercise.muscles.primary { if tertiary.contains(m) { score += 1 } }
        return score
    }

    func generateWorkout(count: Int = 8) {
        defer {
            if selectedSkills.count != 1 { trainingFocusScores = [:] }
        }

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

            // Prioritize by score, then mix up the top pool so each tap varies
            let unlockedSkills = unlockedSkillsFromProgressions()
            
            print("Unlocked:", unlockedSkillsFromProgressions())


            let eligibleExercises = allExercises.filter { ex in
                ex.requiredSkills.allSatisfy { unlockedSkills.contains($0) }
            }

            // ✅ Use filtered list
            let ranked = eligibleExercises
                .map { ($0, score($0)) }
                .sorted { $0.1 > $1.1 }
                .map { $0.0 }
            
            if eligibleExercises.isEmpty {
                print("⚠️ No eligible exercises available for current skill unlocks.")
                generatedWorkout = []
                return
            }

            let pool = Array(ranked.prefix(max(count * 2, 12)))
            generatedWorkout = Array(pool.shuffled().prefix(count))

            // Compute bottom “Training Focus” scores based on generatedWorkout
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
        let unlockedSkills = unlockedSkillsFromProgressions()
        let muscleSet = Set(selectedMuscles)

        let eligibleExercises = allExercises.filter { ex in
            ex.requiredSkills.allSatisfy { unlockedSkills.contains($0) }
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

    
    // You can expand this as needed
    func muscleGroup(for muscle: String) -> String {
        switch muscle {
        case "Rectus Abdominis", "Obliques", "Transversus Abdominis":
            return "Core"
        case "Anterior Deltoid", "Lateral Deltoid", "Posterior Deltoid":
            return "Shoulders"
        case "Latissimus Dorsi", "Upper Trapezius", "Rhomboids", "Lower Trapezius", "Middle Trapezius":
            return "Back"
        case "Gluteus Maximus", "Gluteus Medius":
            return "Glutes"
        case "Rectus Femoris", "Sartorius", "Quadriceps":
            return "Legs"
        case "Forearm Flexors", "Forearm Extensors":
            return "Forearms"
        case "Triceps Brachii", "Biceps Brachii":
            return "Arms"
        case "Pectoralis Major", "Pectoralis Minor":
            return "Chest"
        default:
            return "Other"
        }
    }
    
    @AppStorage("skillProgressions.v1") private var savedProgressionData: Data = Data()

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
        
//        print("Unlocked:", unlockedSkillsFromProgressions())

        
        return unlocked
    }

    



}


