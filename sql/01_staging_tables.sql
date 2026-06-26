-- ============================================
-- SUNRISE BEHAVIORAL HEALTH CLINIC
-- Staging Tables — Portfolio Project 1
-- Run this AFTER loading the raw dataset
-- (sunrise_behavioral_health_v4_mysql.sql)
-- ============================================

USE sunrise_bh_v4;

-- Drop staging tables if they already exist
DROP TABLE IF EXISTS stg_billing;
DROP TABLE IF EXISTS stg_encounters;
DROP TABLE IF EXISTS stg_patients;

-- ============================================
-- STG_PATIENTS
-- Transformation applied:
-- City names standardized using UPPER(TRIM(REPLACE()))
-- to fix mixed case, trailing spaces, and double spaces
-- Result: 150 rows (same as raw, no records excluded)
-- ============================================
CREATE TABLE stg_patients AS
SELECT
    patient_id,
    first_name,
    last_name,
    date_of_birth,
    gender,
    UPPER(TRIM(REPLACE(city, '  ', ' '))) AS city,
    insurance_type,
    referral_source,
    intake_date,
    discharge_date,
    discharge_reason
FROM patients;

-- ============================================
-- STG_ENCOUNTERS
-- Transformations applied:
-- 1. Remove NULL provider_id (10 records removed)
--    Root cause: staff transitions, encounters logged
--    before provider assignment
-- 2. Remove visit_date before patient intake_date (5 records removed)
--    Root cause: data entry errors
-- 3. Remove duplicate records, keep MIN encounter_id (4 duplicates removed)
--    Root cause: EMR system import errors
-- Result: 2,214 rows (down from 2,233 raw)
-- ============================================
CREATE TABLE stg_encounters AS
SELECT
    e.encounter_id,
    e.patient_id,
    e.provider_id,
    e.visit_date,
    e.visit_type,
    e.department,
    e.duration_minutes,
    e.show_status
FROM encounters e
JOIN patients p ON e.patient_id = p.patient_id
WHERE e.provider_id IS NOT NULL
AND e.visit_date >= p.intake_date
AND e.encounter_id IN (
    SELECT MIN(encounter_id)
    FROM encounters
    GROUP BY patient_id, provider_id, visit_date
);

-- ============================================
-- STG_BILLING
-- Transformations applied:
-- 1. Remove records where amount_paid > amount_billed (6 records removed)
--    Root cause: data entry errors or system calculation bugs
--    Physically impossible in real healthcare billing
-- 2. Remove orphaned billing records (5 records removed)
--    Root cause: partial data migration, billing records
--    with no matching encounter in the encounters table
-- Result: 2,223 rows (down from 2,234 raw)
-- ============================================
CREATE TABLE stg_billing AS
SELECT
    b.billing_id,
    b.encounter_id,
    b.insurance_type,
    b.amount_billed,
    b.amount_paid,
    b.payment_status
FROM billing b
WHERE b.amount_paid <= b.amount_billed
AND b.encounter_id IN (SELECT encounter_id FROM encounters);

-- ============================================
-- VERIFICATION QUERIES
-- Run these to confirm staging tables loaded correctly
-- ============================================
SELECT 'stg_patients' AS table_name, COUNT(*) AS row_count FROM stg_patients
UNION ALL
SELECT 'stg_encounters', COUNT(*) FROM stg_encounters
UNION ALL
SELECT 'stg_billing', COUNT(*) FROM stg_billing;

-- Expected results:
-- stg_patients:  150
-- stg_encounters: 2214
-- stg_billing:   2223
