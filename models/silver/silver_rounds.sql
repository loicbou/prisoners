with source as (
    select * from {{ source('prisoners', 'tournament_bronze') }}
),

enriched as (
    select
        run_id,
        tour,
        player_a,
        player_b,

        -- Choix nettoyés
        choice_a,
        choice_b,
        gain_a,
        gain_b,
        cumul_a,
        cumul_b,

        -- Clé de match pour regroupements
        concat(player_a, '_vs_', player_b) as matchup_id,

        -- Indicateurs booléens
        case when choice_a = 'COOPERATE' then 1 else 0 end as cooperated_a,
        case when choice_b = 'COOPERATE' then 1 else 0 end as cooperated_b,
        case when choice_a = 'DEFECT'    then 1 else 0 end as defected_a,
        case when choice_b = 'DEFECT'    then 1 else 0 end as defected_b,

        -- Coopération mutuelle
        case when choice_a = 'COOPERATE' and choice_b = 'COOPERATE' then 1 else 0 end as mutual_cooperation,

        -- Trahison mutuelle
        case when choice_a = 'DEFECT' and choice_b = 'DEFECT' then 1 else 0 end as mutual_defection,

        -- Exploitation (A trahit, B coopère)
        case when choice_a = 'DEFECT' and choice_b = 'COOPERATE' then 1 else 0 end as exploitation_by_a,
        case when choice_b = 'DEFECT' and choice_a = 'COOPERATE' then 1 else 0 end as exploitation_by_b,

        -- Tranche de tours pour behavioral_drift (100 tours par tranche)
        cast(ceil(tour / 100.0) * 100 as int64) as tour_bucket,

        -- Qui gagne ce tour
        case
            when gain_a > gain_b  then player_a
            when gain_b > gain_a  then player_b
            else 'draw'
        end as tour_winner

    from source
)

select * from enriched