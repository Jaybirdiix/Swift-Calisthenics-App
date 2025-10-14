brew install ollama
ollama serve         # starts the local server (port 11434)
ollama pull llama3.1:8b
ollama run llama3.1:8b   # quick sanity check

python ollama_workout_planner.py \
  --exercises ../Data/exercises.json \
  --targets "Latissimus Dorsi,Biceps Brachii,Forearm Flexors" \
  --gate-by-skills --user-skills "Pull Up,Dip" \
  --n 6 --minutes 45 --model llama3:8b-instruct-q4_K_M \
  --format text


python ollama_workout_planner.py \
  --exercises ../Data/exercises.json \
  --targets "Anterior Deltoid,Pectoralis Major,Triceps Brachii" \
  --n 6 --minutes 45 --model llama3.2:3b-instruct \
  --format text
