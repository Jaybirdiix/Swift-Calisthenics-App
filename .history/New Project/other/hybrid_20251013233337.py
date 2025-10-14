# ---------- env & torch-compile shim (must be at top) ----------
import os
os.environ.setdefault("TORCH_COMPILE_DISABLE", "1")
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")
os.environ.setdefault("PYTORCH_ENABLE_MPS_FALLBACK", "1")  # harmless on Intel

import argparse
import json
from typing import List, Literal, Optional

import torch
torch._dynamo.config.suppress_errors = True

def _no_compile(*args, **kwargs):
    # Works both as direct fn and as @decorator factory
    if args and callable(args[0]):
        return args[0]
    def _decorator(fn): return fn
    return _decorator

torch.compile = _no_compile

# ---------- models & helpers ----------
from pydantic import BaseModel
import outlines
from transformers import AutoTokenizer, AutoModelForCausalLM

class PlanItem(BaseModel):
    id: str
    sets: int
    dose: str       # "10 reps" or "25s"
    notes: str

class Block(BaseModel):
    name: Literal["warmup","skill","strength","accessory","cooldown"]
    items: List[PlanItem]

class WorkoutPlan(BaseModel):
    minutes: int
    blocks: List[Block]

def difficulty_band_to_range(band: str) -> tuple[int,int]:
    return {
        "beginner": (1,3),
        "intermediate": (4,6),
        "advanced": (7,8),
        "elite": (9,10),
    }[band]

def rank_candidates(all_exercises, focus_muscles, band, equipment_flags):
    focus = {m.lower() for m in focus_muscles}
    lo, hi = difficulty_band_to_range(band)

    def score(e):
        prim = sum(m.lower() in focus for m in e["muscles"].get("primary", []))
        sec  = sum(m.lower() in focus for m in e["muscles"].get("secondary", []))
        diff = e.get("difficulty", 5)
        center = (lo + hi)/2
        difficulty_match = 1 - abs(center - diff)/10
        req_equip = e.get("equipment", [])
        equip_ok = 1.0 if all((equipment_flags.get(x, True)) for x in req_equip) else 0.5
        return 3*prim + 1*sec + 1.5*difficulty_match + 1*equip_ok

    filtered = [e for e in all_exercises if lo <= e.get("difficulty", 5) <= hi]
    return sorted(filtered, key=score, reverse=True)

def compress_for_prompt(exs):
    def short_reps(s: str) -> str:
        # "Arch Hold – 20s / 30s / 40s" -> "20s/30s/40s"
        return s.split("–",1)[-1].replace(" ", "") if "–" in s else s
    out = []
    for i, e in enumerate(exs):
        out.append({
            "id": f"e{i}",
            "name": e["name"],
            "diff": e.get("difficulty", 5),
            "primary": [m.lower() for m in e["muscles"].get("primary", [])],
            "secondary": [m.lower() for m in e["muscles"].get("secondary", [])],
            "reps": short_reps(e.get("reps", "")),
            "req": e.get("requiredSkills", []),
            "equip": e.get("equipment", []),
        })
    return out

def build_prompt(minutes, band, focus_muscles, equipment_list, compressed_candidates, schema_json):
    return f"""
You are a calisthenics coach. Build a {minutes}-minute workout as **JSON only** (no extra text).
Difficulty band: {band}
Focus muscles: {', '.join(focus_muscles)}
Equipment available: {', '.join(equipment_list) if equipment_list else 'bodyweight/floor'}

Select exercises **only** from these candidates (by id):
{json.dumps(compressed_candidates, ensure_ascii=False)}

Rules:
- Provide blocks in this exact order: warmup, skill, strength, accessory, cooldown.
- Choose rep/hold tiers from the 'reps' field that match the band:
  beginner=first, intermediate=middle, advanced=top (ignore 'elite' unless stated).
- Honor prerequisites: if an item's 'req' aren’t earlier in the plan, do not include it.
- Fit the time budget reasonably; include sets and per-item dose ('10 reps' or '25s') and concise coaching notes.
- Return JSON that validates against this schema:
{schema_json}
""".strip()

