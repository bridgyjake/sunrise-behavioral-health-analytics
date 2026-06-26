-- ============================================
-- SUNRISE BEHAVIORAL HEALTH CLINIC
-- Analytical Queries — Portfolio Project 1
-- All queries run against staging tables
-- ============================================
-- NOTE: All patient data is synthetic.
-- In production, patient PII would be replaced
-- with de-identified IDs per HIPAA Safe Harbor.
-- ============================================


-- ============================================
-- QUERY 1: Year-Over-Year Clinic Performance
-- Business Question: How did encounter volume
-- and revenue trend from 2021-2024?
-- ============================================
SELECT
    YEAR(visit_date) AS year,
    COUNT(e.encounter_id) AS total_encounters,
    SUM(amount_paid) AS total_revenue,
    ROUND(AVG(amount_paid), 1) AS avg_revenue_per_encounter
FROM stg_encounters e
JOIN stg_billing b ON e.encounter_id = b.encounter_id
GROUP BY year
ORDER BY year;

-- Finding: 2022 was the peak year ($79,637 revenue, 936 encounters).
-- 2023 showed a 26% revenue decline and 17% encounter volume decline.


-- ============================================
-- QUERY 2: Revenue by Insurance Type by Year
-- Business Question: Which payer types drove
-- the 2022-2023 revenue decline?
-- ============================================
SELECT
    YEAR(visit_date) AS year,
    b.insurance_type,
    SUM(amount_paid) AS total_revenue
FROM stg_encounters e
JOIN stg_billing b ON e.encounter_id = b.encounter_id
GROUP BY year, b.insurance_type
ORDER BY year, total_revenue DESC;

-- Finding: Private insurance declined $12,323 (33.1%) from 2022-2023,
-- the largest absolute loss. Since Private pays the most per encounter,
-- losing Private patients amplified the overall revenue impact.


-- ============================================
-- QUERY 3: Provider Performance Scorecard
-- Business Question: How do providers compare
-- on caseload, revenue, and no-show rates?
-- ============================================
SELECT
    CONCAT(p.first_name, ' ', p.last_name) AS provider_name,
    p.role,
    COUNT(e.encounter_id) AS total_encounters,
    SUM(b.amount_paid) AS total_revenue,
    ROUND(SUM(b.amount_paid) / COUNT(e.encounter_id), 2) AS revenue_per_encounter,
    ROUND(COUNT(CASE WHEN e.show_status = 'No Show' THEN 1 END) * 100.0
        / COUNT(e.encounter_id), 1) AS no_show_rate
FROM providers p
JOIN stg_encounters e ON p.provider_id = e.provider_id
JOIN stg_billing b ON e.encounter_id = b.encounter_id
WHERE YEAR(e.visit_date) = 2023
GROUP BY provider_name, p.role
ORDER BY total_revenue DESC;

-- Finding: Michael Okafor has the highest no-show rate (48.3%) AND
-- lowest revenue per encounter ($47.57) — two compounding problems.
-- Schwartz and Vasquez generate 62.6% of total 2023 provider revenue.


-- ============================================
-- QUERY 4: Patient Retention by Year
-- Business Question: Is the clinic retaining
-- existing patients year-over-year?
-- ============================================
WITH patient_first_year AS (
    SELECT
        p.patient_id,
        MIN(YEAR(e.visit_date)) AS first_encounter_year
    FROM stg_patients p
    JOIN stg_encounters e ON p.patient_id = e.patient_id
    GROUP BY p.patient_id
),
yearly_activity AS (
    SELECT DISTINCT
        p.patient_id,
        YEAR(e.visit_date) AS active_year
    FROM stg_patients p
    JOIN stg_encounters e ON p.patient_id = e.patient_id
)
SELECT
    ya.active_year AS year,
    COUNT(CASE WHEN ya.active_year = pfy.first_encounter_year THEN 1 END) AS new_patients,
    COUNT(CASE WHEN ya.active_year > pfy.first_encounter_year THEN 1 END) AS returning_patients,
    ROUND(COUNT(CASE WHEN ya.active_year > pfy.first_encounter_year THEN 1 END) * 100.0
        / COUNT(ya.patient_id), 1) AS retention_rate
FROM yearly_activity ya
JOIN patient_first_year pfy ON ya.patient_id = pfy.patient_id
GROUP BY ya.active_year
ORDER BY ya.active_year;

-- Finding: Retention rate improved from 30.8% (2022) to 59.6% (2023),
-- suggesting the clinic retained existing patients even as new patient
-- acquisition slowed significantly.


-- ============================================
-- QUERY 5: Top 10 Patients by Encounter Volume
-- Business Question: Who are the highest
-- utilizers across all years?
-- ============================================
SELECT
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    p.insurance_type,
    COUNT(e.encounter_id) AS total_encounters,
    SUM(b.amount_paid) AS total_revenue,
    ROUND(COUNT(CASE WHEN e.show_status = 'No Show' THEN 1 END) * 100.0
        / COUNT(e.encounter_id), 1) AS no_show_rate
