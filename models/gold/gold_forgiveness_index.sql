-- gold_forgiveness_index.sql
-- Fréquence de retour à la coopération après une trahison reçue
-- Un indice élevé = stratégie "pardonnante"

with rounds as (
    select * from {{ ref('silver_rounds') }}
),

-- On détecte les tours où un joueur reprend la coopération
-- après avoir reçu une trahison au tour précédent

lagged_a as (
    select
        run_id,
        player_a                                    as strategy,
        matchup_id,
        tour,
        choice_a,
        choice_b,
        cooperated_a,
        lag(choice_b) over (
            partition by run_id, player_a, player_b
            order by tour
        )                                           as prev_opponent_choice
    from rounds
),

lagged_b as (
    select
        run_id,
        player_b                                    as strategy,
        matchup_id,
        tour,
        choice_b,
        choice_a,
        cooperated_b                                as cooperated,
        lag(choice_a) over (
            partition by run_id, player_a, player_b
            order by tour
        )                                           as prev_opponent_choice
    from rounds
),

-- Forgiveness A : reprend COOPERATE après avoir reçu DEFECT
forgiveness_a as (
    select
        run_id,
        strategy,
        matchup_id,
        -- Tours où l'adversaire a trahi au tour précédent
        countif(prev_opponent_choice = 'DEFECT')                    as nb_betrayals_received,
        -- Parmi ces tours, combien de fois A recoopère
        countif(prev_opponent_choice = 'DEFECT' and choice_a = 'COOPERATE') as nb_forgiven
    from lagged_a
    where prev_opponent_choice is not null
    group by run_id, strategy, matchup_id
),

forgiveness_b as (
    select
        run_id,
        strategy,
        matchup_id,
        countif(prev_opponent_choice = 'DEFECT')                    as nb_betrayals_received,
        countif(prev_opponent_choice = 'DEFECT' and choice_b = 'COOPERATE') as nb_forgiven
    from lagged_b
    where prev_opponent_choice is not null
    group by run_id, strategy, matchup_id
),

combined as (
    select * from forgiveness_a
    union all
    select * from forgiveness_b
),

aggregated as (
    select
        run_id,
        strategy,
        sum(nb_betrayals_received)                                  as total_betrayals_received,
        sum(nb_forgiven)                                            as total_forgiven,
        round(
            safe_divide(sum(nb_forgiven), sum(nb_betrayals_received)) * 100,
            2
        )                                                           as forgiveness_index_pct
    from combined
    group by run_id, strategy
)

select
    run_id,
    strategy,
    total_betrayals_received,
    total_forgiven,
    forgiveness_index_pct,
    rank() over (partition by run_id order by forgiveness_index_pct desc) as forgiveness_rank
from aggregated
order by forgiveness_rank