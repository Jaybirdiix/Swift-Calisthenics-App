#!/usr/bin/env python3
"""
Deterministic workout planner (no ML).
- Reads a JSON database of exercises.
- Filters by focus muscles, difficulty band, and equipment.
- Assembles blocks: warmup, skill, strength x2, accessory, cooldown.
- Chooses doses from each exercise's "reps" field (e.g., "10s / 20s / 30s").
- Fits a time budget by trimming sets if needed.
"""

import argparse
import json
import math
import re
from typing import Any, Dict, List, Tuple, Set


# -------------------- helpers --------------------

def norm(s: str) -> str:
    return (s or "").strip().lower()

def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", norm(s)).strip("-")

def difficulty_band_to_range(band: str) -> Tuple[int, int]:
    return {
        "beginner": (1, 3),
        "intermediate": (4, 6),
        "advanced": (7, 8),
        "elite": (9, 10),
    }.get(band, (4, 6))

def band_to_index(band: str, n: int) -> int:
    if n <= 1:
        return 0
    return {
        "beginner": 0,
        "intermediate": min(1, n - 1),
        "advanced": n - 1 if n >= 3 else min(1, n - 1),
        "elite": n - 1,
    }.get(band, min(1, n - 1))

def parse_reps_field(reps: str) -> Tuple[List[int], str]:
    """
    Parse reps/hold tiers from strings like:
      "Arch Hold – 20s / 30s / 40s" -> ([20,30,40], 's')
      "Archer Push Up – 6 / 10 / 14" -> ([6,10,14], 'reps')
    """
    if not reps:
        return [8, 10, 12], "reps"
    parts = re.split(r"[–-]", reps, maxsplit=1)
    rhs = parts[1] if len(parts) > 1 else parts[0]
    tiers = [t.strip() for t in rhs.split("/") if t.strip()]
    vals: List[int] = []
    unit = "reps"
    for t in tiers:
        m = re.match(r"(\d+)\s*(s)?", t, flags=re.I)
        if m:
            vals.append(int(m.group(1)))
            if m.group(2):
                unit = "s"
    if not vals:
        return [8, 10, 12], "reps"
    return vals, unit

def classify_movement(name: str) -> str:
    n = norm(name)
    if any(k in n for k in ["pull up", "chin up", "row", "lever"]):
        return "pull"
    if any(k in n for k in ["push up", "dip", "planche", "handstand push", "hspu"]):
        return "push"
    if any(k in n for k in ["squat", "pistol", "lunge", "deadlift"]):
        return "legs"
    if any(k in n for k in ["hold", "hollow", "arch", "l-sit", "lsit", "plank"]):
        return "core"
    if any(k in n for k in ["handstand", "back roll", "press to handstand"]):
        return "skill"
    return "other"

def default_notes(name: str) -> str:
    cls = classify_movement(name)
    if cls == "pull":  return "full hang, scap pull, smooth tempo"
    if cls == "push":  return "scap protracted, full lockout, neutral neck"
    if cls == "core":  return "brace core, steady breath, neutral spine"
    if cls == "skill": return "focus on form and control"
    return "quality over speed"

def equipment_ok(ex: Dict[str, Any], equip_flags: Dict[str, bool]) -> bool:
    req = ex.get("equipment", [])
    return all(equip_flags.get(norm(x), True) for x in req)

def score_exercise(
    ex: Dict[str, Any],
    focus: Set[str],
    band: str,
    equip_flags: Dict[str, bool]
) -> float:
    prim = sum(norm(m) in focus for m in ex.get("muscles", {}).get("primary", []))
    sec = sum(norm(m) in focus for m in ex.get("muscles", {}).get("secondary", []))
    diff = int(ex.get("difficulty", 5))
    lo, hi = difficulty_band_to_range(band)
    center = (lo + hi) / 2
    # 0..1 closeness
    difficulty_match = 1 - abs(center - diff) / 10
    equip = 1.0 if equipment_ok(ex, equip_flags) else 0.5
    # Slight bump for named "skill" class if selecting skill block later
    skill_bump = 0.3 if classify_movement(ex.get("name", "")) in ("skill", "core") else 0.0
    return 3 * prim + 1 * sec + 1.5 * difficulty_match + 1 * equip + skill_bump

