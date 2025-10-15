//
//  ProfileTabView.swift
//  New Project
//
//  Created by Celeste van Dokkum on 10/14/25.
//

import SwiftUI

// MARK: - Minimal workout summary we’ll store/read
struct WorkoutSummary: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let title: String
    let durationMinutes: Int
    let exerciseCount: Int

    init(id: UUID = UUID(), date: Date = .now, title: String, durationMinutes: Int, exerciseCount: Int) {
        self.id = id
        self.date = date
        self.title = title
        self.durationMinutes = durationMinutes
        self.exerciseCount = exerciseCount
    }
}

// MARK: - Profile store (stats + persistence)
@MainActor
final class ProfileStore: ObservableObject {
    // AppStorage for persistent counters
    @AppStorage("profile.totalXP") var totalXP: Int = 0
    @AppStorage("profile.workoutsCompleted") var workoutsCompleted: Int = 0
    @AppStorage("profile.savedWorkouts") private var savedWorkoutsData: Data = Data()

    // Real data from your SkillProgressions
    @AppStorage("skillProgressions.v1") private var savedProgressionData: Data = Data()

    // Derived
    @Published var savedWorkouts: [WorkoutSummary] = []
    @Published var unlockedCount: Int = 0
    @Published var totalSkillsKnown: Int = 0
    @Published var streakDays: Int = 0

    // XP curve (simple & smooth)
    // xp required to REACH level L: 100 * L^2
    static func levelFromXP(_ xp: Int) -> (level: Int, progress: Double, nextLevelXP: Int) {
        func need(_ L: Int) -> Int { 100 * L * L }
        var L = 1
        while xp >= need(L + 1) { L += 1 }
        let curr = need(L), next = need(L + 1)
        let p = Double(xp - curr) / Double(next - curr)
        return (max(1, L), min(max(p, 0), 1), next)
    }

    init(seedIfEmpty: Bool = true) {
        loadSavedWorkouts()
        recomputeFromProgressions()
        recomputeStreak()
        if seedIfEmpty && savedWorkouts.isEmpty && workoutsCompleted == 0 && unlockedCount == 0 {
            seedDemo()
        }
        if totalXP == 0 && (unlockedCount > 0 || workoutsCompleted > 0) {
            totalXP = unlockedCount * 10 + workoutsCompleted * 50
        }
    }

    // MARK: - Public API you can call from the rest of the app
    func recordCompletedWorkout(title: String, durationMinutes: Int, exerciseCount: Int) {
        let w = WorkoutSummary(title: title, durationMinutes: durationMinutes, exerciseCount: exerciseCount)
        savedWorkouts.insert(w, at: 0)
        workoutsCompleted += 1
        totalXP += 50 + exerciseCount
        recomputeStreak()
        persistSavedWorkouts()
    }

    func savePlanAsWorkout(title: String, durationMinutes: Int, exerciseNames: [String]) {
        let w = WorkoutSummary(title: title, durationMinutes: durationMinutes, exerciseCount: exerciseNames.count)
        savedWorkouts.insert(w, at: 0)
        persistSavedWorkouts()
    }

    func resetDemo() {
        totalXP = 0
        workoutsCompleted = 0
        savedWorkouts = []
        persistSavedWorkouts()
        streakDays = 0
    }

    // MARK: - Internal

    private func loadSavedWorkouts() {
        guard !savedWorkoutsData.isEmpty,
              let arr = try? JSONDecoder().decode([WorkoutSummary].self, from: savedWorkoutsData) else {
            savedWorkouts = []
            return
        }
        savedWorkouts = arr.sorted { $0.date > $1.date }
    }

    private func persistSavedWorkouts() {
        if let data = try? JSONEncoder().encode(savedWorkouts) {
            savedWorkoutsData = data
        }
    }

