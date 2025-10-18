//
//  SkillProgressionsView.swift
//  New Project
//
//  Branded UI to match WorkoutGeneratorView / Exercise* views:
//  - Soft blob background
//  - Carded sections with subtle strokes
//  - Accent gradient headers
//  - Tri-state select (unlock all / partial / none) per progression
//

import SwiftUI


// MARK: - Background (soft blobs)
private struct ProgBlobBackground: View {
    var body: some View {
        ZStack {
            ProgBrandTheme.pageBG.ignoresSafeArea()

            RadialGradient(
                colors: [ProgBrandTheme.accent1.opacity(0.22), .clear],
                center: .topLeading, startRadius: 0, endRadius: 360
            )
            .blur(radius: 50)
            .offset(x: -80, y: -120)

            RadialGradient(
                colors: [ProgBrandTheme.accent2.opacity(0.18), .clear],
                center: .bottomTrailing, startRadius: 0, endRadius: 420
            )
            .blur(radius: 60)
            .offset(x: 100, y: 140)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Interactive Skill Tree (fancy ✨)
// MARK: - Interactive Skill Tree (adaptive + gesture-safe ✨)
private struct SkillTreeView: View {
    @Binding var progressions: [Progression]

    // Visuals / layout
    private let margin: CGFloat = 80
    private let nodeSize: CGFloat = 28
    private let minXSpacing: CGFloat = 120
    private let maxXSpacing: CGFloat = 200
    private let ySpacing: CGFloat = 110

    // Pan & zoom
    @State private var scale: CGFloat = 1.0
    @GestureState private var pinchScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @GestureState private var dragOffset: CGSize = .zero

    // Highlighting
    @State private var highlightedRow: Int? = nil
    @State private var selectedNodeKey: String? = nil

    // Motion/accessibility
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Put these inside SkillTreeView (e.g., above `var body`):

    @ViewBuilder
    private func edgesLayer(xSpacing: CGFloat,
                            contentWidth: CGFloat,
                            contentHeight: CGFloat,
                            highlightedRow: Int?) -> some View {
        Canvas { ctx, _ in
            for row in progressions.indices {
                let color = colorForRow(row)
                let steps = progressions[row].steps
                guard steps.count > 1 else { continue }

                for i in 0..<(steps.count - 1) {
                    let p0 = pos(row: row, col: i, xSpacing: xSpacing)
                    let p1 = pos(row: row, col: i + 1, xSpacing: xSpacing)

                    var path = Path()
                    let c1 = CGPoint(x: p0.x + (xSpacing * 0.45), y: p0.y)
                    let c2 = CGPoint(x: p1.x - (xSpacing * 0.45), y: p1.y)
                    path.move(to: p0)
                    path.addCurve(to: p1, control1: c1, control2: c2)

                    let bothUnlocked = steps[i].isUnlocked && steps[i + 1].isUnlocked
                    let isHL = (highlightedRow == row)

                    let baseOpacity: CGFloat = isHL ? 1.0 : 0.55
                    let unlockedWidth: CGFloat = isHL ? 5.0 : 4.0
                    let lockedWidth: CGFloat = isHL ? 3.0 : 2.0

                    // back glow
                    ctx.stroke(
                        path,
                        with: .color(color.opacity(bothUnlocked ? 0.35 : 0.18)),
                        lineWidth: bothUnlocked ? unlockedWidth * 1.8 : lockedWidth * 1.6
                    )
                    // gradient stroke
                    
                    let grad = Gradient(colors: [
                        color.opacity(bothUnlocked ? baseOpacity : 0.45),
                        ProgBrandTheme.accent2.opacity(bothUnlocked ? baseOpacity : 0.35)
                    ])
                    ctx.stroke(
                        path,
                        with: .linearGradient(grad, startPoint: p0, endPoint: p1),
                        lineWidth: bothUnlocked ? unlockedWidth : lockedWidth
                    )
                    
                    // dotted overlay if locked
                    if !bothUnlocked {
                        ctx.stroke(
                            path,
                            with: .color(color.opacity(0.25)),
                            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, dash: [6, 10])
                        )
                    }
                }
            }
        }
        .frame(width: contentWidth, height: contentHeight)
    }

    @ViewBuilder
    private func nodesLayer(xSpacing: CGFloat,
                            nodeSize: CGFloat,
                            reduceMotion: Bool) -> some View {
        ForEach(progressions.indices, id: \.self) { row in
            let color = colorForRow(row)
            ForEach(progressions[row].steps.indices, id: \.self) { col in
                let key = nodeKey(row: row, col: col)
                let binding = $progressions[row].steps[col]
                let p = pos(row: row, col: col, xSpacing: xSpacing)
                let isHL: Bool = (highlightedRow == row || selectedNodeKey == key)
                let title: String = binding.wrappedValue.name

                NodeButton(
                    step: binding,
                    color: color,
                    title: title,
                    isHighlighted: isHL,
                    size: nodeSize,
                    reduceMotion: reduceMotion,
                    longPressAction: {
                        withHapticsProgressions {
                            unlockChain(row: row, through: col)
                            highlightedRow = row
                            selectedNodeKey = key
                        }
                    },
                    action: { // name the trailing closure to help type-checker
                        withHapticsProgressions {
                            binding.wrappedValue.isUnlocked.toggle()
                            highlightedRow = row
                            selectedNodeKey = key
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.3)) { highlightedRow = nil }
                        }
                    }
                )
                .position(p)
            }
        }
    }


