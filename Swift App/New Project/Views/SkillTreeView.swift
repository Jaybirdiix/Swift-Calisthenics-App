//import SwiftUI
//
//// MARK: - Models
//
//enum SkillCategory: String, CaseIterable, Identifiable {
//    case horizontalPull = "Horizontal Pull"
//    case verticalPull   = "Vertical Pull"
//    case verticalPush   = "Vertical Push"
//    case horizontalPush = "Horizontal Push"
//    case core           = "Core"
//    case legs           = "Legs"
//
//    var id: String { rawValue }
//}
//
//struct ProgressionStep: Identifiable, Equatable {
//    let id = UUID()
//    let name: String
//    var isUnlocked: Bool = false
//}
//
//struct Progression: Identifiable, Equatable {
//    let id = UUID()
//    let title: String         // e.g. "Planche Progression"
//    var steps: [ProgressionStep]
//}
//
//// MARK: - View
//
//struct SkillProgressionsView: View {
//    @State private var selectedCategory: SkillCategory = .horizontalPush
//
//    // Store progressions per category so we can bind and toggle
//    @State private var progressionsByCategory: [SkillCategory: [Progression]] = [
//        // Example: Horizontal Push contains our Planche progression list
//        .horizontalPush: [
//            Progression(
//                title: "Planche Progression",
//                steps: [
//                    ProgressionStep(name: "Band-Assisted Tuck Planche"),
//                    ProgressionStep(name: "Tuck Planche"),
//                    ProgressionStep(name: "Band-Assisted Advanced Tuck Planche"),
//                    ProgressionStep(name: "Advanced Tuck Planche"),
//                    ProgressionStep(name: "Band-Assisted Straddle Planche"),
//                    ProgressionStep(name: "Straddle Planche"),
//                    ProgressionStep(name: "Band-Assisted Full Planche"),
//                    ProgressionStep(name: "Full Planche")
//                ]
//            )
//        ],
//
//        // Stubs you can fill out later
//        .horizontalPull: [],
//        .verticalPull:   [],
//        .verticalPush:   [],
//        .core:           [],
//        .legs:           []
//    ]
//
//    var body: some View {
//        VStack {
//            Picker("Category", selection: $selectedCategory) {
//                ForEach(SkillCategory.allCases) { cat in
//                    Text(cat.rawValue).tag(cat)
//                }
//            }
//            .pickerStyle(.segmented)
//            .padding(.horizontal)
//
//            if progressionsByCategory[selectedCategory, default: []].isEmpty {
//                // Empty state
//                VStack(spacing: 12) {
//                    Text("No progressions yet")
//                        .font(.headline)
//                        .foregroundColor(.secondary)
//                    Text("Add a list of steps for \(selectedCategory.rawValue).")
//                        .font(.subheadline)
//                        .foregroundColor(.secondary)
//                }
//                .padding(.top, 40)
//            } else {
//                // List of progressions for selected category
//                List {
//                    ForEach(progressionsBinding(for: selectedCategory)) { $prog in
//                        Section(header: Text(prog.title).font(.headline)) {
//                            ForEach($prog.steps) { $step in
//                                HStack {
//                                    Text(step.name)
//                                    Spacer()
//                                    Button {
//                                        step.isUnlocked.toggle()
//                                    } label: {
//                                        Image(systemName: step.isUnlocked ? "checkmark.circle.fill" : "circle")
//                                            .foregroundColor(step.isUnlocked ? .green : .gray)
//                                    }
//                                    .buttonStyle(.plain)
//                                }
//                            }
//                        }
//                    }
//                }
//                .listStyle(.insetGrouped)
//            }
//        }
//        .navigationTitle("Skill Progressions")
//    }
//
//    // Gives us bindings into the dictionary for ForEach with `$prog`
//    private func progressionsBinding(for category: SkillCategory) -> Binding<[Progression]> {
//        Binding(
//            get: { progressionsByCategory[category] ?? [] },
//            set: { progressionsByCategory[category] = $0 }
//        )
//    }
//}
