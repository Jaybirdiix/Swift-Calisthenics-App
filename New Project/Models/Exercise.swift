//
//  Exercise.swift
//  New Project
//
//  Created by Celeste van Dokkum on 8/6/25.
//

import Foundation

struct Exercise: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
//    let skills: [String] // skills this exercise builds towards, not sure if i'm using this
    let difficulty: Int
    let muscles: Muscles
    let reps: String?  // ✅ NEW
    let requiredSkills: [String]


    struct Muscles: Codable {
        let primary: [String]
        let secondary: [String]
        let tertiary: [String]
    }

    enum CodingKeys: String, CodingKey {
        case name, description, difficulty, muscles, reps, requiredSkills
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
//        skills = try container.decode([String].self, forKey: .skills)
        difficulty = try container.decode(Int.self, forKey: .difficulty)
        muscles = try container.decode(Muscles.self, forKey: .muscles)
        reps = try container.decodeIfPresent(String.self, forKey: .reps) // ✅ Optional if not present
        requiredSkills = try container.decode([String].self, forKey: .requiredSkills)
        id = UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(description, forKey: .description)
//        try container.encode(skills, forKey: .skills)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(muscles, forKey: .muscles)
        try container.encodeIfPresent(reps, forKey: .reps) // ✅ Optional encode
        try container.encode(requiredSkills, forKey: .requiredSkills)
    }
}



enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    var id: String { self.rawValue }
    case chest, back, core, arms, legs, shoulders
}

enum Skill: String, CaseIterable, Identifiable {
    // Advanced / Static / Dynamic Skills
    case oneArmElbowLever = "One-Arm Elbow Lever"
    case elbowLever = "Elbow Lever"
//    case planche = "Planche"
//    case tuckPlanche = "Tuck Planche"
//    case advancedTuckPlanche = "Adv. Tuck Planche"
//    case straddlePlanche = "Straddle Planche"
    case fullPlanche = "Planche"

    case humanFlag = "Human Flag"
//    case lowFlag = "Low Flag"
//    case highFlag = "High Flag"
//    case straddleFlag = "Straddle Flag"
//    case fullFlag = "Full Flag"

    case frontLever = "Front Lever"
    case backLever = "Back Lever"
    case dragonFlag = "Dragon Flag"

    case handstand = "Handstand"
    case pressHandstand = "Press Handstand"
//    case trxHandstand = "TRX Handstand"

    case mana = "Manna"
//    case vSit = "V-Sit"
//    case extremeVSit = "Extreme V-Sit"

    // Basic Skills
    case lSit = "L-Sit"
    case skinTheCat = "Skin the Cat"
    
    case oneArmHang = "One Arm-Hang"
//    case pushUps = "Push-up"
//    case archerPushUp = "Archer Push-up"

    var id: String { self.rawValue }
}


enum DifficultyLevel: String, Codable {
    case beginner, intermediate, advanced
}