    private func recomputeFromProgressions() {
        struct ProgressionStepLite: Codable { let name: String; let isUnlocked: Bool }
        struct ProgressionLite: Codable { let title: String; let steps: [ProgressionStepLite] }

        guard let dict = try? JSONDecoder().decode([String: [ProgressionLite]].self, from: savedProgressionData)
        else { unlockedCount = 0; totalSkillsKnown = 0; return }

        var unlocked = 0, total = 0
        for (_, progs) in dict {
            for p in progs {
                total += p.steps.count
                unlocked += p.steps.filter { $0.isUnlocked }.count
            }
        }
        unlockedCount = unlocked
        totalSkillsKnown = total
    }

    private func recomputeStreak() {
        guard let _ = savedWorkouts.first?.date else { streakDays = 0; return }
        let days = Set(savedWorkouts.map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >)
        guard !days.isEmpty else { streakDays = 0; return }

        var streak = 0
        var cursor = Calendar.current.startOfDay(for: Date())
        for d in days {
            if d == cursor { streak += 1; cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor)! }
            else if d == Calendar.current.date(byAdding: .day, value: -1, to: cursor)! {
                streak += 1
                cursor = Calendar.current.date(byAdding: .day, value: -2, to: cursor)!
            } else { break }
        }
        streakDays = streak
    }

    private func seedDemo() {
        let sample = [
            WorkoutSummary(title: "Push Focus + Core", durationMinutes: 42, exerciseCount: 7),
            WorkoutSummary(title: "Pull + HLR",        durationMinutes: 38, exerciseCount: 6),
            WorkoutSummary(title: "Planche Skills",    durationMinutes: 50, exerciseCount: 8)
        ]
        savedWorkouts = sample
        workoutsCompleted = sample.count
        totalXP = 600
        streakDays = 2
        persistSavedWorkouts()
    }
}

// MARK: - Brand
private enum ProfBrand {
    static let spacing: CGFloat = 16
    static let cardCorner: CGFloat = 14
    static let bg = Color(uiColor: .systemGroupedBackground)
    static let cardBG = Color(uiColor: .secondarySystemGroupedBackground)
    static let stroke = Color.black.opacity(0.08)
    static let accent1 = Color.indigo
    static let accent2 = Color.blue
    static let accent3 = Color.purple

    static var headerGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [accent1, accent2]), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Soft blob background
private struct ProfileBackground: View {
    var body: some View {
        ZStack {
            ProfBrand.bg.ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [ProfBrand.accent1.opacity(0.22), .clear]),
                           center: .topLeading, startRadius: 0, endRadius: 380)
            .blur(radius: 60).offset(x: -90, y: -140)

            RadialGradient(gradient: Gradient(colors: [ProfBrand.accent2.opacity(0.18), .clear]),
                           center: .bottomTrailing, startRadius: 0, endRadius: 420)
            .blur(radius: 65).offset(x: 120, y: 160)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Section card shell
private struct ProfileCard<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ProfBrand.accent1)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(ProfBrand.accent1.opacity(0.12))
                    )
                Text(title).font(.headline)
                Spacer(minLength: 4)
            }

            content

            // Accent underline
            ProfBrand.headerGradient
                .frame(height: 2)
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .padding(.top, 2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ProfBrand.cardCorner, style: .continuous)
                .fill(ProfBrand.cardBG)
                .overlay(
                    RoundedRectangle(cornerRadius: ProfBrand.cardCorner, style: .continuous)
                        .stroke(ProfBrand.stroke, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 6, y: 4)
    }
}

// MARK: - XP Ring
private struct XPRing: View {
    var level: Int
    var progress: Double
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(gradient: Gradient(colors: [.cyan, ProfBrand.accent2, ProfBrand.accent1, .cyan]),
                                    center: .center),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: ProfBrand.accent2.opacity(0.4), radius: 6, y: 2)
            VStack(spacing: 2) {
                Text("LV").font(.caption2).foregroundStyle(.secondary)
                Text("\(level)").font(.title3.bold())
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Stat pill
private struct StatPill: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .imageScale(.large)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(
                        Circle()
                            .fill(LinearGradient(gradient: Gradient(colors: [tint, tint.opacity(0.6)]),
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                Spacer()
            }
            Text(value)
                .font(.title3.weight(.semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(ProfBrand.stroke, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 3)
    }
}

// MARK: - Workout row
private struct WorkoutRow: View {
    let summary: WorkoutSummary
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.35), .indigo.opacity(0.35)]),
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "figure.cross.training")
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(summary.title).font(.body.weight(.semibold))
                Text("\(summary.exerciseCount) exercises • \(summary.durationMinutes) min")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(summary.date, style: .date)
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Profile Tab
struct ProfileTabView: View {
    @StateObject private var store = ProfileStore()

