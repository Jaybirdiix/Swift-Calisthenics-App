# app.py
from typing import List, Dict, Optional, Tuple, Set
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import os, json

# Optional OpenAI (for AI selection + reps refinement)
try:
    from openai import OpenAI
    _openai_available = True
except Exception:
    _openai_available = False

MODEL_NAME = os.getenv("OPENAI_MODEL", "gpt-4o-mini")  # change if you want

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
    reps: Optional[str] = None
    requiredSkills: List[str] = []

# ---------- Request/Response ----------
class PlanRequest(BaseModel):
    target_muscles: List[str] = Field(..., description="Muscles the user selected")
    number_of_exercises: int = 6
    min_difficulty: int = 1
    max_difficulty: int = 10
    user_skills: List[str] = []
    gate_by_skills: bool = False
    use_llm: bool = False                  # if true: AI selection + reps
    goal: Optional[str] = None
    session_minutes: Optional[int] = 45

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
HERE = os.path.dirname(os.path.abspath(__file__))
DATA_PATH = os.path.join(HERE, "exercises.json")
with open(DATA_PATH, "r") as f:
    RAW = json.load(f)
EXERCISES: List[Exercise] = [Exercise(**e) for e in RAW]

# ---------- Helpers ----------
def canon(s: str) -> str:
    return s.strip().lower()

def compatibility_score(ex: Exercise, targets: Set[str]) -> int:
    s = 0
    s += 3 * len({canon(m) for m in ex.muscles.primary}   & targets)
    s += 2 * len({canon(m) for m in ex.muscles.secondary} & targets)
    s += 1 * len({canon(m) for m in ex.muscles.tertiary}  & targets)
    return s

def shortlist(filtered: List[Exercise], targets: Set[str], top_k: int = 40) -> List[Exercise]:
    scored = [(ex, compatibility_score(ex, targets)) for ex in filtered]
    scored = [t for t in scored if t[1] > 0]
    scored.sort(key=lambda t: (t[1], t[0].difficulty, t[0].name.lower()), reverse=True)
    return [ex for ex, _ in scored[:top_k]]

def make_focus_scores(plan: List[Exercise], targets: Set[str]) -> Dict[str,int]:
    scores: Dict[str,int] = {}
    for ex in plan:
        for m in ex.muscles.primary:
            if canon(m) in targets: scores[m] = scores.get(m,0)+3
        for m in ex.muscles.secondary:
            if canon(m) in targets: scores[m] = scores.get(m,0)+2
        for m in ex.muscles.tertiary:
            if canon(m) in targets: scores[m] = scores.get(m,0)+1
    return dict(sorted(scores.items(), key=lambda kv: (-kv[1], kv[0])))

def diversify(candidates: List[Exercise], k: int) -> List[Exercise]:
    """
    Heuristic fallback: limit consecutive repeats of the same first-listed muscle.
    """
    chosen: List[Exercise] = []
    last_primary: Optional[str] = None
    for ex in candidates:
        top = ex.muscles.primary[0].lower() if ex.muscles.primary else ex.name.lower()
        if last_primary and top == last_primary:
            continue
        chosen.append(ex)
        last_primary = top
        if len(chosen) >= k:
            break
    # If we didn't fill k, append the rest
    if len(chosen) < k:
        for ex in candidates:
            if ex not in chosen:
                chosen.append(ex)
                if len(chosen) >= k:
                    break
    return chosen[:k]

# -------------- LLM selection + ordering ---------------
def llm_select_and_order(pool: List[Exercise], req: PlanRequest) -> Tuple[List[Exercise], Dict[str, str]]:
    """
    Returns (chosen_exercises, reps_map). If LLM unavailable/fails, returns ([], {}).
    """
    if not req.use_llm or not _openai_available:
        return [], {}

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return [], {}

    # Build compact catalog to stay token-light
    catalog = [{
        "name": ex.name,
        "difficulty": ex.difficulty,
        "primary": ex.muscles.primary,
        "secondary": ex.muscles.secondary,
        "tertiary": ex.muscles.tertiary,
        "requiredSkills": ex.requiredSkills
    } for ex in pool]

    try:
        client = OpenAI(api_key=api_key)
        user_msg = {
            "target_muscles": req.target_muscles,
            "goal": req.goal or "balanced hypertrophy & skill practice",
            "session_minutes": req.session_minutes or 45,
            "number_of_exercises": req.number_of_exercises,
            "difficulty_range": [req.min_difficulty, req.max_difficulty],
            "user_skills": req.user_skills,
            "catalog": catalog,
            "rules": [
                "Choose only from catalog.",
                "Respect requiredSkills: do not pick moves that need locked skills.",
                "Avoid hitting the same primary muscle group in back-to-back items.",
                "Mix push/pull/legs/core where possible; include some novelty and fun.",
                "Prefer 1 skill/progression item (if allowed), 2 strength, 2 accessory/core, and an optional finisher.",
                "Keep total volume appropriate for the session_minutes.",
                "Return STRICT JSON: {\"plan\":[{\"name\":\"...\",\"prescription\":\"3x8-12\",\"block\":\"warmup|skill|strength|accessory|finisher\"}, ...]}"
            ]
        }

        resp = client.chat.completions.create(
            model=MODEL_NAME,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": "You are a world-class calisthenics coach. Output strict JSON only."},
                {"role": "user", "content": json.dumps(user_msg)}
            ],
            temperature=0.4,
        )
        content = resp.choices[0].message.content
        parsed = json.loads(content)
        plan = parsed.get("plan", [])

        # Build lookup (normalized) from pool
        def norm(s: str) -> str:
            return s.lower().replace("–", "-").replace("’", "'").replace(" push ups", " push up").strip()

        by_name = {norm(ex.name): ex for ex in pool}
        reps_map: Dict[str, str] = {}
        chosen: List[Exercise] = []

        for item in plan:
            nm = item.get("name")
            if not nm: continue
            nx = norm(nm)
            ref = by_name.get(nx)
            if not ref:
                # try loose match by startswith/contains
                matches = [ex for key, ex in by_name.items() if nx in key or key in nx]
                ref = matches[0] if matches else None
            if ref and ref not in chosen:
                chosen.append(ref)
                if "prescription" in item and item["prescription"]:
                    reps_map[ref.name] = item["prescription"]

        # truncate to requested size
        chosen = chosen[: req.number_of_exercises]
        return chosen, reps_map
    except Exception:
        return [], {}

