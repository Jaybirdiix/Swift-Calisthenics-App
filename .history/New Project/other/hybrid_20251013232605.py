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
