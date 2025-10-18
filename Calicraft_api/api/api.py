# api.py
from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict
import json, os, random

import re

def norm_basic(s: str) -> str:
    return (s or "").strip().lower()

# Minimal alias map – add more as you standardize names
ALIASES = {
    "hollow body hold": "hollow hold",
    "arch body hold": "arch hold",
    "pull-up": "pull up",
    "chin-up": "chin up",
}

def canonical_skill(s: str) -> str:
    t = norm_basic(s)
    # normalize punctuation/hyphens/whitespace
    t = re.sub(r"[^a-z0-9]+", " ", t).strip()
    # alias collapse
    return ALIASES.get(t, t)


# ---- import your deterministic helpers ----
# Make sure the filename below exists next to api.py
from deterministic import (
    rank_candidates, choose_dose, norm
)

app = FastAPI()

# ---- load exercises once ----
EX_PATH = os.path.join(os.path.dirname(__file__), "/Users/celestevandokkum/prog_projects/Calicraft/Swift App/New Project/Data/exercises.json")
with open(EX_PATH, "r", encoding="utf-8") as f:
    EXERCISES = json.load(f)

# ---- Swift DTO mirrors ----
class PlanRequestDTO(BaseModel):
    target_muscles: List[str]
    number_of_exercises: int
    min_difficulty: int
    max_difficulty: int
    user_skills: List[str]
    gate_by_skills: bool
    use_llm: bool = False
    goal: str | None = None
    session_minutes: int | None = None

class PlanExerciseDTO(BaseModel):
    name: str
    description: str = ""
    difficulty: int
    reps: str | None = None

class PlanResponseDTO(BaseModel):
    plan: List[PlanExerciseDTO]
    focus_scores: Dict[str, int]
    notes: List[str]

# ---- tiny helpers ----
def infer_band(lo: int, hi: int) -> str:
    c = (lo + hi) / 2
    if c <= 3: return "beginner"
    if c <= 6: return "intermediate"
    if c <= 8: return "advanced"
    return "elite"

def overlaps_targets(ex: dict, targets: set[str]) -> bool:
    m = ex.get("muscles", {})
    bag = {norm(x) for x in (m.get("primary", []) + m.get("secondary", []) + m.get("tertiary", []))}
    return not targets.isdisjoint(bag)

def prereqs_ok(ex: dict, unlocked: set[str]) -> bool:
    u = {canonical_skill(x) for x in unlocked}
    req = {canonical_skill(x) for x in ex.get("requiredSkills", [])}
    return req.issubset(u)


@app.post("/plan", response_model=PlanResponseDTO)
def plan(req: PlanRequestDTO):
    targets = {norm(m) for m in req.target_muscles}
    unlocked = {norm(s) for s in req.user_skills}
    band = infer_band(req.min_difficulty, req.max_difficulty)

    # Filter by difficulty, targets, and prerequisites (if gating enabled)
    pool = []
    for ex in EXERCISES:
        d = int(ex.get("difficulty", 5))
        if not (req.min_difficulty <= d <= req.max_difficulty):
            continue
        if targets and not overlaps_targets(ex, targets):
            continue
        if req.gate_by_skills and not prereqs_ok(ex, unlocked):
            continue
        pool.append(ex)

    if not pool:
        return PlanResponseDTO(plan=[], focus_scores={}, notes=["No eligible exercises (filters/prereqs)"])

    # Your ranker needs equipment flags; we’ll allow all since the Swift request doesn’t send equipment.
    equipment_flags: Dict[str, bool] = {}

    # Rank + take top 2N for variety + sample N
    scored = rank_candidates(pool, list(targets), band, equipment_flags, rand=0.2)
    k = min(max(2 * req.number_of_exercises, req.number_of_exercises), len(scored))
    candidates = [e for (e, s) in scored[:k]]
    random.shuffle(candidates)
    chosen = candidates[:req.number_of_exercises]

    # Build flat "plan" list and compute focus scores
    out_plan: List[PlanExerciseDTO] = []
    focus: Dict[str, int] = {}
    for ex in chosen:
        d = int(ex.get("difficulty", 5))
        dose = choose_dose(ex, band, rand=0.2)  # your deterministic dose chooser
        out_plan.append(PlanExerciseDTO(
            name=ex["name"],
            description=ex.get("description", ""),
            difficulty=d,
            reps=dose
        ))
        # tally focus on targets for UI summary
        m = ex.get("muscles", {})
        for x in m.get("primary", []):
            if norm(x) in targets: focus[x] = focus.get(x, 0) + 3
        for x in m.get("secondary", []):
            if norm(x) in targets: focus[x] = focus.get(x, 0) + 2
        for x in m.get("tertiary", []):
            if norm(x) in targets: focus[x] = focus.get(x, 0) + 1

    notes = []
    if req.goal: notes.append(f"Goal: {req.goal}")
    if req.session_minutes: notes.append(f"Planned ~{req.session_minutes} min")

    return PlanResponseDTO(plan=out_plan, focus_scores=focus, notes=notes)


# cd ~/swift_cali_ai/prog_projects/other
# python3 -m venv .venv
# source .venv/bin/activate
# pip install fastapi uvicorn "pydantic>=2,<3"

# simulator
# uvicorn api:app --reload --host 127.0.0.1 --port 8000
# mobile app
# uvicorn api:app --reload --host 10.0.0.147 --port 3001

