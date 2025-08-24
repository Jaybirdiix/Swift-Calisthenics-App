//
//  WorkoutGeneratorView.swift
//  New Project
//
//  Created by Celeste van Dokkum on 8/6/25.
//

import SwiftUI

struct WorkoutGeneratorView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    
    var body: some View {
        NavigationView {
            Form {
                MuscleGroupSection(viewModel: viewModel)
                SkillSection(viewModel: viewModel)
                
                NavigationLink("Generate Workout") {
                    GeneratedWorkoutView(viewModel: viewModel)
                }
            }
            .navigationTitle("Generate Workout")
        }
    }
    
    
    struct MuscleGroupSection: View {
        @ObservedObject var viewModel: WorkoutViewModel

        var body: some View {
            Section(header: Text("Select Muscle Groups")) {
                ForEach(viewModel.allMuscleGroups, id: \.self) { muscle in
                    Toggle(muscle, isOn: Binding(
                        get: { viewModel.selectedMuscles.contains(muscle) },
                        set: { isSelected in
                            if isSelected {
                                if !viewModel.selectedMuscles.contains(muscle) {
                                    viewModel.selectedMuscles.append(muscle)
                                }
                            } else {
                                viewModel.selectedMuscles.removeAll { $0 == muscle }
                            }
                        }
                    ))
                }
            }
            // lock muscle toggles whenever a skill is selected
            .disabled(!viewModel.selectedSkills.isEmpty)
        }
    }


    struct SkillSection: View {
        @ObservedObject var viewModel: WorkoutViewModel

        var body: some View {
            Section(header: Text("Select Skills")) {
                ForEach(Skill.allCases, id: \.self) { skill in
                    Toggle(skill.rawValue.capitalized, isOn: Binding(
                        get: { viewModel.selectedSkills.contains(skill.rawValue) },
                        set: { isSelected in
                            if isSelected {
                                // Exclusive skill selection
                                viewModel.selectedSkills = [skill.rawValue]
                                viewModel.selectedMuscles = [] // Deselect muscles
                            } else {
                                viewModel.selectedSkills = []
                            }
                        }
                    ))
                    .disabled(!viewModel.selectedSkills.isEmpty && !viewModel.selectedSkills.contains(skill.rawValue))

                }
            }
        }
    }

}
