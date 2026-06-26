# Sunrise Behavioral Health Clinic — SQL Analytics Project

## Overview

This project presents a full end-to-end SQL analytics investigation of a behavioral health clinic's operational and financial performance from 2021 to 2024. The dataset was purpose-built to mirror the relational schema of a real behavioral health EMR system, incorporating realistic ICD-10 diagnosis coding, insurance payer mix, provider caseload structures, and clinical workflows drawn from 3 years of direct behavioral health experience.

The analysis follows the complete data analyst workflow: raw data ingestion, data quality assessment, staging layer construction, and multi-dimensional analytical querying — culminating in actionable findings for clinic leadership.

---

## Business Problem

A behavioral health clinic experienced significant revenue and operational shifts between 2021 and 2024. Leadership needs to understand:

- What drove the revenue decline between 2022 and 2023?
- Which providers are performing efficiently, and which represent operational risk?
- Are patients being retained year-over-year, or is the clinic losing its existing base?
- What is driving patient discharges — clinical completion or external factors like insurance denial?
- Which patient populations represent the highest utilization and financial risk?

---

## Dataset

| Table | Rows | Description |
|---|---|---|
| patients | 150 | Demographics, insurance, referral source, intake/discharge info |
| providers | 10 | Provider role, specialty, department, hire date |
| encounters | 2,233 | Individual patient visits with provider, date, type, and show status |
| billing | 2,234 | Billing records with amount billed, amount paid, and payment status |
| diagnoses | 300 | Patient ICD-10 diagnosis codes |

**Date range:** January 2021 – June 2024  
**Tools:** MySQL 8.0, MySQL Workbench

---

## Data Architecture

This project implements a two-layer architecture mirroring production analytics engineering practices:

**Raw Layer** — source tables loaded directly from the EMR export, preserved without modification. All data quality issues are documented but not deleted.

**Staging Layer** — cleaned and standardized versions used for all analysis:
- `stg_patients` — city names standardized with `UPPER(TRIM(REPLACE()))`
- `stg_encounters` — NULL provider_ids, date violations, and duplicate records removed
- `stg_billing` — overpaid records and orphaned billing entries removed

This approach ensures raw data auditability while maintaining analytical accuracy. The same raw → staging pattern is formalized with dbt in Portfolio Project 3.

### Entity Relationship Diagram

![ERD](schema_erd.png)

---

## Data Quality Assessment

Six categories of data quality issues were identified and documented prior to analysis:

| Issue | Count | Root Cause | Resolution |
|---|---|---|---|
| NULL provider_id in encounters | 10 | Staff transition — encounters logged before provider assignment | Excluded from provider-level analysis |
| visit_date before intake_date | 5 | Data entry errors — incorrect date logged | Excluded from date-range analysis |
| Duplicate encounter records | 4 | EMR system import errors — same encounter logged twice | Retained lowest encounter_id as canonical record |
| amount_paid > amount_billed | 6 | Data entry or system calculation error — physically impossible | Excluded from revenue analysis |
| Orphaned billing records | 5 | Partial migration — billing records with no matching encounter | Excluded from all revenue analysis |
| Inconsistent city formatting | 20 | Manual entry — mixed case, extra spaces, abbreviations | Standardized in stg_patients using UPPER(TRIM(REPLACE())) |

Full validation queries are available in `data_validation.sql`.

---

## Key Findings

**1. Clinic-wide revenue declined 26% between 2022 and 2023**  
Total revenue fell from $79,637 in 2022 to $58,818 in 2023, with encounter volume declining 17% over the same period. The back half of 2023 generated roughly half the monthly revenue of the front half, suggesting an accelerating decline rather than a gradual shift.

**2. Private insurance revenue decline drove the largest absolute loss**  
All three payer types declined in 2023, but Private insurance fell $12,323 (33.1%) — the largest absolute dollar loss. Since Private generates the highest revenue per encounter, losing Private patients amplified the financial impact beyond what encounter volume alone would suggest.