# -------------- Optional LLM reps-only refinement ---------------
def llm_fill_reps(plan_items: List["PlanExercise"], req: PlanRequest) -> None:
    if not req.use_llm or not _openai_available:
        return
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return
    try:
        client = OpenAI(api_key=api_key)
        payload = {
            "goal": req.goal or "balanced hypertrophy & skill practice",
            "session_minutes": req.session_minutes or 45,
            "target_muscles": req.target_muscles,
            "exercises": [{"name": it.name, "difficulty": it.difficulty} for it in plan_items],
            "instructions": (
                "Assign sensible sets×reps or time (e.g., '3×8–12' or '3×20s') for each exercise "
                "to fit the session length. Return only JSON: "
                "{\"plan\": [{\"name\":\"...\",\"reps\":\"...\"}, ...]}"
            ),
        }
        resp = client.chat.completions.create(
            model=MODEL_NAME,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": "You are a concise strength coach. Output strict JSON only."},
                {"role": "user", "content": json.dumps(payload)},
            ],
            temperature=0.2,
        )
        content = resp.choices[0].message.content
        parsed = json.loads(content)
        reps_map = {p["name"]: p["reps"] for p in parsed.get("plan", []) if "name" in p and "reps" in p}
        for it in plan_items:
            if not it.reps and it.name in reps_map:
                it.reps = reps_map[it.name]
    except Exception:
        pass

# ---------- API ----------
app = FastAPI(title="Workout AI Planner (catalog → plan)")

@app.post("/plan", response_model=PlanResponse)
def plan(req: PlanRequest):
    if not req.target_muscles:
        raise HTTPException(status_code=400, detail="target_muscles cannot be empty")

    targets: Set[str] = {canon(m) for m in req.target_muscles}
    user_skills: Set[str] = {canon(s) for s in req.user_skills}

    # Filter by difficulty and skills if requested
    filtered: List[Exercise] = []
    for ex in EXERCISES:
        if not (req.min_difficulty <= ex.difficulty <= req.max_difficulty):
            continue
        if req.gate_by_skills:
            required = {canon(s) for s in ex.requiredSkills}
            if not required.issubset(user_skills):
                continue
        filtered.append(ex)

    if not filtered:
        raise HTTPException(status_code=404, detail="No exercises pass filters.")

    # --- Strategy A: AI chooses and orders from a shortlist ---
    chosen: List[Exercise] = []
    reps_override: Dict[str, str] = {}
    if req.use_llm:
        pool = shortlist(filtered, targets, top_k=40)
        chosen, reps_override = llm_select_and_order(pool, req)

    # --- Strategy B: Heuristic fallback if AI off or failed ---
    if not chosen:
        # deterministic shortlist then diversify
        pool = shortlist(filtered, targets, top_k=40)
        chosen = diversify(pool, k=req.number_of_exercises)

    # Build response items (apply AI reps where available; else keep dataset default)
    plan_items: List[PlanExercise] = [
        PlanExercise(
            name=ex.name,
            description=ex.description,
            difficulty=ex.difficulty,
            reps=reps_override.get(ex.name, ex.reps)
        )
        for ex in chosen[: req.number_of_exercises]
    ]

    # If AI selection was off, we can still let AI refine reps optionally
    if req.use_llm and not reps_override:
        llm_fill_reps(plan_items, req)

    return PlanResponse(
        plan=plan_items,
        focus_scores=make_focus_scores(chosen, targets),
        notes=["Warm up 5–10 min", "Rest 60–90 s between sets", "Cool down & stretch"]
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
