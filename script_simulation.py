import pandas as pd
import requests
import random
import uuid
from datetime import datetime
from pathlib import Path

# ── Configuration ─────────────────────────────────────────────
NB_TOURS      = 2000
OLLAMA_URL    = "http://localhost:11434/api/generate"
OLLAMA_MODEL  = "llama3.2"
OUTPUT_DIR    = Path("data/bronze")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# ── Matrice de gains ──────────────────────────────────────────
# (mon_choix, choix_adverse) → mon_gain
GAINS = {
    ("COOPERATE", "COOPERATE"): 3,
    ("COOPERATE", "DEFECT"):    0,
    ("DEFECT",    "COOPERATE"): 5,
    ("DEFECT",    "DEFECT"):    1,
}

# ── Stratégies codées ─────────────────────────────────────────
def always_cooperate(history):
    return "COOPERATE"

def always_defect(history):
    return "DEFECT"

def tit_for_tat(history):
    if not history:
        return "COOPERATE"
    return history[-1]["opponent_choice"]

def random_strategy(history):
    return random.choice(["COOPERATE", "DEFECT"])

def grim_trigger(history):
    for h in history:
        if h["opponent_choice"] == "DEFECT":
            return "DEFECT"
    return "COOPERATE"

def ollama_agent(history):
    """Agent IA via Ollama — joue en fonction de l'historique."""
    if not history:
        context = "C'est le premier tour."
    else:
        last = history[-1]
        context = (
            f"Tour précédent : tu as joué {last['my_choice']}, "
            f"l'adversaire a joué {last['opponent_choice']}. "
            f"Ton score cumulé : {sum(h['my_gain'] for h in history)}."
        )

    prompt = f"""Tu joues au dilemme du prisonnier itératif.
{context}
Réponds UNIQUEMENT par COOPERATE ou DEFECT, rien d'autre."""

    try:
        response = requests.post(OLLAMA_URL, json={
            "model":  OLLAMA_MODEL,
            "prompt": prompt,
            "stream": False
        }, timeout=30)
        text = response.json()["response"].strip().upper()
        if "DEFECT" in text:
            return "DEFECT"
        return "COOPERATE"
    except Exception as e:
        print(f"[OLLAMA ERROR] {e} → fallback COOPERATE")
        return "COOPERATE"

# ── Registre des stratégies ───────────────────────────────────
STRATEGIES = {
    "always_cooperate": always_cooperate,
    "always_defect":    always_defect,
    "tit_for_tat":      tit_for_tat,
    "random":           random_strategy,
    "grim_trigger":     grim_trigger,
    "ollama_agent":     ollama_agent,
}

# ── Simulation d'un match ─────────────────────────────────────
def simulate_match(strategy_a_name, strategy_b_name, run_id):
    strategy_a = STRATEGIES[strategy_a_name]
    strategy_b = STRATEGIES[strategy_b_name]

    history_a = []  # vu par A (my=A, opponent=B)
    history_b = []  # vu par B (my=B, opponent=A)
    rows = []

    for tour in range(1, NB_TOURS + 1):
        choice_a = strategy_a(history_a)
        choice_b = strategy_b(history_b)

        gain_a = GAINS[(choice_a, choice_b)]
        gain_b = GAINS[(choice_b, choice_a)]

        history_a.append({"my_choice": choice_a, "opponent_choice": choice_b, "my_gain": gain_a})
        history_b.append({"my_choice": choice_b, "opponent_choice": choice_a, "my_gain": gain_b})

        rows.append({
            "run_id":       run_id,
            "tour":         tour,
            "player_a":     strategy_a_name,
            "player_b":     strategy_b_name,
            "choice_a":     choice_a,
            "choice_b":     choice_b,
            "gain_a":       gain_a,
            "gain_b":       gain_b,
            "cumul_a":      sum(h["my_gain"] for h in history_a),
            "cumul_b":      sum(h["my_gain"] for h in history_b),
        })

        if tour % 200 == 0:
            print(f"  Tour {tour}/{NB_TOURS} — {strategy_a_name} vs {strategy_b_name}")

    return rows

# ── Tournoi complet ───────────────────────────────────────────
def run_tournament():
    run_id    = str(uuid.uuid4())[:8]
    timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    all_rows  = []

    matchups = [
        ("tit_for_tat",      "always_defect"),
        ("tit_for_tat",      "always_cooperate"),
        ("grim_trigger",     "random"),
        ("always_cooperate", "always_defect"),
        ("ollama_agent",     "tit_for_tat"),
        ("ollama_agent",     "always_defect"),
    ]

    print(f"\n=== TOURNOI {run_id} — {len(matchups)} matchs × {NB_TOURS} tours ===\n")

    for strategy_a, strategy_b in matchups:
        print(f"► {strategy_a} vs {strategy_b}")
        rows = simulate_match(strategy_a, strategy_b, run_id)
        all_rows.extend(rows)

    df = pd.DataFrame(all_rows)

    output_path = OUTPUT_DIR / f"tournament_{timestamp}_{run_id}.parquet"
    df.to_parquet(output_path, index=False)

    print(f"\n✓ Parquet généré : {output_path}")
    print(f"  {len(df)} lignes — {df['player_a'].nunique() + df['player_b'].nunique()} stratégies")
    return output_path

if __name__ == "__main__":
    run_tournament()