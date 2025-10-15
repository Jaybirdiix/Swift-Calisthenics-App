import SwiftUI

// MARK: - Brand
private enum AppBrand {
    static let bg = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
    static let stroke = Color.black.opacity(0.08)
    static let accent1 = Color.indigo
    static let accent2 = Color.blue
    static let accent3 = Color.purple

    static var accentGradient: LinearGradient {
        LinearGradient(gradient: Gradient(colors: [accent1, accent2]),
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Soft Blob Background
private struct AppBlobBackground: View {
    var body: some View {
        ZStack {
            AppBrand.bg.ignoresSafeArea()
            RadialGradient(gradient: Gradient(colors: [AppBrand.accent1.opacity(0.20), .clear]),
                           center: .topLeading, startRadius: 0, endRadius: 380)
                .blur(radius: 60).offset(x: -90, y: -140)
            RadialGradient(gradient: Gradient(colors: [AppBrand.accent2.opacity(0.16), .clear]),
                           center: .bottomTrailing, startRadius: 0, endRadius: 420)
                .blur(radius: 65).offset(x: 120, y: 160)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Tabs
private enum MainTab: String, CaseIterable, Identifiable {
    case exercises, workout, skills, profile
    var id: String { rawValue }
    var title: String {
        switch self {
        case .exercises: return "Exercises"
        case .workout:   return "Workout"
        case .skills:    return "Skill Lists"
        case .profile:   return "Profile"
        }
    }
    var icon: String {
        switch self {
        case .exercises: return "list.bullet"
        case .workout:   return "bolt.fill"
        case .skills:    return "list.bullet.rectangle"
        case .profile:   return "person.crop.circle"
        }
    }
}

// MARK: - Preference to report bar height
private struct BarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

// MARK: - Docked Glass Tab Bar (edge-to-edge, compact height, subtle sheen)
private struct GlassTabBar: View {
    @Binding var selection: MainTab
    @Namespace private var ns

    // sizing / tweaks
    private let selectedIcon: CGFloat = 22
    private let unselectedIcon: CGFloat = 20
    private let contentYOffset: CGFloat = 4     // move items lower within the bar
    private let topAccentLineHeight: CGFloat = 1.5
    private let topAccentOpacity: Double = 0.75

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                let isSelected = (selection == tab)
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                        selection = tab
                    }
                    #if os(iOS)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: isSelected ? selectedIcon : unselectedIcon,
                                          weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white : .primary.opacity(0.78))
                            .scaleEffect(isSelected ? 1.07 : 1.0)

                        Text(tab.title)
                            .font(.caption2.weight(isSelected ? .semibold : .regular))
                            .foregroundStyle(isSelected ? .white.opacity(0.95) : .primary.opacity(0.70))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .offset(y: contentYOffset)           // nudge content lower inside bar
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)               // compact bar
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppBrand.accentGradient)
                                    .matchedGeometryEffect(id: "tab-pill", in: ns)
                                    .shadow(color: AppBrand.accent2.opacity(0.35), radius: 10, y: 3)
                                    .padding(.horizontal, 8)
                                    .offset(y: contentYOffset) // keep pill aligned with content
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 6)
        .padding(.bottom, 6)                // sits on safe-area bottom
        .background(
            // Full-width glass, top corners only so it docks
            UnevenRoundedRectangle(
                cornerRadii: .init(
                    topLeading: 18,
                    bottomLeading: 0,
                    bottomTrailing: 0,
                    topTrailing: 18
                ),
                style: .continuous
            )
            .fill(.ultraThinMaterial)
            .overlay(
                UnevenRoundedRectangle(
                    cornerRadii: .init(
                        topLeading: 18,
                        bottomLeading: 0,
                        bottomTrailing: 0,
                        topTrailing: 18
                    ),
                    style: .continuous
                )
                .stroke(AppBrand.stroke, lineWidth: 1)
            )
            // vertical sheen
            .overlay(
                LinearGradient(colors: [Color.white.opacity(0.14), .clear],
                               startPoint: .top, endPoint: .bottom)
            )
            // side vignette
            .overlay(
                LinearGradient(colors: [Color.black.opacity(0.05), .clear, Color.black.opacity(0.05)],
                               startPoint: .leading, endPoint: .trailing)
            )
            // **top blue accent line**
            .overlay(alignment: .top) {
                AppBrand.accentGradient
                    .frame(height: topAccentLineHeight)
                    .opacity(topAccentOpacity)
            }
            .ignoresSafeArea(edges: .bottom)
        )
        // publish actual height so ContentView can reserve space
        .overlay(
            GeometryReader { proxy in
                Color.clear.preference(key: BarHeightKey.self, value: proxy.size.height)
            }
        )
    }
}