    var body: some View {
        let rows = progressions.count
        let cols = max(progressions.map { $0.steps.count }.max() ?? 0, 1)

        VStack(spacing: 8) {
            // Controls
            HStack(spacing: 10) {
                Label("Skill Map", systemImage: "tree")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        scale = min(2.0, scale + 0.1)
                    }
                } label: { Image(systemName: "plus.magnifyingglass") }
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                        scale = max(0.7, scale - 0.1)
                    }
                } label: { Image(systemName: "minus.magnifyingglass") }
                Button {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        scale = 1.0
                        offset = .zero
                        highlightedRow = nil
                        selectedNodeKey = nil
                    }
                } label: { Image(systemName: "arrow.counterclockwise") }
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(ProgBrandTheme.accent1)

            GeometryReader { geo in
                let availableW: CGFloat = max(geo.size.width - margin * 2 - nodeSize, 1)
                let dynamicXSpacing: CGFloat = {
                    let target = availableW / max(CGFloat(cols - 1), 1)
                    return target.clamped(to: minXSpacing...maxXSpacing)
                }()

                let contentWidth: CGFloat  = margin * 2 + CGFloat(max(cols - 1, 0)) * dynamicXSpacing + nodeSize
                let contentHeight: CGFloat = margin * 2 + CGFloat(max(rows - 1, 0)) * ySpacing + nodeSize

                ZStack {
                    edgesLayer(xSpacing: dynamicXSpacing,
                               contentWidth: contentWidth,
                               contentHeight: contentHeight,
                               highlightedRow: highlightedRow)

                    nodesLayer(xSpacing: dynamicXSpacing,
                               nodeSize: nodeSize,
                               reduceMotion: reduceMotion)
                }
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: ProgBrandTheme.cardCorner, style: .continuous)
                        .fill(ProgBrandTheme.cardBG)
                        .overlay(
                            RoundedRectangle(cornerRadius: ProgBrandTheme.cardCorner, style: .continuous)
                                .stroke(ProgBrandTheme.separator.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.05), radius: 6, y: 4)
                )
                .frame(minHeight: 320, maxHeight: 520, alignment: .topLeading)
                .contentShape(Rectangle())
                .scaleEffect(scale * pinchScale, anchor: .topLeading)
                .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                .highPriorityGesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            offset.width += value.translation.width
                            offset.height += value.translation.height
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .updating($pinchScale) { value, state, _ in state = value }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                scale = (scale * value).clamped(to: 0.7...2.0)
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        scale = (scale < 1.1) ? 1.5 : 1.0
                        if scale == 1.0 { offset = .zero }
                    }
                }
            }
            .frame(height: 540)
//            .frame(height: 540) // give GeometryReader breathing room

            // Legend
            HStack(spacing: 12) {
                LegendSwatch(color: ProgBrandTheme.accent1, label: "Unlocked")
                LegendSwatch(color: .secondary, label: "Locked", dashed: true)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func pos(row: Int, col: Int, xSpacing: CGFloat) -> CGPoint {
        CGPoint(
            x: margin + CGFloat(col) * xSpacing,
            y: margin + CGFloat(row) * ySpacing
        )
    }

    private func nodeKey(row: Int, col: Int) -> String { "r\(row)-c\(col)" }

    private func colorForRow(_ row: Int) -> Color {
        let palette: [Color] = [
            ProgBrandTheme.accent1,
            ProgBrandTheme.accent2,
            .purple, .mint, .orange, .pink
        ]
        return palette[row % palette.count]
    }

    private func unlockChain(row: Int, through col: Int) {
        guard progressions.indices.contains(row) else { return }
        for i in 0...col where progressions[row].steps.indices.contains(i) {
            progressions[row].steps[i].isUnlocked = true
        }
    }
}

// MARK: - Node Button (glowy)
// MARK: - Node Button (glowy, accessible)
private struct NodeButton: View {
    @Binding var step: ProgressionStep
    let color: Color
    let title: String
    let isHighlighted: Bool
    let size: CGFloat
    let reduceMotion: Bool
    let longPressAction: (() -> Void)?
    let action: () -> Void

    @State private var spin = false
    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(color.opacity(step.isUnlocked ? 0.9 : 0.35), lineWidth: step.isUnlocked ? 3 : 2)
                    .frame(width: size + 10, height: size + 10)
                    .shadow(color: color.opacity(step.isUnlocked ? 0.6 : 0.25), radius: step.isUnlocked ? 10 : 5)

                // Rotating gradient ring
                Circle()
                    .trim(from: 0.0, to: 0.85)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [color, .white.opacity(0.8), color]),
                            center: .center,
                            angle: .degrees(spin ? 360 : 0)
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: size + 6, height: size + 6)
                    .opacity(isHighlighted ? 1 : 0.6)
                    .animation(reduceMotion || !isHighlighted ? nil
                               : .linear(duration: 3).repeatForever(autoreverses: false),
                               value: spin)

                // Core
                Circle()
                    .fill(step.isUnlocked ? color.opacity(0.9) : color.opacity(0.25))
                    .overlay(
                        Circle()
                            .fill(.white.opacity(step.isUnlocked ? 0.15 : 0.08))
                            .blur(radius: 1.5)
                            .padding(3)
                    )
                    .frame(width: size, height: size)
                    .scaleEffect((!reduceMotion && pulse && step.isUnlocked) ? 1.06 : 1.0)
                    .animation(reduceMotion ? nil
                               : (step.isUnlocked
                                  ? .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                                  : .default),
                               value: pulse)

                // Tiny label dot / info
                if isHighlighted {
                    Text("•")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .offset(y: -size * 0.8)
                        .transition(.opacity)
                }
            }
            .overlay(
                // Tooltip
                Text(title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 1))
                    .offset(y: size * 1.1)
                    .opacity(isHighlighted ? 1 : 0)
                    .allowsHitTesting(false)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.35).onEnded { _ in longPressAction?() }
        )
        .onAppear {
            // kick off animations (guarded by reduceMotion in modifiers)
            spin = true
            pulse = true
        }
        .accessibilityLabel(title)
        .accessibilityHint(step.isUnlocked ? "Unlocked" : "Double tap to unlock")
    }
}


