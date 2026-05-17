-- Step 4: Mart - Create skills demand mart (dimensional mart)
-- Run this after Step 3
-- This mart focuses on skills demand over time with clean additive measures

-- Drop existing mart schema if it exists (for idempotency)
DROP SCHEMA IF EXISTS skills_mart CASCADE;
-- Step 1: Create the mart schema
CREATE SCHEMA skills_mart;

-- Step 2: Create dimension tables

-- 1. Skills dimension

CREATE OR REPLACE TABLE skills_mart.dim_skills (
    skill_id INTEGER PRIMARY KEY,
    skills VARCHAR,
    type VARCHAR
);

INSERT INTO skills_mart.dim_skills (
    skill_id,
    skills,
    type
)
SELECT 
    skill_id,
    skills,
    type
FROM skills_dim;

-- 2. Month-level date dimension (enhanced with quarter and other attributes
CREATE OR REPLACE TABLE skills_mart.dim_date_month (
    month_start_date DATE PRIMARY KEY,
    year INTEGER,
    month INTEGER,
    quarter INTEGER,
    quarter_name VARCHAR,
    year_quarter VARCHAR
);
INSERT INTO skills_mart.dim_date_month(
    month_start_date,
    year,
    month,
    quarter,
    quarter_name,
    year_quarter
)
SELECT DISTINCT
    DATE_TRUNC('month', job_posted_date) AS month_start_date,
    EXTRACT(YEAR FROM job_posted_date) AS year,
    EXTRACT(MONTH FROM job_posted_date) AS month,
    EXTRACT(QUARTER FROM job_posted_date) AS QUARTER,
    'Q-' || EXTRACT(QUARTER FROM job_posted_date):: VARCHAR AS quarter_name,
    EXTRACT(YEAR FROM job_posted_date)::VARCHAR || '-Q' ||
     EXTRACT(QUARTER FROM job_posted_date):: VARCHAR AS year_quarter
FROM job_postings_fact
WHERE job_posted_date IS NOT NULL;

-- Step 3: Create fact table - fact_skill_demand_monthly
-- Grain: skill_id + month_start_date + job_title_short
-- All measures are additive (counts and sums) - safe to re-aggregate
CREATE OR REPLACE TABLE skills_mart.fact_skills_demand_monthly (
    skill_id INTEGER,
    month_start_date DATE,
    job_title_short VARCHAR,
    posting_count INTEGER,
    remote_posting_count INTEGER,
    health_insurance_count INTEGER,
    no_degree_count INTEGER,
    PRIMARY KEY (skill_id, month_start_date, job_title_short),
    FOREIGN KEY (skill_id) REFERENCES skills_mart.dim_skills(skill_id),
    FOREIGN KEY (month_start_date) REFERENCES skills_mart.dim_date_month(month_start_date)
);

INSERT INTO skills_mart.fact_skills_demand_monthly (
    skill_id,
    month_start_date,
    job_title_short,
    posting_count,
    remote_posting_count,
    health_insurance_count,
    no_degree_count
)
WITH job_posting_prep AS (
SELECT  
    skill_id,
    DATE_TRUNC('month', jpf.job_posted_date) AS month_start_date,
    jpf.job_title_short,
    CASE WHEN jpf.job_work_from_home = TRUE THEN 1 ELSE 0 END AS is_remote,
    CASE WHEN jpf.job_health_insurance = TRUE THEN 1 ELSE 0 END AS has_health_insurance,
    CASE WHEN jpf.job_no_degree_mention = TRUE THEN 1 ELSE 0 END AS no_degree_required
FROM job_postings_fact AS jpf
INNER JOIN
    skills_job_dim AS sjd
    ON jpf.job_id = sjd.job_id
)
SELECT
    skill_id,
    month_start_date,
    job_title_short,
    COUNT(*) AS posting_count,
    SUM(is_remote) AS remote_posting_count,
    SUM(has_health_insurance) AS health_unsirance_count,
    SUM(no_degree_required) AS no_degree_count
FROM job_posting_prep
GROUP BY ALL;

-- Verify mart was created
SELECT 'Skill Dimension' AS table_name, COUNT(*) as record_count FROM skills_mart.dim_skills
UNION ALL
SELECT 'Date Month Dimension', COUNT(*) FROM skills_mart.dim_date_month
UNION ALL
SELECT 'Skill Demand Fact', COUNT(*) FROM skills_mart.fact_skills_demand_monthly;

-- Show sample data from each table
SELECT '=== Skill Dimension Sample ===' AS info;
SELECT * FROM skills_mart.dim_skills LIMIT 10;

SELECT '=== Date Month Dimension Sample ===' AS info;
SELECT * FROM skills_mart.dim_date_month ORDER BY month_start_date DESC LIMIT 10;

SELECT '=== Skill Demand Fact Sample ===' AS info;
SELECT 
    fdsm.skill_id,
    ds.skills,
    ds.type AS skill_type,
    fdsm.job_title_short,
    fdsm.month_start_date,
    fdsm.posting_count,
    fdsm.remote_posting_count,
    fdsm.health_insurance_count,
    fdsm.no_degree_count,
    -- Calculate derived metrics (ratios) from additive measures
    CASE 
        WHEN fdsm.posting_count > 0 
        THEN fdsm.remote_posting_count::DOUBLE / fdsm.posting_count 
        ELSE 0.0 
    END AS remote_share
FROM skills_mart.fact_skills_demand_monthly fdsm
JOIN skills_mart.dim_skills ds ON fdsm.skill_id = ds.skill_id
ORDER BY fdsm.posting_count DESC, fdsm.month_start_date DESC
LIMIT 10;