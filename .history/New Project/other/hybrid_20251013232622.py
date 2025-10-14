def difficulty_band_to_range(band: str) -> tuple[int,int]:
    return {"beginner": (1,3), "intermediate": (4,6), "advanced": (7,8), "elite": (9,10)}[band]

def rank_candidates(all_exercises, focus_muscles, band, equipment):
    lo, hi = difficulty_band_to_range(band)
    def score(e):
        prim = sum(m in focus_muscles for m in map(str.lower, e["muscles"]["primary"]))
        sec  = sum(m in focus_muscles for m in map(str.lower, e["muscles"]["secondary"]))
        diff = e["difficulty"]
        difficulty_match = 1 - abs(((lo+hi)/2) - diff)/10
        equip_ok = 1 if all(req in equipment and equipment[req] for req in e.get("equipment", [])) else 0.5
        return 3*prim + 1*sec + 1.5*difficulty_match + 1*equip_ok

    # simple filter then rank
    filtered = [e for e in all_exercises if lo <= e["difficulty"] <= hi]
    # (optional) also filter by equipment here
    sorted_ex = sorted(filtered, key=score, reverse=True)
    return sorted_ex

def compress_for_prompt(exs):
    def short_reps(s: str) -> str:
        # "Arch Hold – 20s / 30s / 40s" -> "20s/30s/40s"
        return s.split("–",1)[-1].replace(" ", "")
    out = []
    for i,e in enumerate(exs):
        out.append({
            "id": f"e{i}",
            "name": e["name"],
            "diff": e["difficulty"],
            "primary": [m.lower() for m in e["muscles"]["primary"]],
            "reps": short_reps(e["reps"]),
            "req": e.get("requiredSkills", []),
            "equip": e.get("equipment", []),
        })
    return out


class PlanItem(BaseModel):
    id: str
    sets: int
    dose: str        # e.g., "10 reps" or "25s"
    notes: str

class Block(BaseModel):
    name: Literal["warmup","skill","strength","accessory","cooldown"]
    items: list[PlanItem]

class WorkoutPlan(BaseModel):
    minutes: int
    blocks: list[Block]
