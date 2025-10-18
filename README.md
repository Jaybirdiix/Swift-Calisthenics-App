# Calicraft : a Motivational Calisthenics Workout Tracker & Generator (iOS)

This is a (currently in development) Swift app that tracks your calisthenics progress over time and auto‑generates workouts tailored to the equipment you have available, your current abilities, and your goals. 

### Page Demos

#### Exercises
This is an evolving list of bodyweight exercises I've created. The user may search for an exercise and click on it to get a detailed description of how to perform it and which muscle groups the exercise targets.
<video src="readme/exercisesView.mp4" controls autoplay loop muted playsinline width="640"></video>


#### Workout Generation
This is one of the most fleshed out parts of the app! The workout generation is based either on muscle groups the user specifies, or skills the user wants to work towards. The users abilities (taken from the Skill Progressions tab) are used to determine whether or not the user is capable of each exercise in the generation process.
<video src="readme/workoutView.mp4" controls autoplay loop muted playsinline width="640"></video>


#### Skill Progressions
Skill progressions help the user track their progress, along with helping the algorithm determine which exercises the user is capable of. There are six areas to work towards:

**Categories**
* `core`
* `horizontalPush` (push‑ups, planche variants)
* `horizontalPull` (rows)
* `verticalPush` (HS push‑ups, pike presses)
* `verticalPull` (pull‑ups, front lever)
* `legs` (squats, lunges, hinge, nordics)

<video src="readme/Progressions.mp4" controls autoplay loop muted playsinline width="640"></video>

#### Profile
Very much a work in progress. The UI is there, but it's not hooked up to much.
<video src="readme/profile.mp4" controls autoplay loop muted playsinline width="640"></video>


## Tech Stack

* **Language**: Swift 5.9+
* **UI**: SwiftUI (iOS 17+)
* **API**: Python
* **Persistence**: SwiftData


## Project Structure

```
CalisthenicsApp/
├─ App/
│  ├─ CalisthenicsApp.swift
│  ├─ AppConfig.swift
│  └─ DIContainer.swift
├─ Features/
│  ├─ Generator/
│  │  ├─ WorkoutGenerator.swift
│  │  ├─ Heuristics/
│  │  │  ├─ProgressionHeuristic.swift
│  │  │  ├─FatigueHeuristic.swift
│  │  │  └─EquipmentHeuristic.swift
│  ├─ Tracking/
│  │  ├─ SessionRecorderView.swift
│  │  └─ PRService.swift
│  ├─ Skills/
│  │  ├─ SkillTreeView.swift
│  │  └─ SkillGraph.swift
│  └─ Analytics/
│     ├─ DashboardView.swift
│     └─ TrendsService.swift
├─ Models/
│  ├─ Exercise.swift
│  ├─ ExerciseCategory.swift
│  ├─ Session.swift
│  ├─ SetRecord.swift
│  └─ SkillNode.swift
├─ Persistence/
│  ├─ CoreDataStack.swift
│  ├─ SwiftDataStack.swift
│  └─ Migrations/
├─ Resources/
│  ├─ exercises.json
│  └─ seeds/
└─ Tests/
   ├─ GeneratorTests.swift
   └─ SnapshotTests/
```

---

## Workout Generation
Workout Generation is handled with Python using ExpressAPI. I have written an algorithm that generates a workout tailored to the user's abilities and the muscles or skills they wish to target.

*Note:* There were previous iterations in which ai was used to generate workouts. However, on an Intel Mac, getting results was *incredibly* slow to the point where it wasn't feasible.

## Exercises.json excerpt
```json
{
  "name": "Push Up",
  "description": "Standard floor push-up with straight body line, elbows ~45° from torso, and full lockout at top.",
  "difficulty": 3,
  "muscles": {
    "primary": [
      "Pectoralis Major",
      "Anterior Deltoid",
      "Triceps Brachii"
    ],
    "secondary": [
      "Serratus Anterior",
      "Rectus Abdominis",
      "Obliques"
    ],
    "tertiary": [
      "Forearm Flexors",
      "Forearm Extensors"
    ]
  },
  "reps": "10 / 15 / 20",
  "requiredSkills": []
}
```

---

### Running the App
I run Calicraft with Xcode from the `Swift App` directory. In a separate terminal, I run this command on the simulator:
```shell
uvicorn api:app --reload --host 127.0.0.1 --port 8000
```
Or this one to send the app to my phone:
```shell
uvicorn api:app --reload --host 10.0.0.147 --port 3001
```

## Currently in Progress

Essentials right now
- Improve workout generation / make it a little smarter
- Interactive workout mode (mark as complete)
  - Click the number of reps you were able to complete

Harder
- Swapping out exercises for a choice of similar ones
- Rating exercises to make favorites come up more often
- Click on exercises to pull up the description page
- I’m injured button: avoid particular muscle groups
- Suggest exercises using available equipment
  - **Equipment**: `rings`, `bar`, `parallettes`, `floor`, `bands`
- Adding options to save and edit workouts
  - Statistics over time
- Linking this to the profile page

Optional:
- Calendar of workouts
- Ongoing quests / achievements
- Long terms analytics
- Level bars for each skill
- Resources on good form for each exercise / skill