FROM stg_patients p
JOIN stg_encounters e ON p.patient_id = e.patient_id
JOIN stg_billing b ON e.encounter_id = b.encounter_id
GROUP BY patient_name, p.insurance_type
ORDER BY total_encounters DESC
LIMIT 10;

-- Finding: High-volume Medi-Cal patients generate 2-3x less revenue
-- than comparable Private insurance patients despite similar encounter counts.


-- ============================================
-- QUERY 6: No-Show Rate by Referral Source
-- Business Question: Which referral channels
-- produce the most engaged patients?
-- ============================================
SELECT
    p.referral_source,
    ROUND(COUNT(CASE WHEN e.show_status = 'No Show' THEN 1 END) * 100.0
        / COUNT(e.encounter_id), 1) AS no_show_rate,
    COUNT(DISTINCT p.patient_id) AS total_patients
FROM stg_patients p
JOIN stg_encounters e ON p.patient_id = e.patient_id
GROUP BY p.referral_source
ORDER BY no_show_rate DESC;

-- Finding: Hospital Discharge referrals have the lowest no-show rate (16.4%).
-- Provider Referrals have the highest (28.3%), suggesting differentiated
-- outreach protocols by referral channel could improve attendance rates.


-- ============================================
-- QUERY 7: Average Days Between Encounters
-- Business Question: How consistent is each
-- provider's scheduling cadence in 2023?
-- ============================================
WITH provider_visit_gaps AS (
    SELECT
        CONCAT(pr.first_name, ' ', pr.last_name) AS provider_name,
        e.visit_date,
        LEAD(e.visit_date) OVER (
            PARTITION BY pr.provider_id
            ORDER BY e.visit_date
        ) AS next_visit
    FROM providers pr
    JOIN stg_encounters e ON pr.provider_id = e.provider_id
    WHERE YEAR(e.visit_date) = 2023
)
SELECT
    provider_name,
    ROUND(AVG(DATEDIFF(next_visit, visit_date)), 1) AS avg_days_between_visits
FROM provider_visit_gaps
WHERE next_visit IS NOT NULL
GROUP BY provider_name
ORDER BY avg_days_between_visits;

-- Finding: Elena Vasquez averages 1.6 days between encounters (highest density).
-- Priya Nair averages 17.7 days (specialist, lower visit frequency expected).


-- ============================================
-- QUERY 8: Discharge Reason Breakdown
-- Business Question: Why are patients leaving —
-- clinical completion or external factors?
-- ============================================
SELECT
    COALESCE(discharge_reason, 'Still Active') AS discharge_status,
    COUNT(patient_id) AS patient_count,
    ROUND(COUNT(patient_id) * 100.0 / (SELECT COUNT(*) FROM stg_patients), 1) AS pct_of_total
FROM stg_patients
GROUP BY discharge_reason
ORDER BY patient_count DESC;

-- Finding: Insurance Denial accounts for 23.3% of all discharges —
-- the second leading reason after treatment completion (44.2%).
-- This warrants review of medical necessity documentation practices.


-- ============================================
-- QUERY 9: Monthly Revenue Trend with Running Total
-- Business Question: How did revenue accumulate
-- month-by-month throughout 2023?
-- ============================================
WITH monthly_revenue AS (
    SELECT
        MONTH(e.visit_date) AS month,
        SUM(b.amount_paid) AS total_revenue
    FROM stg_encounters e
    JOIN stg_billing b ON e.encounter_id = b.encounter_id
    WHERE YEAR(e.visit_date) = 2023
    GROUP BY month
)
SELECT
    month,
    total_revenue,
    SUM(total_revenue) OVER (ORDER BY month) AS running_total
FROM monthly_revenue
ORDER BY month;

-- Finding: The clinic generated more revenue in the first 5 months
-- ($31,414) than the last 7 months ($27,404) of 2023.


-- ============================================
-- QUERY 10: Revenue by City
-- Business Question: Do revenue patterns differ
-- across service areas?
-- ============================================
SELECT
    p.city,
    COUNT(DISTINCT p.patient_id) AS patient_count,
    SUM(b.amount_paid) AS total_revenue,
    ROUND(AVG(b.amount_paid), 1) AS avg_revenue_per_encounter
FROM stg_patients p
JOIN stg_encounters e ON p.patient_id = e.patient_id
JOIN stg_billing b ON e.encounter_id = b.encounter_id
GROUP BY p.city
ORDER BY avg_revenue_per_encounter DESC;

-- Finding: Thousand Oaks generates 34% higher average revenue per encounter
-- than Oxnard ($101.20 vs $75.40), reflecting payer mix differences
-- across service areas.


-- ============================================
-- QUERY 11: Revenue and Patient Volume by ICD Code
-- Business Question: Which diagnoses drive
-- the most revenue and at what rate?
-- ============================================
SELECT
    d.icd_code,
    COUNT(DISTINCT d.patient_id) AS patient_count,
    SUM(b.amount_paid) AS total_revenue,
    ROUND(AVG(b.amount_paid), 1) AS avg_revenue_per_encounter
