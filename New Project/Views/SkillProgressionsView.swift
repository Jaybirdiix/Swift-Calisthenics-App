//
//  SkillProgressionsView.swift
//  New Project
//
//  Created by Celeste van Dokkum on 8/24/25.
//

import SwiftUI

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
    var note: String?   // 👈 Add this

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

//// MARK: - View
//struct SkillProgressionsView: View {
//    @State private var selectedCategory: SkillCategory = .horizontalPush
//    @State private var progressionsByCategory: [SkillCategory: [Progression]] = [:]
//
//    private let storeKey = "skillProgressions.v1"
//
//    private var defaultProgressions: [SkillCategory: [Progression]] {
//        [
//            // HORIZONTAL PULL
//            .horizontalPull: [
//                
//                // SKIN THE CAT
//                Progression(
//                    title: "Skin the Cat",
//                    steps: [
//                        ProgressionStep(name: "German Hang"),
//                        ProgressionStep(name: "Tuck Skin the Cat"),
//                        ProgressionStep(name: "Advanced Tuck Skin the Cat"),
//                        ProgressionStep(name: "Pike Skin the Cat")
//                    ]
//                ),
//                
//                Progression(
//                    title: "Rows",
//                    steps: [
//                        ProgressionStep(name: "Vertical Row"),
//                        ProgressionStep(name: "Incline Row"),
//                        ProgressionStep(name: "Row"),
//                        ProgressionStep(name: "Wide Row"),
//                        ProgressionStep(name: "Archer Row"),
//                        ProgressionStep(name: "Archer-In Row"),
//                        ProgressionStep(name: "Straddle One Arm Row"),
//                        ProgressionStep(name: "One Arm Row"),
//                    ]
//                ),
//                
//                // BACK LEVER
//                Progression(
//                    title: "Back Lever",
//                    steps: [
//                        ProgressionStep(name: "Tuck Back Lever"),
//                        ProgressionStep(name: "Advanced Tuck Back Lever"),
//                        ProgressionStep(name: "One Leg Back Lever"),
//                        ProgressionStep(name: "Straddle Back Lever"),
//                        ProgressionStep(name: "Back Lever"),
//                        ProgressionStep(name: "Back Lever Pullout"),
//                        ProgressionStep(name: "German Hang Pullout"),
//                        ProgressionStep(name: "Bent Arm Pull Up to Back Lever"),
//                        ProgressionStep(name: "Handstand Lower to Back Lever")
//                        
//                    ]
//                ),
//                
//                // FRONT LEVER
//                Progression(
//                    title: "Front Lever",
//                    steps: [
//                        ProgressionStep(name: "L Hang"),
//                        ProgressionStep(name: "Tuck Front Lever"),
//                        ProgressionStep(name: "Advanced Tuck Front Lever"),
//                        ProgressionStep(name: "One Leg Front Lever"),
//                        ProgressionStep(name: "Straddle Front Lever"),
//                        ProgressionStep(name: "Front Lever"),
//                        ProgressionStep(name: "Front Lever to Inverted"),
//                        ProgressionStep(name: "Hanging Pull Front Lever to Inverted"),
//                        ProgressionStep(name: "360 degree Pull")
//                    ]
//                ),
//                Progression(
//                    title: "Front Lever etc (post adv tuck FL)",
//                    steps: [
//                        ProgressionStep(name: "Tuck Ice Cream Maker"),
//                        ProgressionStep(name: "Tuck Front Lever Row"),
//                        ProgressionStep(name: "Advanced Tuck Front Lever Row"),
//                        ProgressionStep(name: "Straddle Front Lever Row"),
//                        ProgressionStep(name: "Front Lever Row")
//                    ]
//                ),
//                
//                // IRON CROSS
//                Progression(
//                    title: "Iron Cross",
//                    steps: [
//                        ProgressionStep(name: "Iron Cross"),
//                        ProgressionStep(name: "Iron Cross to Back Lever")
//                    ]
//                )
//                
//            ],
//            
//            .verticalPull: [
//                // Planche
//                Progression(
//                    title: "Pull Up",
//                    steps: [
//                        ProgressionStep(name: "Scapular Pull"),
//                        ProgressionStep(name: "Arch Hang"),
//                        ProgressionStep(name: "Pull Up Negative"),
//                        ProgressionStep(name: "Pull Up")
//                    ]
//                ),
//                
//                Progression(
//                    title: "One Arm Pull Up (post Pull Up)",
//                    steps: [
//                        ProgressionStep(name: "Ring L-Sit Pull Up"),
//                        ProgressionStep(name: "Ring Wide Pull Up"),
//                        ProgressionStep(name: "Ring Wide L-Pull Up"),
//                        ProgressionStep(name: "Typewriter Pull Up"),
//                        ProgressionStep(name: "Archer Pull Up"),
//                        ProgressionStep(name: "One Arm Pull Up Negative"),
//                        ProgressionStep(name: "One Arm Pull Up"),
//                        ProgressionStep(name: "High One Arm Pull Up")
//                    ]
//                ),
//                
//                Progression(
//                    title: "Pullover",
//                    steps: [
//                        ProgressionStep(name: "L-Sit Pull Up"),
//                        ProgressionStep(name: "Pullover", note: "Recommended post 'Kipping Muscle Up'")
//                    ]
//                ),
//                
//                Progression(
//                    title: "Muscle Up (post Pull Up)",
//                    steps: [
//                        ProgressionStep(name: "Chest to Bar Pull Up"),
//                        ProgressionStep(name: "Muscle Up Negative"),
//                        ProgressionStep(name: "Kipping Muscle Up"),
//                        ProgressionStep(name: "Muscle Up", note: "Recommended post 'Pullover'"),
//                        ProgressionStep(name: "Wide Muscle Up"),
//                        ProgressionStep(name: "Straight Bar Muscle Up"),
//                        ProgressionStep(name: "L-Sit Muscle Up"),
//                        ProgressionStep(name: "One Arm Straight Muscle Up", note: "Recommended post 'One Arm Pull Up'")
//                    ]
//                ),
//                
//                Progression(
//                    title: "Human Flag",
//                    steps: [
//                        ProgressionStep(name: "Side Plank"),
//                        ProgressionStep(name: "Vertical Flag"),
//                        ProgressionStep(name: "Advanced Tuck Flag"),
//                        ProgressionStep(name: "Straddle Flag"),
//                        ProgressionStep(name: "Human Flag")
//                    ]
//                ),
//                
//                
//            ],
//            
//            .horizontalPush: [
//            
//                Progression(
//                    title: "L-Sit / Manna",
//                    steps: [
//                        ProgressionStep(name: "Foot Supported L-Sit"),
//                        ProgressionStep(name: "One Leg L-Sit"),
//                        ProgressionStep(name: "Tuck L-Sit"),
//                        ProgressionStep(name: "One Leg Bent L-Sit"),
//                        ProgressionStep(name: "L-Sit"),
//                        ProgressionStep(name: "Straddle L-Sit"),
//                        ProgressionStep(name: "Rings Turned Out L-Sit"),
//                        ProgressionStep(name: "45 degree V-Sit"),
//                        ProgressionStep(name: "90 degree V-Sit"),
//                        ProgressionStep(name: "120 degree V-Sit"),
//                        ProgressionStep(name: "140 degree V-Sit"),
//                        ProgressionStep(name: "155 degree V-Sit"),
//                        ProgressionStep(name: "170 degree V-Sit"),
//                        ProgressionStep(name: "Manna")
//                    ]
//                )
//            ],
//            
//            .horizontalPush: [
//                // Planche
//                Progression(
//                    title: "Planche Progression",
//                    steps: [
//                        ProgressionStep(name: "Tuck Planche"),
//                        ProgressionStep(name: "Advanced Tuck Planche"),
//                        ProgressionStep(name: "Straddle Planche"),
//                        ProgressionStep(name: "Full Planche")
//                    ]
//                )
//            ]
//            
//            
//            
//        ]
//    }

