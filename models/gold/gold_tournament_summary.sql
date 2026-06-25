-- gold_tournament_summary.sql
-- Classement final des stratégies : score total, taux de coopération, victoires/défaites

with rounds as (
    select * from {{ ref('silver_rounds') }}
),

-- Vue du côté joueur A
player_a_stats as (
    select
        run_id,
        player_a                            as strategy,
        matchup_id,
        sum(gain_a)                         as total_gain,
        count(*)                            as total_tours,
        sum(cooperated_a)                   as nb_cooperations,
        sum(defected_a)                     as nb_defections,
        sum(exploitation_by_a)              as nb_exploitations,
        max(cumul_a)                        as final_score
    from rounds
    group by run_id, player_a, matchup_id
),

-- Vue du côté joueur B
player_b_stats as (
    select
        run_id,
        player_b                            as strategy,
        matchup_id,
        sum(gain_b)                         as total_gain,
        count(*)                            as total_tours,
        sum(cooperated_b)                   as nb_cooperations,
        sum(defected_b)                     as nb_defections,
        sum(exploitation_by_b)              as nb_exploitations,
        max(cumul_b)                        as final_score
    from rounds
    group by run_id, player_b, matchup_id
),

combined as (
    select * from player_a_stats
    union all
    select * from player_b_stats
),

aggregated as (
    select
        run_id,
        strategy,
        sum(final_score)                                        as total_score,
        sum(nb_cooperations)                                    as total_cooperations,
        sum(nb_defections)                                      as total_defections,
        sum(nb_exploitations)                                   as total_exploitations,
        round(sum(nb_cooperations) / sum(total_tours) * 100, 2) as cooperation_rate_pct,
        count(distinct matchup_id)                              as nb_matchups
    from combined
    group by run_id, strategy
)

select
    run_id,
    strategy,
    total_score,
    cooperation_rate_pct,
    total_cooperations,
    total_defections,
    total_exploitations,
    nb_matchups,
    rank() over (partition by run_id order by total_score desc) as ranking
from aggregated
order by ranking