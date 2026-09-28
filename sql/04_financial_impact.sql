-- ============================================
-- SUNRISE BEHAVIORAL HEALTH CLINIC
-- Financial Impact Queries
-- Puts a dollar figure on the operational findings.
-- All queries run against staging tables, 2023 only.
-- ============================================
-- Key assumption: a prevented no-show becomes an attended
-- visit reimbursed at the average paid amount per ATTENDED
-- encounter. Dividing by attended visits (not all encounters)
-- matters: no-shows are billed at $0, so including them
-- understates what a kept appointment is worth.
-- ============================================

USE sunrise_bh_v4;


-- ============================================
-- IMPACT 1: Clinic-wide cost of no-shows (2023)
-- Result: 168 no-shows x $96.74 = ~$16,252
-- ============================================
WITH clinic_2023 AS (
    SELECT
        SUM(e.show_status = 'No Show')                        AS no_shows,
        SUM(b.amount_paid) / SUM(e.show_status = 'Show')      AS rev_per_attended
    FROM stg_encounters e
    JOIN stg_billing b ON e.encounter_id = b.encounter_id
    WHERE YEAR(e.visit_date) = 2023
)
SELECT
    no_shows,
    ROUND(rev_per_attended, 2)            AS rev_per_attended,
    ROUND(no_shows * rev_per_attended, 0) AS est_no_show_cost
FROM clinic_2023;


-- ============================================
-- IMPACT 2: Okafor — cost of no-shows and
-- recovery at the 20% benchmark (2023)
-- Result: 87 no-shows x $92.07 = ~$8,010 cost
--         (87 - 36 allowed at 20%) x $92.07 = ~$4,696 recoverable
-- ============================================
WITH okafor_2023 AS (
    SELECT
        COUNT(*)                                              AS scheduled,
        SUM(e.show_status = 'No Show')                        AS no_shows,
        SUM(b.amount_paid) / SUM(e.show_status = 'Show')      AS rev_per_attended
    FROM stg_encounters e
    JOIN stg_billing b ON e.encounter_id = b.encounter_id
    WHERE e.provider_id = 203
      AND YEAR(e.visit_date) = 2023
)
SELECT
    scheduled,
    no_shows,
    ROUND(rev_per_attended, 2)                                       AS rev_per_attended,
    ROUND(no_shows * rev_per_attended, 0)                            AS est_no_show_cost,
    ROUND((no_shows - scheduled * 0.20) * rev_per_attended, 0)       AS est_recovery_at_20pct
FROM okafor_2023;


-- ============================================
-- IMPACT 3: Provider Referral no-shows brought
-- down to the Hospital Discharge rate (16.44%, 2021-2024)
-- Result: (39 - 117 x 0.1644) x $95.47 = ~$1,887/year
-- ============================================
WITH provider_referral_2023 AS (
    SELECT
        COUNT(*)                                              AS scheduled,
        SUM(e.show_status = 'No Show')                        AS no_shows,
        SUM(b.amount_paid) / SUM(e.show_status = 'Show')      AS rev_per_attended
    FROM stg_patients p
    JOIN stg_encounters e ON p.patient_id = e.patient_id
    JOIN stg_billing b    ON e.encounter_id = b.encounter_id
    WHERE p.referral_source = 'Provider Referral'
      AND YEAR(e.visit_date) = 2023
)
SELECT
    scheduled,
    no_shows,
    ROUND(no_shows * 100.0 / scheduled, 2)                           AS no_show_rate_2023,
    ROUND((no_shows - scheduled * 0.1644) * rev_per_attended, 0)     AS est_recovery
FROM provider_referral_2023;


-- ============================================
-- IMPACT 4: Revenue concentration (2023)
-- Result: Vasquez $18,459 + Schwartz $12,487 = $30,946
--         = 52.6% of $58,818 total 2023 revenue
-- ============================================
WITH provider_rev AS (
    SELECT
        CONCAT(pr.first_name, ' ', pr.last_name) AS provider_name,
        SUM(b.amount_paid)                        AS revenue
    FROM providers pr
    JOIN stg_encounters e ON pr.provider_id = e.provider_id
    JOIN stg_billing b    ON e.encounter_id = b.encounter_id
    WHERE YEAR(e.visit_date) = 2023
    GROUP BY provider_name
),
ranked AS (
    SELECT
        provider_name,
        revenue,
        RANK() OVER (ORDER BY revenue DESC) AS rev_rank,
        SUM(revenue) OVER ()                AS total_revenue
    FROM provider_rev
)
SELECT
    SUM(revenue)                                         AS top2_revenue,
    MAX(total_revenue)                                   AS total_revenue,
    ROUND(SUM(revenue) * 100.0 / MAX(total_revenue), 1)  AS top2_pct
FROM ranked
WHERE rev_rank <= 2;


-- ============================================
-- CHECK: Do insurance-denial discharges show
-- lost revenue vs completed treatment?
-- Result: No. Denial patients averaged 13.6 encounters
-- vs 13.9 for Completed Treatment, with the same average
-- length of stay (~410 days). The synthetic data does not
-- support a dollar estimate for denials, so none is claimed.
-- ============================================
WITH patient_visits AS (
    SELECT
        p.patient_id,
        p.discharge_reason,
        DATEDIFF(p.discharge_date, p.intake_date) AS days_in_care,
        COUNT(e.encounter_id)                     AS encounters
    FROM stg_patients p
    JOIN stg_encounters e ON p.patient_id = e.patient_id
    WHERE p.discharge_reason IN ('Completed Treatment', 'Insurance Denial')
    GROUP BY p.patient_id, p.discharge_reason, days_in_care
)
SELECT
    discharge_reason,
    COUNT(*)                     AS patients,
    ROUND(AVG(encounters), 1)    AS avg_encounters,
    ROUND(AVG(days_in_care), 0)  AS avg_days_in_care
FROM patient_visits
GROUP BY discharge_reason;