    var body: some View {
        NavigationStack {
            ZStack {
                ProfileBackground()

                ScrollView {
                    VStack(spacing: ProfBrand.spacing) {

                        // Header Card
                        ProfileCard(icon: "person.crop.circle.fill", title: "Athlete Profile") {
                            HStack(alignment: .center, spacing: 14) {
                                // Avatar + XP Ring
                                let lvl = ProfileStore.levelFromXP(store.totalXP)
                                ZStack {
                                    ProfBrand.headerGradient
                                        .clipShape(Circle())
                                        .frame(width: 68, height: 68)
                                        .overlay(Text("CV").font(.title2.weight(.bold)).foregroundStyle(.white))
                                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                                }
                                XPRing(level: lvl.level, progress: lvl.progress, size: 84)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Celeste van Dokkum")
                                        .font(.headline)
                                    // XP bar
                                    ProgressView(value: lvl.progress) {
                                        Text("Level \(lvl.level)").font(.caption)
                                    } currentValueLabel: {
                                        Text("\(store.totalXP) XP").font(.caption2).foregroundStyle(.secondary)
                                    }
                                    .progressViewStyle(.linear)
                                    .tint(ProfBrand.accent2)
                                }
                                Spacer()
                            }
                        }

                        // Stats Grid
                        ProfileCard(icon: "chart.bar.fill", title: "Stats") {
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                StatPill(title: "Skills Unlocked",
                                         value: "\(store.unlockedCount)\(store.totalSkillsKnown > 0 ? " / \(store.totalSkillsKnown)" : "")",
                                         icon: "checkmark.seal.fill", tint: .green)
                                StatPill(title: "Total XP", value: "\(store.totalXP)",
                                         icon: "bolt.circle.fill", tint: .yellow)
                                StatPill(title: "Workouts", value: "\(store.workoutsCompleted)",
                                         icon: "figure.strengthtraining.traditional", tint: .blue)
                                StatPill(title: "Saved Plans", value: "\(store.savedWorkouts.count)",
                                         icon: "bookmark.circle.fill", tint: .purple)
                                StatPill(title: "Streak", value: "\(store.streakDays)d",
                                         icon: "flame.fill", tint: .red)
                                let nxt = ProfileStore.levelFromXP(store.totalXP).nextLevelXP
                                StatPill(title: "Next Level",
                                         value: "\(max(0, nxt - store.totalXP)) XP",
                                         icon: "arrow.up.circle.fill", tint: .orange)
                            }
                        }

                        // Recent Workouts
                        ProfileCard(icon: "clock.arrow.circlepath", title: "Recent Workouts") {
                            if store.savedWorkouts.isEmpty {
                                HStack(spacing: 10) {
                                    Image(systemName: "rectangle.and.text.magnifyingglass")
                                        .foregroundStyle(ProfBrand.accent1)
                                    Text("No workouts yet. Generate one and mark as completed!")
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(store.savedWorkouts.prefix(10)) { w in
                                        WorkoutRow(summary: w)
                                    }
                                }
                            }

                            // Demo / Dev tools row
                            HStack(spacing: 10) {
                                Button {
                                    store.recordCompletedWorkout(
                                        title: ["Push + Core","Pull Day","Skills + Strength","Legs & Core","HS Prep"].randomElement()!,
                                        durationMinutes: [30,35,40,45,50].randomElement()!,
                                        exerciseCount: [5,6,7,8].randomElement()!
                                    )
                                } label: {
                                    Label("Add Fake Workout", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(ProfBrand.accent1)

                                Button(role: .destructive) {
                                    store.resetDemo()
                                } label: {
                                    Label("Reset Demo", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.top, 6)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .padding(.top, 8)
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}