// MARK: - Legend
private struct LegendSwatch: View {
    let color: Color
    let label: String
    var dashed: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(.clear)
                .overlay(
                    Rectangle()
                        .stroke(color.opacity(0.9),
                                style: StrokeStyle(lineWidth: 3, dash: dashed ? [6, 6] : []))
                )
                .frame(width: 26, height: 8)
                .shadow(color: color.opacity(0.3), radius: 2, y: 1)
            Text(label)
        }
    }
}

// MARK: - Clamp helper
private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}


// MARK: - Step Row
private struct StepRow: View {
    @Binding var step: ProgressionStep

    var body: some View {
        Button {
            withHapticsProgressions { step.isUnlocked.toggle() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Image(systemName: step.isUnlocked ? "checkmark.circle.fill" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(step.isUnlocked ? ProgBrandTheme.accent1 : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(step.name)
                        .font(.body)
                        .lineLimit(2)
                    if let note = step.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(step.name)
        .accessibilityHint(step.isUnlocked ? "Marked unlocked" : "Double tap to mark unlocked")
    }
}

// MARK: - Progression Card (tri-state header + collapsible steps)
private struct ProgressionCard: View {
    @Binding var progression: Progression
    @State private var expanded: Bool = true

    var body: some View {
        let total = progression.steps.count
        let unlocked = progression.steps.filter { $0.isUnlocked }.count
        let isAll = total > 0 && unlocked == total
        let isPartial = unlocked > 0 && unlocked < total

        return ProgSectionCard(icon: "list.bullet.circle.fill", title: progression.title) {
            DisclosureGroup(isExpanded: $expanded) {
                VStack(spacing: 8) {
                    ForEach($progression.steps) { $step in
                        StepRow(step: $step)
                        Divider().opacity(0.15)
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 12) {
                    Text("\(unlocked)/\(total)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withHapticsProgressions {
                            if isAll {
                                // Clear all
                                for i in progression.steps.indices {
                                    progression.steps[i].isUnlocked = false
                                }
                            } else {
                                // Unlock all
                                for i in progression.steps.indices {
                                    progression.steps[i].isUnlocked = true
                                }
                            }
                        }
                    } label: {
                        Image(systemName: isAll ? "checkmark.square.fill"
                                      : (isPartial ? "minus.square" : "square"))
                            .imageScale(.large)
                            .foregroundStyle(ProgBrandTheme.accent1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Models
enum SkillCategory: String, CaseIterable, Identifiable, Codable, Hashable {
    case horizontalPull = "Horizontal Pull"
    case verticalPull   = "Vertical Pull"
    case verticalPush   = "Vertical Push"
    case horizontalPush = "Horizontal Push"
    case core           = "Core"
    case legs           = "Legs"
    var id: String { rawValue }
}

struct ProgressionStep: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    var isUnlocked: Bool
    var note: String?

    init(
        id: UUID = UUID(),
        name: String,
        isUnlocked: Bool = false,
        note: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isUnlocked = isUnlocked
        self.note = note
    }
}

struct Progression: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    var steps: [ProgressionStep]

    init(id: UUID = UUID(), title: String, steps: [ProgressionStep]) {
        self.id = id
        self.title = title
        self.steps = steps
    }
}

// MARK: - View
struct SkillProgressionsView: View {

    @State private var selectedCategory: SkillCategory = .horizontalPush
    @State private var progressionsByCategory: [SkillCategory: [Progression]] = [:]

    // track the JSON file export location
    @State private var lastExportURL: URL? = nil

    private let storeKey = "skillProgressions.v1"

    // MARK: Default Progressions (v5.4 Bodyweight Fitness Progressions)
    private var defaultProgressions: [SkillCategory: [Progression]] {
        [
                    // =========================
                    // HORIZONTAL PULL
                    // =========================
                    .horizontalPull: [

                        // SKIN THE CAT
                        Progression(
                            title: "Skin the Cat",
                            steps: [
                                ProgressionStep(name: "German Hang"),
                                ProgressionStep(name: "Tuck Skin the Cat"),
                                ProgressionStep(name: "Advanced Tuck Skin the Cat"),
                                ProgressionStep(name: "Pike Skin the Cat")
                            ]
                        ),

                        // ROWS
                        Progression(
                            title: "Rows",
                            steps: [
                                ProgressionStep(name: "Vertical Row"),
                                ProgressionStep(name: "Incline Row"),
                                ProgressionStep(name: "Row"),
                                ProgressionStep(name: "Wide Row"),
                                ProgressionStep(name: "Archer Row"),
                                ProgressionStep(name: "Archer-In Row"),
                                ProgressionStep(name: "Straddle One Arm Row"),
                                ProgressionStep(name: "One Arm Row"),
                                ProgressionStep(name: "Straight One Arm Row")
                            ]
                        ),

                        // BACK LEVER
                        Progression(
                            title: "Back Lever",
                            steps: [
                                ProgressionStep(name: "Tuck Back Lever"),
                                ProgressionStep(name: "Advanced Tuck Back Lever"),
                                ProgressionStep(name: "One Leg Back Lever"),
                                ProgressionStep(name: "Straddle Back Lever"),
                                ProgressionStep(name: "Back Lever"),
                                ProgressionStep(name: "Back Lever Pullout"),
                                ProgressionStep(name: "German Hang Pullout"),
                                ProgressionStep(name: "Bent Arm Pull Up to Back Lever"),
                                ProgressionStep(name: "Handstand Lower to Back Lever")
                            ]
                        ),

                        // FRONT LEVER
                        Progression(
                            title: "Front Lever",
                            steps: [
                                ProgressionStep(name: "L Hang"),
                                ProgressionStep(name: "Tuck Front Lever"),
                                ProgressionStep(name: "Advanced Tuck Front Lever"),
                                ProgressionStep(name: "One Leg Front Lever"),
                                ProgressionStep(name: "Straddle Front Lever"),
                                ProgressionStep(name: "Front Lever")
                            ]
                        ),

                        // FRONT LEVER ROWS (post Adv Tuck FL)
                        Progression(
                            title: "Front Lever Rows (post Adv Tuck FL)",
                            steps: [
                                ProgressionStep(name: "Tuck Ice Cream Maker"),
                                ProgressionStep(name: "Tuck Front Lever Row"),
                                ProgressionStep(name: "Advanced Tuck Front Lever Row"),
                                ProgressionStep(name: "Straddle Front Lever Row"),
                                ProgressionStep(name: "Front Lever Row")
                            ]
                        ),

                        // FRONT LEVER TRANSITIONS
                        Progression(
                            title: "Front Lever – Transitions",
                            steps: [
                                ProgressionStep(name: "Front Lever to Inverted"),
                                ProgressionStep(name: "Hanging Pull FL to Inverted"),
                                ProgressionStep(name: "360° Pull"),
                                ProgressionStep(name: "Circle Front Lever")
                            ]
                        ),

                        // IRON CROSS
                        Progression(
                            title: "Iron Cross",
                            steps: [
                                ProgressionStep(name: "Iron Cross Progression"),
                                ProgressionStep(name: "Iron Cross"),
                                ProgressionStep(name: "Iron Cross to Back Lever")
                            ]
                        )
                    ],

                    // =========================
                    // VERTICAL PULL
                    // =========================
                    .verticalPull: [

                        // PULL UP
                        Progression(
                            title: "Pull Up",
                            steps: [
                                ProgressionStep(name: "Scapular Pull"),
                                ProgressionStep(name: "Arch Hang"),
                                ProgressionStep(name: "Pull Up Negative"),
                                ProgressionStep(name: "Pull Up")
                            ]
                        ),

                        // ONE ARM PULL UP (post Pull Up)
                        Progression(
                            title: "One Arm Pull Up (post Pull Up)",
                            steps: [
                                ProgressionStep(name: "Ring L‑Sit Pull Up"),
                                ProgressionStep(name: "Ring Wide Pull Up"),
                                ProgressionStep(name: "Ring Wide L‑Pull Up"),
                                ProgressionStep(name: "Typewriter Pull Up"),
                                ProgressionStep(name: "Archer Pull Up"),
                                ProgressionStep(name: "One Arm Pull Up Negative"),
                                ProgressionStep(name: "One Arm Pull Up"),
                                ProgressionStep(name: "High One Arm Pull Up")
                            ]
                        ),

                        // PULLOVER
                        Progression(
                            title: "Pullover",
                            steps: [
                                ProgressionStep(name: "L‑Sit Pull Up"),
                                ProgressionStep(name: "Pullover", note: "Recommended post 'Kipping Muscle Up'")
                            ]
                        ),

                        // MUSCLE UP (post Pull Up)
                        Progression(
                            title: "Muscle Up (post Pull Up)",
                            steps: [
                                ProgressionStep(name: "Chest to Bar Pull Up"),
                                ProgressionStep(name: "Muscle Up Negative"),
                                ProgressionStep(name: "Kipping Muscle Up"),
                                ProgressionStep(name: "Muscle Up", note: "Recommended post 'Pullover'"),
                                ProgressionStep(name: "Wide Muscle Up"),
                                ProgressionStep(name: "Strict Bar Muscle Up"),
                                ProgressionStep(name: "L‑Sit Muscle Up"),
                                ProgressionStep(name: "One Arm Straight Muscle Up", note: "Recommended post 'One Arm Pull Up'")
                            ]
                        ),

                        // HUMAN FLAG
                        Progression(
                            title: "Human Flag",
                            steps: [
                                ProgressionStep(name: "Side Plank"),
                                ProgressionStep(name: "Vertical Flag"),
                                ProgressionStep(name: "Advanced Tuck Flag"),
                                ProgressionStep(name: "Straddle Flag"),
                                ProgressionStep(name: "Human Flag")
                            ]
                        )
                    ],

                    // =========================
                    // VERTICAL PUSH
                    // =========================
                    .verticalPush: [

                        // HANDSTAND & HSPU
                        Progression(
                            title: "Handstand / HSPU",
                            steps: [
                                ProgressionStep(name: "Wall Plank"),
                                ProgressionStep(name: "Wall Headstand"),
                                ProgressionStep(name: "Wall Handstand"),
                                ProgressionStep(name: "Handstand"),
                                ProgressionStep(name: "Press Handstand", note: "optional at this stage"),
                                ProgressionStep(name: "Wall HS Push Up Negative"),
                                ProgressionStep(name: "Wall HS Push Up"),
                                ProgressionStep(name: "Headstand Push Up"),
                                ProgressionStep(name: "Handstand Push Up"),
                                ProgressionStep(name: "Ring Handstand Push Up"),
                                ProgressionStep(name: "RTO L‑Sit Handstand Push Up")
                            ]
                        ),

                        // L‑SIT → V‑SIT → MANNA
                        Progression(
                            title: "L‑Sit / V‑Sit / Manna",
                            steps: [
                                ProgressionStep(name: "Foot Supported L‑Sit"),
                                ProgressionStep(name: "One Leg L‑Sit"),
                                ProgressionStep(name: "Tuck L‑Sit"),
                                ProgressionStep(name: "One Leg Bent L‑Sit"),
                                ProgressionStep(name: "L‑Sit"),
                                ProgressionStep(name: "Straddle L‑Sit"),
                                ProgressionStep(name: "Rings Turned Out L‑Sit"),
                                ProgressionStep(name: "45° V‑Sit"),
                                ProgressionStep(name: "75° V‑Sit"),
                                ProgressionStep(name: "90° V‑Sit"),
                                ProgressionStep(name: "120° V‑Sit"),
                                ProgressionStep(name: "140° V‑Sit"),
                                ProgressionStep(name: "155° V‑Sit"),
                                ProgressionStep(name: "170° V‑Sit"),
                                ProgressionStep(name: "Manna")
                            ]
                        ),

                        // SUPPORTS & DIPS (RINGS)
                        Progression(
                            title: "Ring Support & Dips",
                            steps: [
                                ProgressionStep(name: "Support Hold"),
                                ProgressionStep(name: "Ring Support Hold"),
                                ProgressionStep(name: "RTO Support Hold"),
                                ProgressionStep(name: "Ring Dip Negative"),
                                ProgressionStep(name: "Ring Dip"),
                                ProgressionStep(name: "Bulgarian Dip"),
                                ProgressionStep(name: "Ring Wide Dip"),
                                ProgressionStep(name: "RTO 45° Dip"),
                                ProgressionStep(name: "RTO 90° Dip"),
                                ProgressionStep(name: "Ring L‑Sit Dip")
                            ]
                        ),

                        // RING BALANCES
                        Progression(
                            title: "Ring Balances",
                            steps: [
                                ProgressionStep(name: "Ring Shoulder Stand"),
                                ProgressionStep(name: "Ring Handstand")
                            ]
                        ),

                        // BRIDGE / WHEEL
                        Progression(
                            title: "Bridge / Wheel",
                            steps: [
                                ProgressionStep(name: "Shoulder Bridge"),
                                ProgressionStep(name: "Table Bridge"),
                                ProgressionStep(name: "Angled Bridge"),
                                ProgressionStep(name: "Bridge / Wheel"),
                                ProgressionStep(name: "Decline Bridge"),
                                ProgressionStep(name: "One Leg Bridge"),
                                ProgressionStep(name: "Decline One Leg Bridge"),
                                ProgressionStep(name: "OA Head Bridge"),
                                ProgressionStep(name: "One Arm Bridge")
                            ]
                        )
                    ],

                    // =========================
                    // HORIZONTAL PUSH
                    // =========================
                    .horizontalPush: [

                        // Push Up (floor)
                        Progression(
                            title: "Push Up",
                            steps: [
                                ProgressionStep(name: "Incline Push Up"),
                                ProgressionStep(name: "Push Up"),
                                ProgressionStep(name: "Diamond Push Up"),
                                ProgressionStep(name: "Archer Push Up")
                            ]
                        ),

                        // RING Push Up
                        Progression(
                            title: "Ring Push Up",
                            steps: [
                                ProgressionStep(name: "Ring Push Up"),
                                ProgressionStep(name: "Ring Wide Push Up"),
                                ProgressionStep(name: "RTO Push Up"),
                                ProgressionStep(name: "RTO Archer Push Up")
                            ]
                        ),

                        // PSEUDO PLANCHE Push Up
                        Progression(
                            title: "Pseudo Planche Push Up",
                            steps: [
                                ProgressionStep(name: "Pseudo Planche Push Up"),
                                ProgressionStep(name: "Ring Pseudo Planche Push Up"),
                                ProgressionStep(name: "Wall Pseudo Planche Push Up"),
                                ProgressionStep(name: "Ring Wall Pseudo Planche Push Up")
                            ]
                        ),

                        // PLANK → OA PLANK
                        Progression(
                            title: "Plank / One Arm Plank",
                            steps: [
                                ProgressionStep(name: "Plank"),
                                ProgressionStep(name: "One Arm Plank"),
                                ProgressionStep(name: "Straddle One Arm Plank")
                            ]
                        ),
                        
                        // ONE ARM Push Up
                        Progression(
                            title: "One Arm Push Up",
                            steps: [
                                ProgressionStep(name: "Incline One Arm Push Up"),
                                ProgressionStep(name: "Straddle One Arm Push Up"),
                                ProgressionStep(name: "One Arm Push Up")
                            ]
                        ),

                        // FROG / CRANE → ELBOW LEVER
                        Progression(
                            title: "Frog/Crane → Elbow Lever",
                            steps: [
                                ProgressionStep(name: "Frog Stand / Crow Pose"),
                                ProgressionStep(name: "Straight Arm Frog Stand / Crane Pose"),
                                ProgressionStep(name: "Ring Frog Stand"),
                                ProgressionStep(name: "Bent Leg / Straddle Elbow Lever"),
                                ProgressionStep(name: "Elbow Lever"),
                                ProgressionStep(name: "One Arm Straight Elbow Lever"),
                                ProgressionStep(name: "One Arm Elbow Lever")
                            ]
                        ),

                        // PLANche (floor)
                        Progression(
                            title: "Planche Progression",
                            steps: [
                                ProgressionStep(name: "Planche Lean"),
                                ProgressionStep(name: "Tuck Planche"),
                                ProgressionStep(name: "Advanced Tuck Planche"),
                                ProgressionStep(name: "Straddle Planche"),
                                ProgressionStep(name: "Full Planche")
                            ]
                        ),
                        
                        // MALTESE (ring & floor)
                        Progression(
                            title: "Maltese",
                            steps: [
                                ProgressionStep(name: "Ring Wall Maltese Push Up"),
                                ProgressionStep(name: "Wall Maltese Push Up"),
                                ProgressionStep(name: "Ring Maltese Push Up"),
                                ProgressionStep(name: "Maltese")
                            ]
                        ),

                        // PLANche Push UpS
                        Progression(
                            title: "Planche Push Up",
                            steps: [
                                ProgressionStep(name: "Tuck Planche Push Up"),
                                ProgressionStep(name: "Advanced Tuck Planche Push Up"),
                                ProgressionStep(name: "Straddle Planche Push Up"),
                                ProgressionStep(name: "Planche Push Up")
                            ]
                        ),


                        // RING PLANche
                        Progression(
                            title: "Ring Planche",
                            steps: [
                                ProgressionStep(name: "Ring Tuck Planche"),
                                ProgressionStep(name: "Ring Straddle Planche"),
                                ProgressionStep(name: "Ring One Leg Planche"),
                                ProgressionStep(name: "Ring Planche")
                            ]
                        )
                    ],

                    // =========================
                    // CORE
                    // =========================
                    .core: [

                        // HYPEREXTENSIONS / ARCH HOLDS
                        Progression(
                            title: "Posterior Chain (Extensions)",
                            steps: [
                                ProgressionStep(name: "Rev Hyperextension"),
                                ProgressionStep(name: "Hyperextension"),
                                ProgressionStep(name: "Arch Body Hold")
                            ]
                        ),

                        // ANTI-ROTATION (PALLOF)
                        Progression(
                            title: "Anti‑Rotation (Pallof)",
                            steps: [
                                ProgressionStep(name: "Banded Pallof Press"),
                                ProgressionStep(name: "Ring Pallof Press")
                            ]
                        ),

                        // HOLLOW / TUCK-UP / PIKE LIFT
                        Progression(
                            title: "Hollow & Compression",
                            steps: [
                                ProgressionStep(name: "Hollow Hold"),
                                ProgressionStep(name: "Tuck Up Crunch"),
                                ProgressionStep(name: "Seated Pike Leg Lift")
                            ]
                        ),

                        // PLANK VARIATIONS (CORE COLUMN)
                        Progression(
                            title: "Core Planks",
                            steps: [
                                ProgressionStep(name: "OA Plank"),
                                ProgressionStep(name: "OA OL Plank") // one arm / one leg plank
                            ]
                        ),

                        // HANGING LEG RAISES / T2B
                        Progression(
                            title: "HLR / T2B",
                            steps: [
                                ProgressionStep(name: "Hanging Knees to Chest"),
                                ProgressionStep(name: "Hanging Leg Raise / T2B"),
                                ProgressionStep(name: "Ankle Weight HLR / T2B"),
                                ProgressionStep(name: "One Arm HLR / T2B")
                            ]
                        ),

                        // AB WHEEL
                        Progression(
                            title: "Ab Wheel",
                            steps: [
                                ProgressionStep(name: "Knees Ab Wheel"),
                                ProgressionStep(name: "Straight Leg Ab Wheel (Ramp)"),
                                ProgressionStep(name: "Straight Leg Ab Wheel Negative"),
                                ProgressionStep(name: "Straight Leg Ab Wheel"),
                                ProgressionStep(name: "Weighted Ab Wheel"),
                                ProgressionStep(name: "One Arm Ab Wheel")
                            ]
                        ),

                        // RING AB ROLLOUT
                        Progression(
                            title: "Ring Ab Rollout",
                            steps: [
                                ProgressionStep(name: "Ring Ab Rollout")
                            ]
                        ),

                        // DRAGON FLAG
                        Progression(
                            title: "Dragon Flag",
                            steps: [
                                ProgressionStep(name: "Tuck Dragon Flag Negative"),
                                ProgressionStep(name: "Advanced Tuck Dragon Flag"),
                                ProgressionStep(name: "Straddle / One Leg Dragon Flag"),
                                ProgressionStep(name: "Dragon Flag"),
                                ProgressionStep(name: "Ankle Weight Dragon Flag"),
                                ProgressionStep(name: "One Arm Dragon Flag")
                            ]
                        )
                    ],

                    // =========================
                    // LEGS
                    // =========================
                    .legs: [

                        // SQUAT (assisted → full)
                        Progression(
                            title: "Squat",
                            steps: [
                                ProgressionStep(name: "Assisted Squat"),
                                ProgressionStep(name: "Parallel Squat"),
                                ProgressionStep(name: "Full Squat")
                            ]
                        ),

                        // SPLIT SQUAT
                        Progression(
                            title: "Split Squat",
                            steps: [
                                ProgressionStep(name: "Split Squat"),
                                ProgressionStep(name: "Bulgarian Split Squat")
                            ]
                        ),

                        // STEP UPS
                        Progression(
                            title: "Step Up",
                            steps: [
                                ProgressionStep(name: "Step Up"),
                                ProgressionStep(name: "Deep Step Up")
                            ]
                        ),

                        // COSSACK → PISTOL
                        Progression(
                            title: "Pistol Squat",
                            steps: [
                                ProgressionStep(name: "Cossack Squat"),
                                ProgressionStep(name: "Partial Pistol Squat"),
                                ProgressionStep(name: "Assisted Pistol Squat"),
                                ProgressionStep(name: "Pistol Squat"),
                                ProgressionStep(name: "Weighted Pistol Squat"),
                                ProgressionStep(name: "Elevated Friction Pistol Squat")
                            ]
                        ),

                        // SHRIMP SQUAT
                        Progression(
                            title: "Shrimp Squat",
                            steps: [
                                ProgressionStep(name: "Beginner Shrimp Squat"),
                                ProgressionStep(name: "Intermediate Shrimp Squat"),
                                ProgressionStep(name: "Advanced Shrimp Squat"),
                                ProgressionStep(name: "Two Hand Shrimp Squat"),
                                ProgressionStep(name: "Elevated Two Hand Shrimp Squat")
                            ]
                        ),

                        // NORDIC CURL
                        Progression(
                            title: "Nordic Curl",
                            steps: [
                                ProgressionStep(name: "Nordic Curl Negative"),
                                ProgressionStep(name: "Nordic Curl"),
                                ProgressionStep(name: "Nordic Curl (Arms Overhead)"),
                                ProgressionStep(name: "One Leg Nordic Curl")
                            ]
                        ),

                        // HINGE / BALANCE
                        Progression(
                            title: "Single‑Leg Hinge",
                            steps: [
                                ProgressionStep(name: "One Leg Deadlift (OL Deadlift)")
                            ]
                        )
                    ]
                ]
            }


    // Derived counts for header summary
    private var currentProgressions: [Progression] {
        progressionsByCategory[selectedCategory, default: []]
    }
    private var currentCounts: (unlocked: Int, total: Int) {
        let allSteps = currentProgressions.flatMap { $0.steps }
        let unlocked = allSteps.filter { $0.isUnlocked }.count
        return (unlocked, allSteps.count)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ProgBlobBackground()

                ScrollView {
                    VStack(spacing: ProgBrandTheme.spacing) {

                        // Header summary
                        ProgSectionCard(icon: "figure.gymnastics", title: "Progression Tracker") {
                            HStack {
                                Text(selectedCategory.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                let (u, t) = currentCounts
                                Text("\(u) / \(t) unlocked")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 4)

                        // Category picker
                        ProgSectionCard(icon: "square.grid.2x2", title: "Category") {
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(SkillCategory.allCases) { cat in
                                    Text(cat.rawValue).tag(cat)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Tools / Export
                        // USEFUL FOR TESTING JSON EXPORTS !!!!!!
//                        ProgSectionCard(icon: "wrench.and.screwdriver.fill", title: "Tools") {
//                            HStack(spacing: 10) {
//                                Button("Copy Unlocked JSON") { copyUnlockedToClipboard() }
//                                Button("Print JSON") { printUnlockedToConsole() }
//                                Button("Save JSON to File") {
//                                    lastExportURL = writeUnlockedJSONToFile()
//                                }
//                            }
//                            .buttonStyle(.borderedProminent)
//                            .tint(ProgBrandTheme.accent1)
//
//                            if let url = lastExportURL {
//                                Divider().opacity(0.15)
//                                Text("Saved to: \(url.lastPathComponent)")
//                                    .font(.caption)
//                                    .foregroundStyle(.secondary)
//                            }
//                        }
                        
//                         Interactive tree for selected category
//                        ProgSectionCard(icon: "tree", title: "Interactive Tree") {
//                            SkillTreeView(progressions: progressionsBinding(for: selectedCategory))
//                        }
////                         Interactive tree for selected category
//                        ProgSectionCard(icon: "tree", title: "Interactive Tree") {
//                            SkillTreeView(progressions: progressionsBinding(for: selectedCategory))
//                                .id(selectedCategory) // reset zoom/pan when switching category
//                        }


                        // Progressions for selected category
                        if currentProgressions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "rectangle.and.text.magnifyingglass")
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundStyle(ProgBrandTheme.accent1)
                                Text("No progressions yet")
                                    .font(.headline)
                                Text("Add a list of steps for \(selectedCategory.rawValue).")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: ProgBrandTheme.cardCorner, style: .continuous)
                                    .fill(ProgBrandTheme.cardBG)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ProgBrandTheme.cardCorner, style: .continuous)
                                            .stroke(ProgBrandTheme.separator.opacity(0.35), lineWidth: 1)
                                    )
                            )
                        } else {
                            VStack(spacing: ProgBrandTheme.spacing) {
                                ForEach(progressionsBinding(for: selectedCategory)) { $prog in
                                    ProgressionCard(progression: $prog)
                                }
                            }
                        }

                        Spacer(minLength: 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .navigationTitle("Skill Progressions")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear { loadProgressions() }
        .onChange(of: progressionsByCategory) { _ in saveProgressions() }
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: selectedCategory)
        .animation(.spring(response: 0.28, dampingFraction: 0.92), value: progressionsByCategory)
    }

    private func progressionsBinding(for category: SkillCategory) -> Binding<[Progression]> {
        Binding(
            get: { progressionsByCategory[category] ?? [] },
            set: { progressionsByCategory[category] = $0 }
        )
    }

    // MARK: - Persistence
    private func loadProgressions() {
        guard let data = UserDefaults.standard.data(forKey: storeKey) else {
            progressionsByCategory = defaultProgressions
            return
        }
        do {
            let saved = try JSONDecoder().decode([String: [Progression]].self, from: data)
            var restored: [SkillCategory: [Progression]] = [:]
            for (key, progs) in saved {
                if let cat = SkillCategory(rawValue: key) {
                    restored[cat] = progs
                }
            }
            progressionsByCategory = merge(template: defaultProgressions, with: restored)
        } catch {
            progressionsByCategory = defaultProgressions
        }
    }

    private func saveProgressions() {
        let toSave = Dictionary(uniqueKeysWithValues:
            progressionsByCategory.map { ($0.key.rawValue, $0.value) }
        )
        if let data = try? JSONEncoder().encode(toSave) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func merge(template: [SkillCategory: [Progression]],
                       with saved: [SkillCategory: [Progression]]) -> [SkillCategory: [Progression]] {
        var result = template
        for (cat, defaults) in template {
            let savedProgs = saved[cat] ?? []
            var merged: [Progression] = []
            for defProg in defaults {
                if let savedProg = savedProgs.first(where: { $0.title == defProg.title }) {
                    var mergedSteps: [ProgressionStep] = []
                    for step in defProg.steps {
                        if let savedStep = savedProg.steps.first(where: { $0.name == step.name }) {
                            mergedSteps.append(savedStep)
                        } else {
                            mergedSteps.append(step)
                        }
                    }
                    merged.append(Progression(title: defProg.title, steps: mergedSteps))
                } else {
                    merged.append(defProg)
                }
            }
            for extra in savedProgs where !defaults.contains(where: { $0.title == extra.title }) {
                merged.append(extra)
            }
            result[cat] = merged
        }
        for (cat, progs) in saved where result[cat] == nil {
            result[cat] = progs
        }
        return result
    }
}

// MARK: - Export helpers
extension SkillProgressionsView {
    func makeUnlockedSkillsJSON() -> String {
        let merged = progressionsByCategory.isEmpty ? defaultProgressions : progressionsByCategory
        let names = merged.values
            .flatMap { $0 }
            .flatMap { $0.steps }
            .filter { $0.isUnlocked }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .sorted()

        let payload: [String: Any] = ["unlockedSkillNames": names]
        let data = try! JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        return String(data: data, encoding: .utf8)!
    }

    func copyUnlockedToClipboard() {
        UIPasteboard.general.string = makeUnlockedSkillsJSON()
        print("✅ Copied unlocked skills JSON to clipboard.")
    }

    func printUnlockedToConsole() {
        let s = makeUnlockedSkillsJSON()
        print("==== UNLOCKED START ====\n\(s)\n==== UNLOCKED END ====")
    }

    func writeUnlockedJSONToFile(filename: String = "unlocked_skills.json") -> URL? {
        let json = makeUnlockedSkillsJSON()
        guard let data = json.data(using: .utf8) else { return nil }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            print("✅ Wrote unlocked skills to:", url.path)
            return url
        } catch {
            print("❌ Write failed:", error)
            return nil
        }
    }

    // Optional: POST unlocked skills to a local server
    func postUnlockedToLocalhost() {
        let json = makeUnlockedSkillsJSON().data(using: .utf8)!
        var req = URLRequest(url: URL(string: "http://127.0.0.1:8765/")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        Task {
            do { _ = try await URLSession.shared.upload(for: req, from: json)
                 print("✅ Posted to localhost, saved as ./data/unlocked_skills.json")
            } catch { print("❌ Post failed:", error) }
        }
    }

    struct WorkoutRequest: Codable {
        let minutes: Int
        let band: String
        let focus: [String]
        let equipment: [String]
        let unlocked: [String: [String]]

        init(minutes: Int, band: String, focus: [String], equipment: [String], unlockedNames: [String]) {
            self.minutes = minutes
            self.band = band
            self.focus = focus
            self.equipment = equipment
            self.unlocked = ["unlockedSkillNames": unlockedNames]
        }
    }

    func postUnlockedToPythonAPI(
        minutes: Int = 40,
        band: String = "intermediate",
        focus: [String] = ["anterior deltoid","triceps","lats"],
        equipment: [String] = ["floor","bar"],
        baseURL: String = "http://127.0.0.1:8765/workout"
    ) async throws -> String {
        let merged = progressionsByCategory.isEmpty ? defaultProgressions : progressionsByCategory
        let unlockedNames = merged.values
            .flatMap { $0 }
            .flatMap { $0.steps }
            .filter { $0.isUnlocked }
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }

        let reqBody = WorkoutRequest(
            minutes: minutes, band: band, focus: focus, equipment: equipment, unlockedNames: unlockedNames
        )
        let data = try JSONEncoder().encode(reqBody)

        var req = URLRequest(url: URL(string: baseURL)!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        let (respData, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let text = String(data: respData, encoding: .utf8) ?? ""
            throw NSError(domain: "WorkoutAPI", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Bad status: \( (resp as? HTTPURLResponse)?.statusCode ?? -1) \(text)"])
        }
        return String(data: respData, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Haptics
@MainActor
private func withHapticsProgressions(_ perform: () -> Void) {
    perform()
    #if os(iOS)
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    #endif
}
