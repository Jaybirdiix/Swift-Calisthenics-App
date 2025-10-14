# from pydantic import BaseModel
# from enum import Enum

# # ----- must come BEFORE torch/transformers/outlines imports -----
# import os
# os.environ["TORCH_COMPILE_DISABLE"] = "1"
# os.environ["TOKENIZERS_PARALLELISM"] = "false"

# import torch
# torch._dynamo.config.suppress_errors = True

# def _no_compile(*args, **kwargs):
#     if args and callable(args[0]):
#         return args[0]
#     def _decorator(fn):
#         return fn
#     return _decorator

# torch.compile = _no_compile

# import outlines
# from transformers import AutoTokenizer, AutoModelForCausalLM

# MODEL_NAME = "microsoft/Phi-3-mini-4k-instruct"
# device = "mps" if torch.backends.mps.is_available() else "cpu"

# tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
# if tokenizer.pad_token is None:
#     tokenizer.pad_token = tokenizer.eos_token

# hf_model = AutoModelForCausalLM.from_pretrained(
#     MODEL_NAME,
#     dtype=torch.float16 if device == "mps" else "auto",
#     low_cpu_mem_usage=True,
#     attn_implementation="eager",
# )
# if device == "mps":
#     # torch.backends.mps.enable_mps_fallback(True)
#     hf_model.to(device)


# model = outlines.from_transformers(hf_model, tokenizer)

# # -----------------------------------------------------------

# class Rating(Enum):
#     easy = 1
#     medium = 2
#     hard = 3
#     really_hard = 4

# class ProductReview(BaseModel):
#     rating: Rating
#     # pros: list[str]
#     # cons: list[str]
#     # summary: str

# review_json = model(
#     # "Review: The XPS 13 has great battery life and a stunning display, but it runs hot and the webcam is poor quality.",
#     "Exercise difficulty of the handstand push-up",
#     ProductReview,
#     max_new_tokens=200,
# )
# review = ProductReview.model_validate_json(review_json)
# print('tada')
# print(f"Rating: {review.rating.name}")
# # print(f"Pros: {review.pros}")
# # print(f"Summary: {review.summary}")

import json, os, torch
from pydantic import BaseModel
from typing import List, Literal, Optional
import outlines
from transformers import AutoTokenizer, AutoModelForCausalLM

# --- environment & torch.compile no-op, as we did before ---
os.environ.setdefault("TORCH_COMPILE_DISABLE", "1")
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")

def _no_compile(*a, **k):
    if a and callable(a[0]): return a[0]
    def _decorator(fn): return fn
    return _decorator

torch.compile = _no_compile

# --- model choice (see section B for alternatives) ---
MODEL_NAME = "microsoft/Phi-3-mini-4k-instruct"   # fast, small, works on Mac
device = "mps" if hasattr(torch.backends, "mps") and torch.backends.mps.is_available() else "cpu"

tok = AutoTokenizer.from_pretrained(MODEL_NAME)
if tok.pad_token is None:
    tok.pad_token = tok.eos_token

hf = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    dtype=torch.float16 if device == "mps" else "auto",
    attn_implementation="eager",
    low_cpu_mem_usage=True,
)
if device == "mps":
    hf.to(device)

model = outlines.from_transformers(hf, tok)

# --- your exercise DB (paste your JSON as a string) ---
EX_JSON = r'''mini_exercises.json'''
exercises = json.loads(EX_JSON)

# --- Response schema ---
class Block(BaseModel):
    block_name: Literal["warmup","skill","strength","accessory","cooldown"]
    items: List[dict]   # each item will be {name, sets, reps_or_time, notes}

class WorkoutPlan(BaseModel):
    title: str
    duration_minutes: int
    focus: List[str]               # e.g., ["push","core"]
    difficulty_target: Literal["beginner","intermediate","advanced"]
    blocks: List[Block]
    total_estimated_volume: Optional[str]  # free-form

# --- Prompt builder ---
def build_prompt(goal, minutes, difficulty, rules=None, exclusions=None):
    return f"""
You are a calisthenics coach. Construct a {minutes}-minute workout as JSON only (no extra text).

Constraints:
- Difficulty target: {difficulty}
- Goal: {goal}
- Pick from ONLY the following exercises JSON (field names: name, description, difficulty, muscles, reps, requiredSkills):
{json.dumps(exercises, indent=2)}
- Prefer items with difficulty <= 6 for intermediate; use <= 4 for beginner; <= 8 for advanced.
- Respect skill prerequisites: do not select items whose requiredSkills are unmet unless they appear earlier in the plan.
- Include a 'warmup' and 'cooldown'.
- If an exercise has 'reps' like 'Arch Hold – 20s / 30s / 40s', pick one progression level that matches the target difficulty.
{f"- Additional rules: {rules}" if rules else ""}
{f"- Exclusions: {exclusions}" if exclusions else ""}

Return a JSON that validates against this schema:
{WorkoutPlan.model_json_schema()}
"""

prompt = build_prompt(
    goal="push strength + planche accessory emphasis",
    minutes=45,
    difficulty="intermediate",
    rules="Alternate push and core where possible; cap any isometric holds at 30s.",
    exclusions="Avoid anything requiring rings if none are mentioned."
)

# --- Generate structured JSON ---
plan_json = model(prompt, WorkoutPlan, max_new_tokens=800)
plan = WorkoutPlan.model_validate_json(plan_json)

print(plan.title, plan.duration_minutes, plan.difficulty_target)
for b in plan.blocks:
    print("##", b.block_name)
    for it in b.items:
        print("-", it)
