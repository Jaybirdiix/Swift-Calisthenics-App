brew install ollama
ollama serve         # starts the local server (port 11434)
ollama pull llama3.1:8b
ollama run llama3.1:8b   # quick sanity check

python ollama_workout_planner.py \
  --exercises ..//exercises.json \
  --targets "Latissimus Dorsi,Biceps Brachii,Forearm Flexors" \
  --gate-by-skills --user-skills "Pull Up,Dip" \
  --n 6 --minutes 45 --model llama3.1:8b