# ---------- main ----------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--exercises", default="mini_exercises.json", help="Path to exercises JSON")
    ap.add_argument("--focus", default="anterior deltoid,triceps", help="Comma-separated focus muscles")
    ap.add_argument("--band", default="intermediate", choices=["beginner","intermediate","advanced","elite"])
    ap.add_argument("--minutes", type=int, default=45)
    ap.add_argument("--equipment", default="floor,bar", help="Comma-separated equipment tokens (e.g., floor,bar,rings,parallettes)")
    ap.add_argument("--model", default="microsoft/Phi-3-mini-4k-instruct")
    ap.add_argument("--top_k_per_muscle", type=int, default=5)
    ap.add_argument("--max_new_tokens", type=int, default=600)
    ap.add_argument("--out", default="plan.json", help="Where to save the JSON plan")
    args = ap.parse_args()

    with open(args.exercises, "r", encoding="utf-8") as f:
        all_exercises = json.load(f)

    focus_muscles = [s.strip().lower() for s in args.focus.split(",") if s.strip()]
    equipment_list = [s.strip().lower() for s in args.equipment.split(",") if s.strip()]
    equipment_flags = {e: True for e in equipment_list}

    # rank & cut to a small candidate set
    ranked = rank_candidates(all_exercises, focus_muscles, args.band, equipment_flags)

    # keep up to K per focus muscle to keep the prompt small
    bucket = []
    seen = set()
    for m in focus_muscles:
        picks = [e for e in ranked if m in [x.lower() for x in e["muscles"].get("primary", [])]]
        for e in picks[:args.top_k_per_muscle]:
            key = e["name"].lower()
            if key not in seen:
                bucket.append(e); seen.add(key)

    # fallback: if too small, add some secondary hits
    if len(bucket) < args.top_k_per_muscle * max(1, len(focus_muscles)//2):
        for e in ranked:
            key = e["name"].lower()
            if key in seen: continue
            sec = any(m in [x.lower() for x in e["muscles"].get("secondary", [])] for m in focus_muscles)
            if sec:
                bucket.append(e); seen.add(key)
            if len(bucket) >= 30: break  # cap prompt size

    compressed = compress_for_prompt(bucket)
    compressed = compressed[:12]   # was ~30; 8–12 is plenty


    # load model
    device = "mps" if hasattr(torch.backends, "mps") and torch.backends.mps.is_available() else "cpu"
    tok = AutoTokenizer.from_pretrained(args.model)
    if tok.pad_token is None:
        tok.pad_token = tok.eos_token

    model_kwargs = dict(low_cpu_mem_usage=True, attn_implementation="eager")
    if device == "mps":
        model_kwargs["dtype"] = torch.float16
    hf = AutoModelForCausalLM.from_pretrained(args.model, **model_kwargs)
    if device == "mps":
        hf.to(device)

    gen = outlines.from_transformers(hf, tok)

    schema_json = WorkoutPlan.model_json_schema()
    prompt = build_prompt(args.minutes, args.band, focus_muscles, equipment_list, compressed, schema_json)

    plan_json = gen(prompt, WorkoutPlan, max_new_tokens=args.max_new_tokens)
    plan_json = gen(
        prompt, WorkoutPlan,
        max_new_tokens=min(args.max_new_tokens, 220),
        do_sample=False, temperature=0.0, top_k=0, top_p=1.0, num_beams=1
    )

    plan = WorkoutPlan.model_validate_json(plan_json)

    # save & pretty print
    with open(args.out, "w", encoding="utf-8") as f:
        f.write(plan_json)

    print(f"\n✅ Wrote {args.out}")
    print(f"\n{args.minutes}-min {args.band} plan:")
    for block in plan.blocks:
        print(f"\n### {block.name}")
        for it in block.items:
            print(f" - {it.id}: {it.sets} x {it.dose}  — {it.notes}")

if __name__ == "__main__":
    main()