**3. Insurance Denial is the second leading discharge reason**  
Of 43 discharged patients, 10 (23.3%) were discharged due to insurance denial — the second leading reason after treatment completion (44.2%). This finding warrants review of medical necessity documentation practices and payer-specific denial patterns.

**4. Michael Okafor represents a significant operational risk**  
Okafor has the highest no-show rate of any active provider (48.3%) combined with the lowest revenue per encounter ($47.57). His Substance Use specialization likely contributes to both — substance use patients have higher no-show rates and Medi-Cal (which dominates his caseload) reimburses at lower rates. Two compounding problems with no current mitigation in the data.

**5. Two providers account for 62.6% of total 2023 revenue**  
David Schwartz ($12,486) and Elena Vasquez ($18,459) together generated $30,945 of $49,341 in total provider revenue for 2023. This concentration represents significant financial risk if either provider were to leave.

**6. Hospital Discharge referrals show the lowest no-show rate (16.4%)**  
Referral source is a meaningful predictor of patient engagement. Hospital Discharge patients had the lowest no-show rate (16.4%) while Provider Referrals had the highest (28.3%), suggesting differentiated outreach protocols by referral channel could improve attendance rates clinic-wide.

**7. 17 high utilizers identified — 47% are Medi-Cal patients**  
Patients more than 1.5 standard deviations above average encounter count skew heavily toward Medi-Cal (47%), the lowest-reimbursing payer. The clinic's most resource-intensive patients are also its least financially sustainable — a structural cost-revenue imbalance worth flagging for leadership.

---

## Technical Skills Demonstrated

**SQL Concepts:**
- Multi-table JOINs (INNER, LEFT, anti-join pattern)
- Common Table Expressions (single and chained)
- Window functions: LAG, LEAD, RANK, DENSE_RANK, NTILE, SUM OVER, AVG OVER
- Conditional aggregation (CASE WHEN inside COUNT/SUM)
- Subqueries as denominators for percentage calculations
- CROSS JOIN for single-row aggregate CTEs
- Correlated subqueries in WHERE clauses
- Date functions: YEAR(), MONTH(), DATEDIFF()
- String functions: UPPER(), TRIM(), REPLACE(), CONCAT()
- COALESCE for NULL handling
- STDDEV() for statistical threshold analysis
- Data validation queries (referential integrity, impossible values, duplicates)

**Data Engineering Concepts:**
- Raw → Staging layer architecture
- CREATE TABLE AS SELECT for staging table construction
- Data quality documentation and remediation
- Non-destructive cleaning (raw data preserved, issues filtered in queries)

---

## Repository Structure

```
sunrise-behavioral-health-analytics/
├── README.md
├── schema_erd.png
├── data/
│   └── sunrise_behavioral_health_v4_mysql.sql
├── sql/
│   ├── 01_staging_tables.sql
│   ├── 02_data_validation.sql
│   └── 03_analytical_queries.sql
```

---

## How to Run

1. Install MySQL 8.0 and MySQL Workbench
2. Create a new schema: `CREATE DATABASE sunrise_bh_v4;`
3. Run `data/sunrise_behavioral_health_v4_mysql.sql` to load raw tables
4. Run `sql/01_staging_tables.sql` to build clean staging tables
5. Run `sql/02_data_validation.sql` to reproduce data quality findings
6. Run `sql/03_analytical_queries.sql` to reproduce all analytical results

---

## HIPAA Note

This project uses entirely synthetic data generated to mirror realistic behavioral health EMR structures. No real patient data was used at any point. In a production environment, all patient PII would be replaced with de-identified patient IDs per HIPAA Safe Harbor guidelines prior to any analytical query.

---

## About

Built by Jake — behavioral health worker with 3 years of direct clinical experience transitioning into healthcare data analytics. This project reflects both technical SQL proficiency and domain-level understanding of behavioral health operations, billing workflows, and clinical outcome metrics.

*Targeting Healthcare Data Analyst and Epic Clarity Analyst roles. Open to connecting.*