// MARK: - View
struct SkillProgressionsView: View {
    @State private var selectedCategory: SkillCategory = .horizontalPush
    @State private var progressionsByCategory: [SkillCategory: [Progression]] = [:]

    private let storeKey = "skillProgressions.v1"

    // v5.4 (2019-03-13) Bodyweight Fitness Progressions
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


    var body: some View {
        VStack {
            Picker("Category", selection: $selectedCategory) {
                ForEach(SkillCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if progressionsByCategory[selectedCategory, default: []].isEmpty {
                VStack(spacing: 12) {
                    Text("No progressions yet").font(.headline).foregroundColor(.secondary)
                    Text("Add a list of steps for \(selectedCategory.rawValue).")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .padding(.top, 40)
            } else {
                List {
                    ForEach(progressionsBinding(for: selectedCategory)) { $prog in
                        Section(header: Text(prog.title).font(.headline)) {
                            ForEach($prog.steps) { $step in
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.name)
                                            .font(.body)
                                        if let note = step.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Button {
                                        step.isUnlocked.toggle()
                                    } label: {
                                        Image(systemName: step.isUnlocked ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(step.isUnlocked ? .green : .gray)
                                    }
                                    .buttonStyle(.plain)
                                }

                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Skill Progressions")
        .onAppear { loadProgressions() }
        .onChange(of: progressionsByCategory) { _ in saveProgressions() }
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
