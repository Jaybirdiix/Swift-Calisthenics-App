import json

# === Load your existing exercises.json ===
with open("exercises.json", "r") as f:
    data = json.load(f)

# === Flattened list of all progression skill names ===
progression_skills = {
    "German Hang", "Tuck Skin the Cat", "Advanced Tuck Skin the Cat", "Pike Skin the Cat",
    "Vertical Row", "Incline Row", "Row", "Wide Row", "Archer Row", "Archer-In Row",
    "Straddle One Arm Row", "One Arm Row", "Straight One Arm Row",
    "Tuck Back Lever", "Advanced Tuck Back Lever", "One Leg Back Lever", "Straddle Back Lever",
    "Back Lever", "Back Lever Pullout", "German Hang Pullout", "Bent Arm Pull Up to Back Lever",
    "Handstand Lower to Back Lever", "L Hang", "Tuck Front Lever", "Advanced Tuck Front Lever",
    "One Leg Front Lever", "Straddle Front Lever", "Front Lever",
    "Tuck Ice Cream Maker", "Tuck Front Lever Row", "Advanced Tuck Front Lever Row",
    "Straddle Front Lever Row", "Front Lever Row", "Front Lever to Inverted",
    "Hanging Pull FL to Inverted", "360° Pull", "Circle Front Lever",
    "Iron Cross Progression", "Iron Cross", "Iron Cross to Back Lever",
    "Scapular Pull", "Arch Hang", "Pull Up Negative", "Pull Up", "Ring L‑Sit Pull Up",
    "Ring Wide Pull Up", "Ring Wide L‑Pull Up", "Typewriter Pull Up", "Archer Pull Up",
    "One Arm Pull Up Negative", "One Arm Pull Up", "High One Arm Pull Up",
    "L‑Sit Pull Up", "Pullover", "Chest to Bar Pull Up", "Muscle Up Negative",
    "Kipping Muscle Up", "Muscle Up", "Wide Muscle Up", "Strict Bar Muscle Up",
    "L‑Sit Muscle Up", "One Arm Straight Muscle Up", "Side Plank", "Vertical Flag",
    "Advanced Tuck Flag", "Straddle Flag", "Human Flag", "Wall Plank", "Wall Headstand",
    "Wall Handstand", "Handstand", "Wall HS Push Up Negative", "Wall HS Push Up",
    "Headstand Push Up", "Handstand Push Up", "Ring Handstand Push Up",
    "RTO L‑Sit Handstand Push Up", "Foot Supported L‑Sit", "One Leg L‑Sit",
    "Tuck L‑Sit", "One Leg Bent L‑Sit", "L‑Sit", "Straddle L‑Sit",
    "Rings Turned Out L‑Sit", "45° V‑Sit", "75° V‑Sit", "90° V‑Sit", "120° V‑Sit",
    "140° V‑Sit", "155° V‑Sit", "170° V‑Sit", "Manna", "Support Hold", "Ring Support Hold",
    "RTO Support Hold", "Ring Dip Negative", "Ring Dip", "Bulgarian Dip", "Ring Wide Dip",
    "RTO 45° Dip", "RTO 90° Dip", "Ring L‑Sit Dip", "Ring Shoulder Stand", "Ring Handstand",
    "Shoulder Bridge", "Table Bridge", "Angled Bridge", "Bridge / Wheel", "Decline Bridge",
    "One Leg Bridge", "Decline One Leg Bridge", "OA Head Bridge", "One Arm Bridge",
    "Incline Push Up", "Push Up", "Diamond Push Up", "Archer Push Up", "Ring Push Up",
    "Ring Wide Push Up", "RTO Push Up", "RTO Archer Push Up", "PP Push Up",
    "Ring PP Push Up", "Wall PP Push Up", "Ring Wall PP Push Up", "Plank",
    "One Arm Plank", "Straddle One Arm Plank", "Incline One Arm Push Up",
    "Straddle One Arm Push Up", "One Arm Push Up", "Frog Stand / Crow Pose",
    "Straight Arm Frog Stand / Crane Pose", "Ring Frog Stand", "Bent Leg / Straddle Elbow Lever",
    "Elbow Lever", "One Arm Straight Elbow Lever", "One Arm Elbow Lever",
    "Planche Lean", "Tuck Planche", "Advanced Tuck Planche", "Straddle Planche",
    "Full Planche", "Ring Wall Maltese Push Up", "Wall Maltese Push Up",
    "Ring Maltese Push Up", "Maltese", "Tuck Planche Push Up",
    "Advanced Tuck Planche Push Up", "Straddle Planche Push Up", "Planche Push Up",
    "Ring Tuck Planche", "Ring Straddle Planche", "Ring One Leg Planche", "Ring Planche",
    "Rev Hyperextension", "Hyperextension", "Arch Body Hold", "Banded Pallof Press",
    "Ring Pallof Press", "Hollow Hold", "Tuck Up Crunch", "Seated Pike Leg Lift",
    "OA Plank", "OA OL Plank", "Hanging Knees to Chest", "Hanging Leg Raise / T2B",
    "Ankle Weight HLR / T2B", "One Arm HLR / T2B", "Knees Ab Wheel",
    "Straight Leg Ab Wheel (Ramp)", "Straight Leg Ab Wheel Negative",
    "Straight Leg Ab Wheel", "Weighted Ab Wheel", "One Arm Ab Wheel",
    "Ring Ab Rollout", "Tuck Dragon Flag Negative", "Advanced Tuck Dragon Flag",
    "Straddle / One Leg Dragon Flag", "Dragon Flag", "Ankle Weight Dragon Flag",
    "One Arm Dragon Flag", "Assisted Squat", "Parallel Squat", "Full Squat",
    "Split Squat", "Bulgarian Split Squat", "Step Up", "Deep Step Up", "Cossack Squat",
    "Partial Pistol Squat", "Assisted Pistol Squat", "Pistol Squat", "Weighted Pistol Squat",
    "Elevated Friction Pistol Squat", "Beginner Shrimp Squat", "Intermediate Shrimp Squat",
    "Advanced Shrimp Squat", "Two Hand Shrimp Squat", "Elevated Two Hand Shrimp Squat",
    "Nordic Curl Negative", "Nordic Curl", "Nordic Curl (Arms Overhead)",
    "One Leg Nordic Curl", "One Leg Deadlift (OL Deadlift)"
}

# === Add requiredSkills to all exercises ===
for ex in data:
    name = ex.get("name", "")
    if name in progression_skills:
        ex["requiredSkills"] = [name]  # self-required
    else:
        ex["requiredSkills"] = []

# === Save updated file ===
with open("exercises_with_required_skills_cleaned.json", "w") as f:
    json.dump(data, f, indent=2)

print("✅ All exercises now have `requiredSkills` (either self or empty).")