// FLOATING GLASS TAB
// MARK: - Glass Tab Bar (bigger icons + sheen + edge fade)
//private struct GlassTabBar: View {
//    @Binding var selection: MainTab
//    @Namespace private var ns
//
//    // tweakables
//    private let selectedIcon: CGFloat = 22
//    private let unselectedIcon: CGFloat = 19
//    private let pillCorner: CGFloat = 12
//
//    var body: some View {
//        HStack(spacing: 12) {
//            ForEach(MainTab.allCases) { tab in
//                let isSelected = (selection == tab)
//
//                Button {
//                    withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) { selection = tab }
//                    #if os(iOS)
//                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
//                    #endif
//                } label: {
//                    VStack(spacing: 4) {
//                        Image(systemName: tab.icon)
//                            .font(.system(size: isSelected ? selectedIcon : unselectedIcon,
//                                          weight: isSelected ? .semibold : .regular))
//                            .foregroundStyle(isSelected ? .white : .primary.opacity(0.78))
//                            .scaleEffect(isSelected ? 1.07 : 1.0)
//                            .shadow(color: isSelected ? .black.opacity(0.25) : .clear, radius: 6, y: 2)
//
//                        // show label only for selected to keep things clean
//                        if isSelected {
//                            Text(tab.title)
//                                .font(.caption2.weight(.semibold))
//                                .foregroundStyle(.white.opacity(0.95))
//                                .minimumScaleFactor(0.8)
//                                .lineLimit(1)
//                                .transition(.opacity.combined(with: .move(edge: .top)))
//                        }
//                    }
//                    .padding(.horizontal, isSelected ? 14 : 10)
//                    .padding(.vertical, isSelected ? 9 : 6)
//                    .frame(maxWidth: .infinity) // bigger hit target
//                    .background(
//                        ZStack {
//                            if isSelected {
//                                RoundedRectangle(cornerRadius: pillCorner, style: .continuous)
//                                    .fill(AppBrand.accentGradient)
//                                    .matchedGeometryEffect(id: "tab-pill", in: ns)
//                                    .shadow(color: AppBrand.accent2.opacity(0.35), radius: 10, y: 3)
//                            }
//                        }
//                    )
//                    .contentShape(Rectangle())
//                    .accessibilityLabel(tab.title)
//                    .accessibilityAddTraits(isSelected ? .isSelected : [])
//                }
//                .buttonStyle(.plain)
//            }
//        }
//        .padding(.horizontal, 16)
//        .padding(.vertical, 10)
//        .background(
//            // glass base
//            RoundedRectangle(cornerRadius: 20, style: .continuous)
//                .fill(.ultraThinMaterial)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 20, style: .continuous)
//                        .stroke(AppBrand.stroke, lineWidth: 1)
//                )
//                // ---- opacity gradients (subtle) ----
//                // vertical "sheen"
//                .overlay(
//                    LinearGradient(colors: [Color.white.opacity(0.18), .clear],
//                                   startPoint: .top, endPoint: .bottom)
//                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
//                )
//                // horizontal edge vignette
//                .overlay(
//                    LinearGradient(colors: [Color.black.opacity(0.06), .clear, Color.black.opacity(0.06)],
//                                   startPoint: .leading, endPoint: .trailing)
//                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
//                )
//                .shadow(color: .black.opacity(0.08), radius: 12, y: 6)
//        )
//        .padding(.horizontal, 18)
//        .padding(.top, 8)
//    }
//}

// MARK: - ContentView (swanky)
struct ContentView: View {
    @StateObject private var viewModel = WorkoutViewModel()
    @State private var selection: MainTab = .workout   // default landing tab
    @State private var barHeight: CGFloat = 0          // measured tab-bar height

    // tweak if you still need a smidge more space above content
    private let bottomReserveExtra: CGFloat = 1

    var body: some View {
        NavigationStack {                       // top-level nav for titles
            ZStack {
                AppBlobBackground()

                // Main content switches per tab
                Group {
                    switch selection {
                    case .exercises:
                        ExerciseListView(viewModel: viewModel)
                            .navigationTitle("Exercises")
                    case .workout:
                        WorkoutGeneratorView(viewModel: viewModel)
                            .navigationTitle("Generate Workout")
                    case .skills:
                        SkillProgressionsView()
                            .navigationTitle("Skill Lists")
                    case .profile:
                        ProfileTabView()
                            .navigationTitle("Profile")
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            // .toolbarColorScheme(.automatic, for: .navigationBar)
            .toolbarColorScheme(nil, for: .navigationBar)     // follow system (automatic)
            .navigationBarTitleDisplayMode(.inline)
        }
        // Reserve space so content never hides under the docked bar
        .padding(.bottom, barHeight + bottomReserveExtra)
        .onPreferenceChange(BarHeightKey.self) { barHeight = $0 }

        // The docked bar itself
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GlassTabBar(selection: $selection)
        }
    }
}