def choose_dose(ex: Dict[str, Any], band: str) -> str:
    tiers, unit = parse_reps_field(ex.get("reps", ""))
    idx = band_to_index(band, len(tiers))
    val = tiers[idx]
    return f"{val}s" if unit == "s" else f"{val} reps"

def estimate_time_per_set(dose: str, block: str) -> int:
    """
    Return seconds for one set including a typical rest.
    """
    # time part
    m_s = re.match(r"^\s*(\d+)\s*s\s*$", dose)
    m_r = re.match(r"^\s*(\d+)\s*reps\s*$", dose, flags=re.I)
    m_m = re.match(r"^\s*(\d+)(?:-(\d+))?\s*m\s*$", dose, flags=re.I)

    if m_s:
        secs = int(m_s.group(1))
        rest = 60 if block == "strength" else 45 if block in ("skill", "accessory") else 15
        return secs + rest
    if m_r:
        reps = int(m_r.group(1))
        sec_per_rep = 3.0 if block == "strength" else 2.5
        rest = 75 if block == "strength" else 45
        return int(reps * sec_per_rep + rest)
    if m_m:
        lo = int(m_m.group(1))
        hi = int(m_m.group(2) or lo)
        return int(((lo + hi) / 2) * 60)
    # fallback
    return 60

def pick_first(cands: List[Dict[str, Any]], taken: Set[str], pred) -> Dict[str, Any] | None:
    for e in cands:
        if norm(e["name"]) in taken:
            continue
        if pred(e):
            return e
    return None

def fits_band(ex: Dict[str, Any], band: str) -> bool:
    lo, hi = difficulty_band_to_range(band)
    return lo <= int(ex.get("difficulty", 5)) <= hi


# -------------------- planner --------------------

def rank_candidates(
    all_exercises: List[Dict[str, Any]],
    focus_muscles: List[str],
    band: str,
    equipment_flags: Dict[str, bool],
) -> List[Dict[str, Any]]:
    focus = {norm(m) for m in focus_muscles}
    ranked = sorted(
        all_exercises,
        key=lambda e: score_exercise(e, focus, band, equipment_flags),
        reverse=True,
    )
    # keep band-matching and equipment-ok near top
    ranked = [e for e in ranked if equipment_ok(e, equipment_flags)]
    return ranked

def build_block_item(ex: Dict[str, Any], band: str, sets: int, block_name: str) -> Dict[str, Any]:
    dose = choose_dose(ex, band) if block_name != "warmup" and block_name != "cooldown" else (
        "2m" if block_name == "warmup" else "3m"
    )
    item = {
        "id": slug(ex["name"]),
        "name": ex["name"],
        "sets": sets,
        "dose": dose,
        "notes": default_notes(ex["name"]),
    }
    # If prerequisites exist and are not obviously basic, hint in notes
    reqs = ex.get("requiredSkills", [])
    if reqs:
        item["notes"] += f"; prereq: {', '.join(reqs)}"
    return item

