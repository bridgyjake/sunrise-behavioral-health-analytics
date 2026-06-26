-- ============================================
-- SUNRISE BEHAVIORAL HEALTH CLINIC - v4
-- Data Quality Assessment Queries
-- Portfolio Project 1 - Data Validation Section
-- ============================================
-- These queries identify and document known data quality issues
-- in the raw dataset. Raw data is preserved; issues are filtered
-- out in analytical queries rather than deleted from source.
-- ============================================


-- ============================================
-- ISSUE 1: NULL provider_id in encounters
-- Root cause: Staff transition periods where encounters were
-- logged before provider assignment was completed.
-- Impact: These records are excluded from all provider-level
-- analysis (caseload, revenue, no-show rate).
-- Count: 10 records
-- ============================================
SELECT 
    encounter_id,
    patient_id,
    visit_date,
    visit_type
FROM encounters
WHERE provider_id IS NULL;

-- Remediation: Flag for administrative review.
-- Exclude from provider-level analysis with:
-- WHERE provider_id IS NOT NULL


-- ============================================
-- ISSUE 2: visit_date before patient intake_date
-- Root cause: Data entry errors where visit dates were
-- logged incorrectly (e.g., wrong month/year).
-- Impact: Inflates early engagement metrics, distorts
-- longitudinal analysis.
-- Count: 5 records
-- ============================================
SELECT 
    CONCAT(p.first_name, ' ', p.last_name) AS patient_name,
    e.encounter_id,
    e.visit_date,
    p.intake_date
FROM patients p
JOIN encounters e ON p.patient_id = e.patient_id
WHERE e.visit_date < p.intake_date;

-- Remediation: Exclude from date-range analysis with:
-- AND e.visit_date >= p.intake_date


-- ============================================
-- ISSUE 3: Duplicate encounter records
-- Root cause: System import errors during EMR migration
-- where the same encounter was imported twice with
-- different encounter IDs.
-- Impact: Inflates encounter counts, revenue totals,
-- and no-show rates.
-- Count: 4 duplicate groups (8 total records)
-- ============================================
SELECT 
    patient_id,
    provider_id,
    visit_date,
    COUNT(*) AS occurrence_count
FROM encounters
GROUP BY patient_id, provider_id, visit_date
HAVING COUNT(*) > 1;

-- Remediation: Retain lowest encounter_id as canonical record.
-- Exclude duplicates with:
-- WHERE encounter_id IN (
--     SELECT MIN(encounter_id)
--     FROM encounters
--     GROUP BY patient_id, provider_id, visit_date
-- )


-- ============================================
-- ISSUE 4: amount_paid > amount_billed
-- Root cause: Data entry errors or system calculation bugs.
-- Physically impossible in real healthcare billing.
-- Impact: Overstates revenue collection totals.
-- Count: 6 records
-- ============================================
SELECT 
    billing_id,
    encounter_id,
    insurance_type,
    amount_billed,
    amount_paid,
    ROUND(amount_paid - amount_billed, 2) AS overpayment_amount
FROM billing
WHERE amount_paid > amount_billed;

-- Remediation: Flag for billing department review.
-- Exclude from revenue analysis with:
-- WHERE amount_paid <= amount_billed


-- ============================================
-- ISSUE 5: Orphaned billing records
-- Root cause: Partial data migration or improper record
-- deletion where encounter records were removed without
-- cascading to billing table.
-- Impact: Inflates revenue totals with unverifiable records.
-- Count: 5 records
-- ============================================
SELECT 
    b.billing_id,
    b.encounter_id,
    b.insurance_type,
    b.amount_billed,
    b.amount_paid
FROM billing b
LEFT JOIN encounters e ON b.encounter_id = e.encounter_id
WHERE e.encounter_id IS NULL;

-- Remediation: Exclude from all revenue analysis with:
-- WHERE b.encounter_id IN (SELECT encounter_id FROM encounters)


-- ============================================
-- ISSUE 6: Inconsistent city name formatting
-- Root cause: Manual data entry with no field validation —
-- multiple staff entering the same city name differently.
-- Impact: GROUP BY city splits identical locations into
-- separate groups, fragmenting geographic analysis.
-- Count: 20 patients affected
-- ============================================

-- Step 1: View all distinct raw city values (shows the problem)
SELECT DISTINCT city
FROM patients
ORDER BY city;

-- Step 2: View standardized city values (shows the fix)
SELECT DISTINCT UPPER(TRIM(REPLACE(city, '  ', ' '))) AS city_standardized
FROM patients
ORDER BY city_standardized;

-- Remediation: Apply to all geographic queries:
-- UPPER(TRIM(REPLACE(city, '  ', ' '))) AS city


-- ============================================
-- SUMMARY: Clean dataset filters
-- Apply ALL of the following to any analytical query
-- to ensure results exclude dirty records:
-- ============================================
-- 1. provider_id IS NOT NULL
-- 2. e.visit_date >= p.intake_date
-- 3. encounter_id IN (SELECT MIN(encounter_id) FROM encounters GROUP BY patient_id, provider_id, visit_date)
-- 4. b.amount_paid <= b.amount_billed
-- 5. b.encounter_id IN (SELECT encounter_id FROM encounters)
-- 6. UPPER(TRIM(REPLACE(city, '  ', ' '))) for geographic analysis
-- ============================================
