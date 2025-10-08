#
#//  app.py
#//  New Project
#//
#//  Created by Celeste van Dokkum on 10/8/25.
#//

from typing import List, Dict, Optional, Tuple
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import json, os

# ---------- Models that match YOUR JSON ----------
class Muscles(BaseModel):
    primary: List[str] = []
    secondary: List[str] = []
    tertiary: List[str] = []

class Exercise(BaseModel):
    name: str
    description: str
    difficulty: int
    muscles: Muscles
    reps: Optional[str] = None      # e.g., "Planche – 5s / 10s / 15s"
    requiredSkills: List[str] = []

# ---------- Request/Response ----------
class PlanRequest(BaseModel):
    target_muscles: List[str] = Field(..., description="Muscles the user selected")
    number_of_exercises: int = 6
    min_difficulty: int = 1
    max_difficulty: int = 10
    user_skills: List[str] = []            # skills the user already has
    gate_by_skills: bool = False           # if True, filter out exercises whose requiredSkills ⊄ user_skills

class PlanExercise(BaseModel):
    name: str
    description: str
    difficulty: int
    reps: Optional[str] = None

class PlanResponse(BaseModel):
    plan: List[PlanExercise]
    focus_scores: Dict[str, int]
    notes: List[str] = []

# ---------- Load your dataset ----------
with open("exercises.json", "r") as f:
    RAW = json.load(f)
EXERCISES: List[Exercise] = [Exercise(**e) for e in RAW]

# ---------- Helpers ----------
def canon(s: str) -> str:
    return s.strip().lower()

def compatibility_score(ex: Exercise, targets: set[str]) -> int:
    # primary=3, secondary=2, tertiary=1
    s = 0
    s += 3 * len({canon(m) for m in ex.muscles.primary}   & targets)
    s += 2 * len({canon(m) for m in ex.muscles.secondary} & targets)
    s += 1 * len({canon(m) for m in ex.muscles.tertiary}  & targets)
    return s

def make_focus_scores(plan: List[Exercise], targets: set[str]) -> Dict[str,int]:
    scores: Dict[str,int] = {}
    for ex in plan:
        for m in ex.muscles.primary:
            if canon(m) in targets: scores[m] = scores.get(m,0)+3
        for m in ex.muscles.secondary:
            if canon(m) in targets: scores[m] = scores.get(m,0)+2
        for m in ex.muscles.tertiary:
            if canon(m) in targets: scores[m] = scores.get(m,0)+1
    # sort: score desc, then muscle name
    return dict(sorted(scores.items(), key=lambda kv: (-kv[1], kv[0])))

def diversify(candidates: List[Tuple[Exercise,int]], k: int) -> List[Exercise]:
    """
    Simple diversity rule: don't over-pick the same first-listed muscle group.
    You can make this smarter later.
    """
    chosen: List[Exercise] = []
    counts: Dict[str,int] = {}
    for ex, _ in candidates:
        if len(chosen) >= k: break
        all_m = ex.muscles.primary + ex.muscles.secondary + ex.muscles.tertiary
        key = canon(all_m[0]) if all_m else ex.name
        if counts.get(key, 0) >= 2:
            continue
        chosen.append(ex)
        counts[key] = counts.get(key, 0) + 1
    return chosen

# ---------- API ----------
app = FastAPI(title="Workout AI Planner (JSON → plan)")

@app.post("/plan", response_model=PlanResponse)
def plan(req: PlanRequest):
    if not req.target_muscles:
        raise HTTPException(status_code=400, detail="target_muscles cannot be empty")

    targets = {canon(m) for m in req.target_muscles}
    user_skills = {canon(s) for s in req.user_skills}

    # Filter by difficulty and skills if requested
    filtered: List[Exercise] = []
    for ex in EXERCISES:
        if not (req.min_difficulty <= ex.difficulty <= req.max_difficulty):
            continue
        if req.gate_by_skills:
            # require all needed skills to be present
            required = {canon(s) for s in ex.requiredSkills}
            if not required.issubset(user_skills):
                continue
        filtered.append(ex)

    # Score by muscle match
    scored = []
    for ex in filtered:
        s = compatibility_score(ex, targets)
        if s > 0:
            scored.append((ex, s))
    if not scored:
        raise HTTPException(status_code=404, detail="No matching exercises for these muscles.")

    # Sort by score desc, then (optionally) difficulty, then name
    scored.sort(key=lambda t: (t[1], -t[0].difficulty, t[0].name.lower()), reverse=True)

    # Pick top-k with a bit of diversity
    chosen = diversify(scored, k=req.number_of_exercises)

    plan_items = [
        PlanExercise(
            name=ex.name,
            description=ex.description,
            difficulty=ex.difficulty,
            reps=ex.reps
        )
        for ex in chosen
    ]

    notes = ["Warm up 5–10 min", "Rest 60–90 s between sets", "Cool down & stretch"]
    return PlanResponse(
        plan=plan_items,
        focus_scores=make_focus_scores(chosen, targets),
        notes=notes
    )
