-- gold_matchup_matrix.sql
-- Table de confrontation croisée : stratégie A vs B → scores moyens des deux côtés

with rounds as (
    select * from {{ ref('silver_rounds') }}
),

matchup as (
    select
        run_id,
        player_a,
        player_b,
        matchup_id,

        -- Scores finaux
        max(cumul_a)                                            as final_score_a,
        max(cumul_b)                                            as final_score_b,

        -- Taux de coopération
        round(avg(cooperated_a) * 100, 2)                      as cooperation_rate_a_pct,
        round(avg(cooperated_b) * 100, 2)                      as cooperation_rate_b_pct,

        -- Exploitations
        sum(exploitation_by_a)                                  as exploitations_by_a,
        sum(exploitation_by_b)                                  as exploitations_by_b,

        -- Vainqueur du match
        case
            when max(cumul_a) > max(cumul_b) then player_a
            when max(cumul_b) > max(cumul_a) then player_b
            else 'draw'
        end as match_winner

    from rounds
    group by run_id, player_a, player_b, matchup_id
)

select
    run_id,
    player_a,
    player_b,
    matchup_id,
    final_score_a,
    final_score_b,
    cooperation_rate_a_pct,
    cooperation_rate_b_pct,
    exploitations_by_a,
    exploitations_by_b,
    match_winner
from matchup
order by run_id asc, final_score_a desc