def assemble_plan(
    ranked: List[Dict[str, Any]],
    minutes: int,
    band: str,
    focus_muscles: List[str],
) -> Dict[str, Any]:
    taken: Set[str] = set()
    blocks: List[Dict[str, Any]] = []

    # convenience filters
    def is_hold(e): return "hold" in norm(e["name"])
    def is_skilly(e): return classify_movement(e["name"]) in ("skill", "core") or any(k in norm(e["name"]) for k in ["planche","lever","handstand"])
    def is_push(e): return classify_movement(e["name"]) == "push"
    def is_pull(e): return classify_movement(e["name"]) == "pull"

    # WARMUP (1)
    warmup = pick_first(
        ranked, taken,
        lambda e: is_hold(e) and int(e.get("difficulty", 5)) <= 3
    ) or pick_first(ranked, taken, lambda e: int(e.get("difficulty", 5)) <= 3) or ranked[0]
    taken.add(norm(warmup["name"]))
    blocks.append({"name": "warmup", "items": [build_block_item(warmup, band, sets=1, block_name="warmup")]})

    # SKILL (1)
    skill = pick_first(
        ranked, taken,
        lambda e: is_skilly(e) and fits_band(e, band)
    ) or pick_first(ranked, taken, lambda e: is_skilly(e)) or pick_first(ranked, taken, lambda e: fits_band(e, band))
    if skill:
        taken.add(norm(skill["name"]))
        blocks.append({"name": "skill", "items": [build_block_item(skill, band, sets=3, block_name="skill")]})

    # STRENGTH (2) – try one push + one pull if possible
    strength_items: List[Dict[str, Any]] = []
    push = pick_first(ranked, taken, lambda e: is_push(e) and fits_band(e, band))
    if push:
        taken.add(norm(push["name"]))
        strength_items.append(build_block_item(push, band, sets=3, block_name="strength"))
    pull = pick_first(ranked, taken, lambda e: is_pull(e) and fits_band(e, band))
    if pull:
        taken.add(norm(pull["name"]))
        strength_items.append(build_block_item(pull, band, sets=3, block_name="strength"))
    # fill if missing one
    if len(strength_items) < 2:
        extra = pick_first(ranked, taken, lambda e: fits_band(e, band))
        if extra:
            taken.add(norm(extra["name"]))
            strength_items.append(build_block_item(extra, band, sets=3, block_name="strength"))
    if strength_items:
        blocks.append({"name": "strength", "items": strength_items})

    # ACCESSORY (1)
    accessory = pick_first(
        ranked, taken,
        lambda e: int(e.get("difficulty", 5)) <= max(difficulty_band_to_range(band)[0] + 1, 4)
    ) or pick_first(ranked, taken, lambda e: True)
    if accessory:
        taken.add(norm(accessory["name"]))
        blocks.append({"name": "accessory", "items": [build_block_item(accessory, band, sets=2, block_name="accessory")]})

    # COOLDOWN (1)
    cooldown = pick_first(ranked, taken, lambda e: is_hold(e) and int(e.get("difficulty", 5)) <= 3) or warmup
    if cooldown:
        taken.add(norm(cooldown["name"]))
        blocks.append({"name": "cooldown", "items": [build_block_item(cooldown, band, sets=1, block_name="cooldown")]})

    plan = {"minutes": minutes, "blocks": blocks}
    trim_to_time_budget(plan)
    return plan

def total_plan_seconds(plan: Dict[str, Any]) -> int:
    secs = 0
    for block in plan["blocks"]:
        bname = block["name"]
        for it in block["items"]:
            per = estimate_time_per_set(it["dose"], bname)
            secs += per * int(it["sets"])
    return secs

def trim_to_time_budget(plan: Dict[str, Any]) -> None:
    budget = plan["minutes"] * 60
    # order to trim: accessory -> strength -> skill; reduce sets
    order = ["accessory", "strength", "skill"]
    while total_plan_seconds(plan) > budget:
        trimmed = False
        for bname in order:
            for block in plan["blocks"]:
                if block["name"] != bname:
                    continue
                # reduce last item's sets first
                for it in reversed(block["items"]):
                    if it["sets"] > 1:
                        it["sets"] -= 1
                        trimmed = True
                        break
                if trimmed:
                    break
            if trimmed:
                break
        if not trimmed:
            # as a last resort, shorten holds by converting to smaller dose if possible
            for block in plan["blocks"]:
                for it in block["items"]:
                    # if dose like "40s" -> cut to "25s" ; if reps -> cut by ~20%
                    m_s = re.match(r"^\s*(\d+)\s*s\s*$", it["dose"])
                    m_r = re.match(r"^\s*(\d+)\s*reps\s*$", it["dose"], flags=re.I)
                    if m_s:
                        val = int(m_s.group(1))
                        if val > 20:
                            it["dose"] = f"{max(15, int(val * 0.7))}s"
                            trimmed = True
                            break
                    elif m_r:
                        val = int(m_r.group(1))
                        if val > 6:
                            it["dose"] = f"{max(5, int(math.ceil(val * 0.8)))} reps"
                            trimmed = True
                            break
                if trimmed:
                    break
        if not trimmed:
            # give up
            break


# -------------------- CLI --------------------

JSON_PATH = "mini_exercises.json"#!/usr/bin/env python3
"""
Deterministic workout planner with controllable randomness (no ML).
- Filters by focus muscles, difficulty band, and equipment.
- Assembles blocks: warmup, skill, strength x2, accessory, cooldown.
- Adds small randomness to selection, dose tier, and sets (seedable).
"""

