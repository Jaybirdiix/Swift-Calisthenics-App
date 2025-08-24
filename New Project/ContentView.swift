import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WorkoutViewModel()

    var body: some View {
        TabView {
            ExerciseListView(viewModel: viewModel)
                .tabItem { Label("Exercises", systemImage: "list.bullet") }

            WorkoutGeneratorView(viewModel: viewModel)
                .tabItem { Label("Workout", systemImage: "bolt.fill") }

            SkillProgressionsView()
                .tabItem { Label("Skill Lists", systemImage: "list.bullet.rectangle") }
        }
    }
}
