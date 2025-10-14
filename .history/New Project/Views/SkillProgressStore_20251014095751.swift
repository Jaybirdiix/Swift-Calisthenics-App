// import Foundation

// // Reuse your models
// // enum SkillCategory: String, CaseIterable, Identifiable, Codable, Hashable { ... }
// // struct ProgressionStep: Identifiable, Equatable, Codable { ... }
// // struct Progression: Identifiable, Equatable, Codable { ... }

// enum SkillProgressStore {
//     static let storeKey = "skillProgressions.v1"

//     /// Load saved progressions and merge with your default template.
//     static func loadMergedProgressions(
//         defaults: [SkillCategory: [Progression]]
//     ) -> [SkillCategory: [Progression]] {
//         guard let data = UserDefaults.standard.data(forKey: storeKey) else {
//             return defaults
//         }
//         do {
//             // Saved format is [String: [Progression]] keyed by category rawValue
//             let savedRaw = try JSONDecoder().decode([String: [Progression]].self, from: data)
//             var saved: [SkillCategory: [Progression]] = [:]
//             for (k, v) in savedRaw {
//                 if let cat = SkillCategory(rawValue: k) {
//                     saved[cat] = v
//                 }
//             }
//             return merge(template: defaults, with: saved)
//         } catch {
//             return defaults
//         }
//     }

//     /// Flatten to a Set of unlocked step names (exact strings, e.g. "Archer Pull Up").
//     static func unlockedSkillNames(
//         defaults: [SkillCategory: [Progression]]
//     ) -> Set<String> {
//         let merged = loadMergedProgressions(defaults: defaults)
//         let names = merged.values
//             .flatMap { $0 }            // [Progression]
//             .flatMap { $0.steps }      // [ProgressionStep]
//             .filter { $0.isUnlocked }
//             .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
//         return Set(names)
//     }

//     /// Also handy if you want per-category lists for UI/debugging.
//     static func unlockedByCategory(
//         defaults: [SkillCategory: [Progression]]
//     ) -> [String: [String]] {
//         let merged = loadMergedProgressions(defaults: defaults)
//         var out: [String: [String]] = [:]
//         for (cat, progs) in merged {
//             let names = progs.flatMap { $0.steps }
//                 .filter { $0.isUnlocked }
//                 .map { $0.name }
//             out[cat.rawValue] = names
//         }
//         return out
//     }

//     /// Export unlocked names to JSON (e.g., to feed the workout generator).
//     @discardableResult
//     static func exportUnlockedJSON(
//         defaults: [SkillCategory: [Progression]],
//         to url: URL? = nil
//     ) throws -> URL {
//         struct Payload: Codable {
//             let unlockedSkillNames: [String]
//             let unlockedByCategory: [String: [String]]
//         }
//         let unlocked = Array(unlockedSkillNames(defaults: defaults)).sorted()
//         let byCat = unlockedByCategory(defaults: defaults)
//         let payload = Payload(unlockedSkillNames: unlocked, unlockedByCategory: byCat)

//         let data = try JSONEncoder().encode(payload)
//         let fileURL =
//             url ??
//             FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//                 .appendingPathComponent("unlocked_skills.json")
//         try data.write(to: fileURL, options: .atomic)
//         return fileURL
//     }

//     // MARK: - merge (same logic you have in the view)
//     private static func merge(
//         template: [SkillCategory: [Progression]],
//         with saved: [SkillCategory: [Progression]]
//     ) -> [SkillCategory: [Progression]] {
//         var result = template
//         for (cat, defaults) in template {
//             let savedProgs = saved[cat] ?? []
//             var merged: [Progression] = []
//             for defProg in defaults {
//                 if let savedProg = savedProgs.first(where: { $0.title == defProg.title }) {
//                     var mergedSteps: [ProgressionStep] = []
//                     for step in defProg.steps {
//                         if let savedStep = savedProg.steps.first(where: { $0.name == step.name }) {
//                             mergedSteps.append(savedStep)
//                         } else {
//                             mergedSteps.append(step)
//                         }
//                     }
//                     merged.append(Progression(title: defProg.title, steps: mergedSteps))
//                 } else {
//                     merged.append(defProg)
//                 }
//             }
//             for extra in savedProgs where !defaults.contains(where: { $0.title == extra.title }) {
//                 merged.append(extra)
//             }
//             result[cat] = merged
//         }
//         for (cat, progs) in saved where result[cat] == nil {
//             result[cat] = progs
//         }
//         return result
//     }
// }
