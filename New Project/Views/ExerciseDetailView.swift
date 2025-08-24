//
//  ExerciseDetailView.swift
//  New Project
//
//  Created by Celeste van Dokkum on 8/6/25.
//

import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Name
                Text(exercise.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top)

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(exercise.description)
                        .font(.body)
                }

                // Muscle groups
                VStack(alignment: .leading, spacing: 12) {
                    if !exercise.muscles.primary.isEmpty {
                        SectionView(title: "Primary Muscles", items: exercise.muscles.primary)
                    }
                    if !exercise.muscles.secondary.isEmpty {
                        SectionView(title: "Secondary Muscles", items: exercise.muscles.secondary)
                    }
                    if !exercise.muscles.tertiary.isEmpty {
                        SectionView(title: "Tertiary Muscles", items: exercise.muscles.tertiary)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Reusable section view for muscles

struct SectionView: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)

            ForEach(items, id: \.self) { muscle in
                Text("• \(muscle)")
                    .font(.body)
            }
        }
    }
}
