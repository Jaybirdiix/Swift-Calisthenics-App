#!/usr/bin/env python3
"""
Plan a varied, AI-chosen workout using a local Ollama model only.

Usage examples:
  python ollama_workout_planner.py \
      --exercises ./exercises.json \
      --targets "Anterior Deltoid,Pectoralis Major,Triceps Brachii" \
      --n 6 --minutes 45 --model llama3.1:8b

  python ollama_workout_planner.py \
      --exercises ./exercises.json \
      --targets "Latissimus Dorsi,Biceps Brachii,Forearm Flexors" \
      --gate-by-skills --user-skills "Pull Up,Dip" \
      --n 6 --minutes 40 --model mistral:7b
"""

import argparse
import json
import os
import re
import sys
from typing import List, Dict, Tuple, Set
import requests

# ----------------------- Data models (dict-based) -----------------------

def canon(s: str) -> str:
    return s.strip().lower()

def normalize_name(s: str) -> str:
    return (s or "").lower().replace("–", "-").replace("’", "'").replace(" push ups", " push up").strip()

def load_exercises(path: str) -> List[Dict]:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    # minimal validation
    for ex in data:
        ex.setdefault("reps", None)
        ex.setdefault("requiredSkills", [])
        # muscles must exist
        ex["muscles"].setdefault("primary", [])
        ex["muscles"].setdefault("secondary", [])
        ex["muscles"].setdefault("tertiary", [])
    return data

def compatibility_score(ex: Dict, targets: Set[str]) -> int:
    prim = {canon(m) for m in ex["muscles"]["primary"]}
    sec  = {canon(m) for m in ex["muscles"]["secondary"]}
    ter  = {canon(m) for m in ex["muscles"]["tertiary"]}
    s = 0
    s += 3 * len(prim & targets)
    s += 2 * len(sec & targets)
    s += 1 * len(ter & targets)
    return s

def shortlist(exercises: List[Dict], targets: Set[str], min_diff: int, max_diff: int,
              gate_by_skills: bool, user_skills: Set[str], top_k: int = 40) -> List[Dict]:
    filtered = []
    for ex in exercises:
        if not (min_diff <= int(ex.get("difficulty", 0)) <= max_diff):
            continue
        if gate_by_skills:
            req = {canon(s) for s in ex.get("requiredSkills", [])}
            if not req.issubset(user_skills):
                continue
        filtered.append(ex)

    scored = [(ex, compatibility_score(ex, targets)) for ex in filtered]
    scored = [t for t in scored if t[1] > 0]
    scored.sort(key=lambda t: (t[1], int(t[0].get("difficulty", 0)), t[0]["name"].lower()), reverse=True)
    return [ex for ex, _ in scored[:top_k]]

def diversify(candidates: List[Dict], k: int) -> List[Dict]:
    """Heuristic fallback: avoid consecutive same first-listed primary muscle."""
    chosen = []
    last_primary = None
    for ex in candidates:
        prims = ex["muscles"]["primary"]
        top = prims[0].lower() if prims else ex["name"].lower()
        if last_primary and top == last_primary:
            continue
        chosen.append(ex)
        last_primary = top
        if len(chosen) >= k:
            break
    # fill if short
    if len(chosen) < k:
        for ex in candidates:
            if ex not in chosen:
                chosen.append(ex)
                if len(chosen) >= k:
                    break
    return chosen[:k]

def make_focus_scores(plan: List[Dict], targets: Set[str]) -> Dict[str, int]:
    scores: Dict[str, int] = {}
    for ex in plan:
        for m in ex["muscles"]["primary"]:
            if canon(m) in targets: scores[m] = scores.get(m, 0) + 3
        for m in ex["muscles"]["secondary"]:
            if canon(m) in targets: scores[m] = scores.get(m, 0) + 2
        for m in ex["muscles"]["tertiary"]:
            if canon(m) in targets: scores[m] = scores.get(m, 0) + 1
    return dict(sorted(scores.items(), key=lambda kv: (-kv[1], kv[0])))

# ----------------------- Ollama call -----------------------

def ollama_generate(model: str, prompt: str, host: str = "http://localhost:11434") -> str:
    """
    Calls Ollama /api/generate with stream=false to get a single JSON response.
    Returns the 'response' text (model output).
    """
    url = f"{host}/api/generate"
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": False,
        "options": {"temperature": 0.4}
    }
    r = requests.post(url, json=payload, timeout=120)
    r.raise_for_status()
    data = r.json()
    return data.get("response", "")

def extract_json(text: str) -> dict:
    """Attempt to parse a JSON object from model text; tolerant to extra text."""
    # best effort: find the first {...} block
    m = re.search(r"\{.*\}", text, flags=re.DOTALL)
    if not m:
        raise ValueError("No JSON object found in model output.")
    snippet = m.group(0)
    return json.loads(snippet)

# ----------------------- AI selection -----------------------