import argparse
import json
import math
import random
import re
from typing import Any, Dict, List, Tuple, Set


# -------------------- helpers --------------------

def norm(s: str) -> str:
    return (s or "").strip().lower()

def slug(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", norm(s)).strip("-")

def difficulty_band_to_range(band: str) -> Tuple[int, int]:
    return {
        "beginner": (1, 3),
        "intermediate": (4, 6),
        "advanced": (7, 8),
        "elite": (9, 10),
    }.get(band, (4, 6))

def band_to_index(band: str, n: int) -> int:
    if n <= 1:
        return 0
    return {
        "beginner": 0,
        "intermediate": min(1, n - 1),
        "advanced": n - 1 if n >= 3 else min(1, n - 1),
        "elite": n - 1,
    }.get(band, min(1, n - 1))

def parse_reps_field(reps: str) -> Tuple[List[int], str]:
    """
    Parse reps/hold tiers from strings like:
      "Arch Hold – 20s / 30s / 40s" -> ([20,30,40], 's')
      "Archer Push Up – 6 / 10 / 14" -> ([6,10,14], 'reps')
    """
    if not reps:
        return [8, 10, 12], "reps"
    parts = re.split(r"[–-]", reps, maxsplit=1)
    rhs = parts[1] if len(parts) > 1 else parts[0]
    tiers = [t.strip() for t in rhs.split("/") if t.strip()]
    vals: List[int] = []
    unit = "reps"
    for t in tiers:
        m = re.match(r"(\d+)\s*(s)?", t, flags=re.I)
        if m:
            vals.append(int(m.group(1)))
            if m.group(2):
                unit = "s"
    if not vals:
        return [8, 10, 12], "reps"
    return vals, unit

def classify_movement(name: str) -> str:
    n = norm(name)
    if any(k in n for k in ["pull up", "chin up", "row", "lever"]):
        return "pull"
    if any(k in n for k in ["push up", "dip", "planche", "handstand push", "hspu"]):
        return "push"
    if any(k in n for k in ["squat", "pistol", "lunge", "deadlift"]):
        return "legs"
    if any(k in n for k in ["hold", "hollow", "arch", "l-sit", "lsit", "plank"]):
        return "core"
    if any(k in n for k in ["handstand", "back roll", "press to handstand"]):
        return "skill"
    return "other"

def default_notes(name: str) -> str:
    cls = classify_movement(name)
    if cls == "pull":  return "full hang; scap pull; smooth"
    if cls == "push":  return "protract; lockout; neutral neck"
    if cls == "core":  return "brace; breathe; neutral spine"
    if cls == "skill": return "strict form; control"
    return "quality over speed"

def equipment_ok(ex: Dict[str, Any], equip_flags: Dict[str, bool]) -> bool:
    req = ex.get("equipment", [])
    return all(equip_flags.get(norm(x), True) for x in req)

def score_exercise(
    ex: Dict[str, Any],
    focus: Set[str],
    band: str,
    equip_flags: Dict[str, bool]
) -> float:
    prim = sum(norm(m) in focus for m in ex.get("muscles", {}).get("primary", []))
    sec = sum(norm(m) in focus for m in ex.get("muscles", {}).get("secondary", []))
    diff = int(ex.get("difficulty", 5))
    lo, hi = difficulty_band_to_range(band)
    center = (lo + hi) / 2
    difficulty_match = 1 - abs(center - diff) / 10  # 0..1
    equip = 1.0 if equipment_ok(ex, equip_flags) else 0.5
    skill_bump = 0.3 if classify_movement(ex.get("name", "")) in ("skill", "core") else 0.0
    return 3 * prim + 1 * sec + 1.5 * difficulty_match + 1 * equip + skill_bump

def choose_dose(ex: Dict[str, Any], band: str, rand: float) -> str:
    tiers, unit = parse_reps_field(ex.get("reps", ""))
    idx = band_to_index(band, len(tiers))
    # small chance to nudge to an adjacent tier for variety
    if len(tiers) > 1 and rand > 0 and random.random() < min(0.35, 0.7 * rand):
        idx = max(0, min(len(tiers) - 1, idx + random.choice([-1, 1])))
    val = tiers[idx]
    return f"{val}s" if unit == "s" else f"{val} reps"

def estimate_time_per_set(dose: str, block: str) -> int:
    """
    Return seconds for one set including a typical rest.
    """
    m_s = re.match(r"^\s*(\d+)\s*s\s*$", dose)
    m_r = re.match(r"^\s*(\d+)\s*reps\s*$", dose, flags=re.I)
    m_m = re.match(r"^\s*(\d+)(?:-(\d+))?\s*m\s*$", dose, flags=re.I)

    if m_s:
        secs = int(m_s.group(1))
        rest = 60 if block == "strength" else 45 if block in ("skill", "accessory") else 15
        return secs + rest
    if m_r:
        reps = int(m_r.group(1))
        sec_per_rep = 3.0 if block == "strength" else 2.5
        rest = 75 if block == "strength" else 45
        return int(reps * sec_per_rep + rest)
    if m_m:
        lo = int(m_m.group(1)); hi = int(m_m.group(2) or lo)
        return int(((lo + hi) / 2) * 60)
    return 60

def fits_band(ex: Dict[str, Any], band: str) -> bool:
    lo, hi = difficulty_band_to_range(band)
    return lo <= int(ex.get("difficulty", 5)) <= hi

def sample_from_top(
    scored: List[Tuple[Dict[str, Any], float]],
    taken: Set[str],
    pred,
    top_k: int
) -> Dict[str, Any] | None:
    pool = [(e, s) for (e, s) in scored if pred(e) and norm(e["name"]) not in taken]
    if not pool:
        return None
    k = min(top_k, len(pool))
    # bias toward higher scores but allow exploration
    idx = random.randrange(k)
    return pool[idx][0]


# -------------------- planner --------------------

def rank_candidates(
    all_exercises: List[Dict[str, Any]],
    focus_muscles: List[str],
    band: str,
    equipment_flags: Dict[str, bool],
    rand: float
) -> List[Tuple[Dict[str, Any], float]]:
    focus = {norm(m) for m in focus_muscles}
    scored: List[Tuple[Dict[str, Any], float]] = []
    for e in all_exercises:
        if not equipment_ok(e, equipment_flags):
            continue
        s = score_exercise(e, focus, band, equipment_flags)
        # small random jitter to break ties / add variety
        if rand > 0:
            s += random.uniform(-0.4, 0.4) * rand
        scored.append((e, s))
    scored.sort(key=lambda x: x[1], reverse=True)
    return scored

def build_block_item(ex: Dict[str, Any], band: str, sets: int, block_name: str, rand: float) -> Dict[str, Any]:
    if block_name == "warmup":
        dur = 2 if rand == 0 else random.choice([1, 2, 3])
        dose = f"{dur}m"
    elif block_name == "cooldown":
        dur = 3 if rand == 0 else random.choice([2, 3, 4])
        dose = f"{dur}m"
    else:
        dose = choose_dose(ex, band, rand)

    # small set jitter (±1) except warmup/cooldown
    if rand > 0 and block_name not in ("warmup", "cooldown") and random.random() < min(0.45, 0.9 * rand):
        sets = max(1, sets + random.choice([-1, 0, 1]))

    item = {
        "id": slug(ex["name"]),
        "name": ex["name"],
        "sets": sets,
        "dose": dose,
        "notes": default_notes(ex["name"]),
    }
    reqs = ex.get("requiredSkills", [])
    if reqs:
        item["notes"] += f"; prereq: {', '.join(reqs)}"
    return item

def assemble_plan(
    scored: List[Tuple[Dict[str, Any], float]],
    minutes: int,
    band: str,
    top_k: int,
    rand: float
) -> Dict[str, Any]:
    taken: Set[str] = set()
    blocks: List[Dict[str, Any]] = []

    def is_hold(e): return "hold" in norm(e["name"])
    def is_skilly(e): return classify_movement(e["name"]) in ("skill", "core") or any(k in norm(e["name"]) for k in ["planche","lever","handstand"])
    def is_push(e): return classify_movement(e["name"]) == "push"
    def is_pull(e): return classify_movement(e["name"]) == "pull"

    # WARMUP
    warmup = (sample_from_top(scored, taken, lambda e: is_hold(e) and int(e.get("difficulty", 5)) <= 3, top_k)
              or sample_from_top(scored, taken, lambda e: int(e.get("difficulty", 5)) <= 3, top_k)
              or scored[0][0])
    taken.add(norm(warmup["name"]))
    blocks.append({"name": "warmup", "items": [build_block_item(warmup, band, sets=1, block_name="warmup", rand=rand)]})

    # SKILL
    skill = (sample_from_top(scored, taken, lambda e: is_skilly(e) and fits_band(e, band), top_k)
             or sample_from_top(scored, taken, lambda e: is_skilly(e), top_k)
             or sample_from_top(scored, taken, lambda e: fits_band(e, band), top_k))
    if skill:
        taken.add(norm(skill["name"]))
        blocks.append({"name": "skill", "items": [build_block_item(skill, band, sets=3, block_name="skill", rand=rand)]})

    # STRENGTH (try push + pull)
    strength_items: List[Dict[str, Any]] = []
    push = sample_from_top(scored, taken, lambda e: is_push(e) and fits_band(e, band), top_k)
    if push:
        taken.add(norm(push["name"]))
        strength_items.append(build_block_item(push, band, sets=3, block_name="strength", rand=rand))
    pull = sample_from_top(scored, taken, lambda e: is_pull(e) and fits_band(e, band), top_k)
    if pull:
        taken.add(norm(pull["name"]))
        strength_items.append(build_block_item(pull, band, sets=3, block_name="strength", rand=rand))
    if len(strength_items) < 2:
        extra = sample_from_top(scored, taken, lambda e: fits_band(e, band), top_k)
        if extra:
            taken.add(norm(extra["name"]))
            strength_items.append(build_block_item(extra, band, sets=3, block_name="strength", rand=rand))
    if strength_items:
        # optional tiny shuffle
        if rand > 0 and random.random() < min(0.35, 0.7 * rand):
            random.shuffle(strength_items)
        blocks.append({"name": "strength", "items": strength_items})

    # ACCESSORY
    accessory = (sample_from_top(
        scored, taken,
        lambda e: int(e.get("difficulty", 5)) <= max(difficulty_band_to_range(band)[0] + 1, 4),
        top_k
    ) or sample_from_top(scored, taken, lambda e: True, top_k))
    if accessory:
        taken.add(norm(accessory["name"]))
        blocks.append({"name": "accessory", "items": [build_block_item(accessory, band, sets=2, block_name="accessory", rand=rand)]})

    # COOLDOWN
    cooldown = (sample_from_top(scored, taken, lambda e: is_hold(e) and int(e.get("difficulty", 5)) <= 3, top_k)
                or warmup)
    if cooldown:
        taken.add(norm(cooldown["name"]))
        blocks.append({"name": "cooldown", "items": [build_block_item(cooldown, band, sets=1, block_name="cooldown", rand=rand)]})

    plan = {"minutes": minutes, "blocks": blocks}
    trim_to_time_budget(plan)
    return plan

def total_plan_seconds(plan: Dict[str, Any]) -> int:
    secs = 0
    for block in plan["blocks"]:
        bname = block["name"]
        for it in block["items"]:
            per = estimate_time_per_set(it["dose"], bname)
            secs += per * int(it["sets"])
    return secs

def trim_to_time_budget(plan: Dict[str, Any]) -> None:
    budget = plan["minutes"] * 60
    order = ["accessory", "strength", "skill"]
    while total_plan_seconds(plan) > budget:
        trimmed = False
        for bname in order:
            for block in plan["blocks"]:
                if block["name"] != bname:
                    continue
                for it in reversed(block["items"]):
                    if it["sets"] > 1:
                        it["sets"] -= 1
                        trimmed = True
                        break
                if trimmed:
                    break
            if trimmed:
                break
        if not trimmed:
            for block in plan["blocks"]:
                for it in block["items"]:
                    m_s = re.match(r"^\s*(\d+)\s*s\s*$", it["dose"])
                    m_r = re.match(r"^\s*(\d+)\s*reps\s*$", it["dose"], flags=re.I)
                    if m_s:
                        val = int(m_s.group(1))
                        if val > 20:
                            it["dose"] = f"{max(15, int(val * 0.7))}s"
                            trimmed = True
                            break
                    elif m_r:
                        val = int(m_r.group(1))
                        if val > 6:
                            it["dose"] = f"{max(5, int(math.ceil(val * 0.8)))} reps"
                            trimmed = True
                            break
                if trimmed:
                    break
        if not trimmed:
            break


# -------------------- CLI --------------------

def main():
    ap = argparse.ArgumentParser(description="Deterministic workout planner with randomness (no ML).")
    ap.add_argument("--exercises", default="exercises.json", help="Path to exercises JSON file")
    ap.add_argument("--focus", default="anterior deltoid,triceps", help="Comma-separated focus muscles")
    ap.add_argument("--band", default="intermediate", choices=["beginner","intermediate","advanced","elite"])
    ap.add_argument("--minutes", type=int, default=45, help="Session length in minutes")
    ap.add_argument("--equipment", default="floor,bar", help="Comma-separated equipment tokens (e.g., floor,bar,rings)")
    ap.add_argument("--out", default="plan.json", help="Where to write the plan JSON")
    ap.add_argument("--rand", type=float, default=0.20, help="Randomness level (0..1). 0 = fully deterministic.")
    ap.add_argument("--topk", type=int, default=6, help="Sample from top-K candidates per pick")
    ap.add_argument("--seed", type=int, default=None, help="Random seed (same seed -> same plan)")
    args = ap.parse_args()

    if args.seed is not None:
        random.seed(args.seed)

    with open(args.exercises, "r", encoding="utf-8") as f:
        all_exercises = json.load(f)

    focus_muscles = [s.strip() for s in args.focus.split(",") if s.strip()]
    equipment_list = [s.strip().lower() for s in args.equipment.split(",") if s.strip()]
    equipment_flags = {e: True for e in equipment_list}

    scored = rank_candidates(
        all_exercises, focus_muscles, args.band, equipment_flags, rand=args.rand
    )
    if not scored:
        raise SystemExit("No exercises matched your filters/equipment. Add more items or loosen filters.")

    plan = assemble_plan(scored, minutes=args.minutes, band=args.band, top_k=args.topk, rand=args.rand)

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)

    # pretty print summary
    total_min = total_plan_seconds(plan) // 60
    print(f"\n✅ Wrote {args.out}")
    print(f"Estimated duration: ~{total_min} min (budget {args.minutes} min)")
    for block in plan["blocks"]:
        print(f"\n### {block['name']}")
        for it in block["items"]:
            print(f" - {it['name']}  |  {it['sets']} x {it['dose']}  |  {it['notes']}")

