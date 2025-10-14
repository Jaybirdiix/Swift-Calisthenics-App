# from pydantic import BaseModel
# from enum import Enum

# import os; os.environ["PYTORCH_ENABLE_MPS_FALLBACK"] = "1"
# import torch; device = "cpu"


# class Rating(Enum):
#     poor = 1
#     fair = 2
#     good = 3
#     excellent = 4

# class ProductReview(BaseModel):
#     rating: Rating
#     pros: list[str]
#     cons: list[str]
#     summary: str

# import torch
# import outlines
# from transformers import AutoTokenizer, AutoModelForCausalLM

# MODEL_NAME = "microsoft/Phi-3-mini-4k-instruct"
# # device = "mps" if torch.backends.mps.is_available() else "cpu"

# tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
# hf_model = AutoModelForCausalLM.from_pretrained(
#     MODEL_NAME,
#     # torch_dytpe?
#     dtype=torch.float16 if device == "mps" else "auto",
#     low_cpu_mem_usage=True,
#     attn_implementation="eager",  # safer on MPS
# )

# if device == "mps":
#     hf_model.to(device)

# model = outlines.from_transformers(hf_model, tokenizer)

# review_json = model(
#     "Review: The XPS 13 has great battery life and a stunning display, but it runs hot and the webcam is poor quality.",
#     ProductReview,
#     max_new_tokens=200,
# )

# review = ProductReview.model_validate_json(review_json)
# print(f"Rating: {review.rating.name}")
# print(f"Pros: {review.pros}")
# print(f"Summary: {review.summary}")

# # python3.11 -m venv swift_ai
# # source swift_ai/bin/activate
# # pip install torch transformers outlines


from pydantic import BaseModel
from enum import Enum

# ----- must come BEFORE torch/transformers/outlines imports -----
import os
os.environ["TORCH_COMPILE_DISABLE"] = "1"
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import torch
torch._dynamo.config.suppress_errors = True

def _no_compile(*args, **kwargs):
    if args and callable(args[0]):
        return args[0]
    def _decorator(fn):
        return fn
    return _decorator

torch.compile = _no_compile
# ----- end no-op compile shim -----

class Rating(Enum):
    poor = 1
    fair = 2
    good = 3
    excellent = 4

class ProductReview(BaseModel):
    rating: Rating
    pros: list[str]
    cons: list[str]
    summary: str

import outlines
from transformers import AutoTokenizer, AutoModelForCausalLM

MODEL_NAME = "microsoft/Phi-3-mini-4k-instruct"
device = "cpu"

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token

hf_model = AutoModelForCausalLM.from_pretrained(
    MODEL_NAME,
    dtype=torch.float16 if device == "mps" else "auto",
    low_cpu_mem_usage=True,
    attn_implementation="eager",
)
if device == "mps":
    # torch.backends.mps.enable_mps_fallback(True)
    hf_model.to(device)

model = outlines.from_transformers(hf_model, tokenizer)

review_json = model(
    "Review: The XPS 13 has great battery life and a stunning display, but it runs hot and the webcam is poor quality.",
    ProductReview,
    max_new_tokens=200,
)
review = ProductReview.model_validate_json(review_json)
print(f"Rating: {review.rating.name}")
print(f"Pros: {review.pros}")
print(f"Summary: {review.summary}")