def llm_select_and_order(pool: List[Dict], targets: List[str], goal: str,
                         session_minutes: int, n: int, model: str) -> Tuple[List[Dict], Dict[str, str]]:
    """
    Ask the local model to choose + order a plan from 'pool'.
    Returns (chosen_exercises, reps_override).
    """
    catalog = [{
        "name": ex["name"],
        "difficulty": int(ex.get("difficulty", 0)),
        "primary": ex["muscles"]["primary"],
        "secondary": ex["muscles"]["secondary"],
        "tertiary": ex["muscles"]["tertiary"],
        "requiredSkills": ex.get("requiredSkills", [])
    } for ex in pool]

    user_msg = {
        "target_muscles": targets,
        "goal": goal or "balanced hypertrophy & skill practice with variety",
        "session_minutes": session_minutes,
        "number_of_exercises": n,
        "catalog": catalog,
        "rules": [
            "Choose only from catalog.",
            "Respect requiredSkills: do not pick moves that the user has not unlocked.",
            "Avoid hitting the same primary muscle group in back-to-back items.",
            "Mix push/pull/legs/core for variety and fun.",
            "Keep difficulty reasonable for the session length.",
            "Return STRICT JSON ONLY:\n"
            "{\"plan\":[{\"name\":\"...\",\"prescription\":\"3x8-12\",\"block\":\"warmup|skill|strength|accessory|finisher\"}, ...]}"
        ]
    }

    prompt = (
        "You are a world-class calisthenics coach.\n"
        "Given this JSON, choose a good, varied workout that obeys the rules.\n"
        "Output STRICT JSON only.\n\n"
        f"{json.dumps(user_msg)}"
    )

    out = ollama_generate(model=model, prompt=prompt)
    data = extract_json(out)
    plan = data.get("plan", [])

    # Build fast lookup for matching by normalized name
    by_name = {normalize_name(ex["name"]): ex for ex in pool}
    chosen: List[Dict] = []
    reps_map: Dict[str, str] = {}

    for item in plan:
        nm = item.get("name")
        if not nm: 
            continue
        nx = normalize_name(nm)
        ex = by_name.get(nx)
        if not ex:
            # try a loose contains match
            matches = [v for k, v in by_name.items() if nx in k or k in nx]
            ex = matches[0] if matches else None
        if ex and ex not in chosen:
            chosen.append(ex)
            presc = item.get("prescription")
            if presc:
                reps_map[ex["name"]] = presc

    return chosen[:n], reps_map

# ----------------------- Main script -----------------------

def main():
    ap = argparse.ArgumentParser(description="Local (Ollama) AI workout planner")
    ap.add_argument("--exercises", required=True, help="Path to exercises.json")
    ap.add_argument("--targets", required=True,
                    help="Comma-separated list of target muscles (e.g. 'Anterior Deltoid,Pectoralis Major')")
    ap.add_argument("--user-skills", default="", help="Comma-separated unlocked skills (optional)")
    ap.add_argument("--gate-by-skills", action="store_true", help="Exclude exercises that require locked skills")
    ap.add_argument("--min-diff", type=int, default=1)
    ap.add_argument("--max-diff", type=int, default=10)
    ap.add_argument("--n", type=int, default=6, help="Number of exercises")
    ap.add_argument("--minutes", type=int, default=45)
    ap.add_argument("--model", default=os.getenv("OLLAMA_MODEL", "llama3.1:8b"))
    ap.add_argument("--ollama-host", default=os.getenv("OLLAMA_HOST", "http://localhost:11434"))
    args = ap.parse_args()

    try:
        exercises = load_exercises(args.exercises)
    except Exception as e:
        print(f"Failed to load exercises: {e}", file=sys.stderr)
        sys.exit(1)

    targets = [t.strip() for t in args.targets.split(",") if t.strip()]
    if not targets:
        print("No targets provided.", file=sys.stderr)
        sys.exit(1)

    target_set = {canon(t) for t in targets}
    user_skills = {canon(s) for s in [u.strip() for u in args.user_skills.split(",") if u.strip()]}

    pool = shortlist(
        exercises, target_set,
        min_diff=args.min_diff, max_diff=args.max_diff,
        gate_by_skills=args.gate_by_skills, user_skills=user_skills,
        top_k=40
    )
    if not pool:
        print(json.dumps({"error": "No exercises pass filters/targets."}, indent=2))
        sys.exit(0)

    # Try AI selection first
    chosen, reps_override = [], {}
    try:
        # temporarily override Ollama host for this call
        global ollama_generate
        def ollama_generate(model: str, prompt: str, host: str = args.ollama_host) -> str:
            url = f"{host}/api/generate"
            payload = {"model": model, "prompt": prompt, "stream": False, "options": {"temperature": 0.4}}
            r = requests.post(url, json=payload, timeout=120)
            r.raise_for_status()
            return r.json().get("response", "")
        chosen, reps_override = llm_select_and_order(pool, targets, goal="Fun, varied session",
                                                        session_minutes=args.minutes, n=args.n, model=args.model)

    except Exception as e:
        # swallow and fallback
        print(f"(AI selection failed, falling back: {e})", file=sys.stderr)

    if chosen:
        print("(AI selection used)", file=sys.stderr)
    else:
        print("(AI timeout/fail → heuristic fallback)", file=sys.stderr)

    if not chosen:
        # heuristic diversify as fallback
        chosen = diversify(pool, k=args.n)

    # Build final plan items (apply AI reps if provided, else catalog reps)
    plan_items = []
    for ex in chosen[: args.n]:
        plan_items.append({
            "name": ex["name"],
            "description": ex.get("description", ""),
            "difficulty": int(ex.get("difficulty", 0)),
            "reps": reps_override.get(ex["name"], ex.get("reps"))
        })

    result = {
        "plan": plan_items,
        "focus_scores": make_focus_scores(chosen, target_set),
        "notes": ["Warm up 5–10 min", "Rest 60–90 s between sets", "Cool down & stretch"]
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