if __name__ == "__main__":
    main()

JSON_PATH = "../Data/exercises.json"

def main():
    ap = argparse.ArgumentParser(description="Deterministic workout planner (no ML).")
    ap.add_argument("--exercises", default=JSON_PATH, help="Path to exercises JSON file")
    ap.add_argument("--focus", default="anterior deltoid,triceps", help="Comma-separated focus muscles")
    ap.add_argument("--band", default="intermediate", choices=["beginner","intermediate","advanced","elite"])
    ap.add_argument("--minutes", type=int, default=45, help="Session length in minutes")
    ap.add_argument("--equipment", default="floor,bar", help="Comma-separated equipment tokens (e.g., floor,bar,rings)")
    ap.add_argument("--out", default="plan.json", help="Where to write the plan JSON")
    args = ap.parse_args()

    with open(args.exercises, "r", encoding="utf-8") as f:
        all_exercises = json.load(f)

    focus_muscles = [s.strip() for s in args.focus.split(",") if s.strip()]
    equipment_list = [s.strip().lower() for s in args.equipment.split(",") if s.strip()]
    equipment_flags = {e: True for e in equipment_list}

    ranked = rank_candidates(all_exercises, focus_muscles, args.band, equipment_flags)
    if not ranked:
        raise SystemExit("No exercises matched your filters/equipment. Add more items or loosen filters.")

    plan = assemble_plan(ranked, minutes=args.minutes, band=args.band, focus_muscles=focus_muscles)

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(plan, f, ensure_ascii=False, indent=2)

    # pretty print summary
    print(f"\n✅ Wrote {args.out}")
    secs = total_plan_seconds(plan)
    print(f"Estimated duration: ~{secs//60} min (budget {args.minutes} min)")
    for block in plan["blocks"]:
        print(f"\n### {block['name']}")
        for it in block["items"]:
            print(f" - {it['name']}  |  {it['sets']} x {it['dose']}  |  {it['notes']}")

if __name__ == "__main__":
    main()
