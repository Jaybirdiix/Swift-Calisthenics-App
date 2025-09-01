//
//  ExerciseListView.swift
//  New Project
//
//  Created by Celeste van Dokkum on 8/6/25.
//


import SwiftUI

struct ExerciseListView: View {
    @ObservedObject var viewModel: WorkoutViewModel
    @State private var searchText = ""

    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return viewModel.allExercises
        } else {
            return viewModel.allExercises.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationView {
//            Button("🧨 Reset Skill Progressions") {
//                UserDefaults.standard.removeObject(forKey: "skillProgressions.v1")
//            }

            List {
                ForEach(filteredExercises) { exercise in
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        VStack(alignment: .leading) {
                            Text(exercise.name).font(.headline)
                            Text(exercise.description).font(.subheadline).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("All Exercises")
        }
    }
}