FROM diagnoses d
JOIN stg_encounters e ON d.patient_id = e.patient_id
JOIN stg_billing b ON e.encounter_id = b.encounter_id
GROUP BY d.icd_code
ORDER BY total_revenue DESC;

-- Finding: Severe mood disorders (F32.2, F33.0) generate $93-95 per encounter
-- while substance use disorders (F10.20, F11.20) generate only $59-65.
-- This reimbursement gap directly impacts clinics with high substance use caseloads.


-- ============================================
-- QUERY 12: Month-Over-Month Revenue Change
-- Business Question: Which months in 2023
-- showed revenue growth vs decline?
-- ============================================
WITH monthly_revenue AS (
    SELECT
        MONTH(e.visit_date) AS month,
        SUM(b.amount_paid) AS total_revenue
    FROM stg_encounters e
    JOIN stg_billing b ON e.encounter_id = b.encounter_id
    WHERE YEAR(e.visit_date) = 2023
    GROUP BY month
),
revenue_change AS (
    SELECT
        month,
        total_revenue,
        total_revenue - LAG(total_revenue) OVER (ORDER BY month) AS monthly_change
    FROM monthly_revenue
)
SELECT
    month,
    total_revenue,
    monthly_change,
    CASE
        WHEN monthly_change > 0 THEN 'Increase'
        WHEN monthly_change < 0 THEN 'Decrease'
        ELSE 'No Change'
    END AS trend
FROM revenue_change
ORDER BY month;

-- Finding: 8 of 12 months showed revenue decline in 2023.
-- August had the steepest single-month drop (-$2,026).
-- Only March, July, and October showed recovery.


-- ============================================
-- QUERY 13: Patient Risk Stratification
-- Business Question: Which patients require
-- immediate outreach or care coordination?
-- Note: All patients show High Risk due to
-- dataset ending April 2024; thresholds are
-- calibrated for production use with current data.
-- ============================================
WITH patient_stats AS (
    SELECT
        CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
        p.insurance_type,
        COUNT(e.encounter_id) AS total_encounters,
        MAX(e.visit_date) AS last_visit,
        ROUND(COUNT(CASE WHEN e.show_status = 'No Show' THEN 1 END) * 100.0
            / COUNT(e.encounter_id), 1) AS no_show_rate
    FROM stg_patients p
    JOIN stg_encounters e ON p.patient_id = e.patient_id
    GROUP BY p.patient_id, p.first_name, p.last_name, p.insurance_type
),
patient_risk AS (
    SELECT
        patient_name,
        insurance_type,
        total_encounters,
        DATEDIFF(NOW(), last_visit) AS days_since_last_visit,
        no_show_rate
    FROM patient_stats
)
SELECT
    patient_name,
    insurance_type,
    total_encounters,
    days_since_last_visit,
    no_show_rate,
    CASE
        WHEN no_show_rate > 30 OR days_since_last_visit > 500 THEN 'High Risk'
        WHEN no_show_rate > 15 OR days_since_last_visit > 300 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END AS risk_classification
FROM patient_risk
ORDER BY
    CASE
        WHEN no_show_rate > 30 OR days_since_last_visit > 500 THEN 1
        WHEN no_show_rate > 15 OR days_since_last_visit > 300 THEN 2
        ELSE 3
    END,
    days_since_last_visit DESC;

-- ============================================
-- HIGH UTILIZER IDENTIFICATION
-- Bonus Query: Patients more than 1.5 standard
-- deviations above average encounter count
-- ============================================
WITH patient_encounters AS (
    SELECT
        p.patient_id,
        CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
        p.insurance_type,
        COUNT(e.encounter_id) AS total_encounters
    FROM stg_patients p
    JOIN stg_encounters e ON p.patient_id = e.patient_id
    GROUP BY p.patient_id, p.first_name, p.last_name, p.insurance_type
),
clinic_stats AS (
    SELECT
        AVG(total_encounters) AS avg_encounters,
        STDDEV(total_encounters) AS stddev_encounters
    FROM patient_encounters
)
SELECT
    pe.patient_name,
    pe.insurance_type,
    pe.total_encounters,
    MIN(d.icd_code) AS primary_diagnosis,
    ROUND(cs.avg_encounters, 1) AS clinic_avg,
    ROUND(cs.avg_encounters + (1.5 * cs.stddev_encounters), 1) AS high_utilizer_threshold
FROM patient_encounters pe
JOIN diagnoses d ON pe.patient_id = d.patient_id
CROSS JOIN clinic_stats cs
WHERE pe.total_encounters > cs.avg_encounters + (1.5 * cs.stddev_encounters)
GROUP BY pe.patient_name, pe.insurance_type, pe.total_encounters,
         cs.avg_encounters, cs.stddev_encounters
ORDER BY pe.total_encounters DESC;

-- Finding: 17 high utilizers identified. 47% are Medi-Cal patients —
-- the clinic's most resource-intensive patients are also its least
-- financially sustainable, representing a structural cost-revenue imbalance.
