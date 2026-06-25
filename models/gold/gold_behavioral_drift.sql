-- gold_behavioral_drift.sql
-- Évolution du taux de coopération par tranche de 100 tours
-- Permet de détecter les bascules comportementales

with rounds as (
    select * from {{ ref('silver_rounds') }}
),

-- Côté A
drift_a as (
    select
        run_id,
        player_a                                            as strategy,
        player_b                                            as opponent,
        matchup_id,
        tour_bucket,
        round(avg(cooperated_a) * 100, 2)                  as cooperation_rate_pct,
        sum(gain_a)                                         as total_gain,
        sum(exploitation_by_a)                              as exploitations_done,
        sum(exploitation_by_b)                              as exploitations_received
    from rounds
    group by run_id, player_a, player_b, matchup_id, tour_bucket
),

-- Côté B
drift_b as (
    select
        run_id,
        player_b                                            as strategy,
        player_a                                            as opponent,
        matchup_id,
        tour_bucket,
        round(avg(cooperated_b) * 100, 2)                  as cooperation_rate_pct,
        sum(gain_b)                                         as total_gain,
        sum(exploitation_by_b)                              as exploitations_done,
        sum(exploitation_by_a)                              as exploitations_received
    from rounds
    group by run_id, player_b, player_a, matchup_id, tour_bucket
),

combined as (
    select * from drift_a
    union all
    select * from drift_b
)

select
    run_id,
    strategy,
    opponent,
    matchup_id,
    tour_bucket,
    cooperation_rate_pct,
    total_gain,
    exploitations_done,
    exploitations_received
from combined
order by strategy, matchup_id, tour_bucket