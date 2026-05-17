-- Step 2: DW - Load data from CSV files into star schema tables (Data Warehouse)
-- Run this after Step 1
-- Note: Update the GCS bucket path with your actual bucket name

-- Load dimension tables first (no FK dependencies)
-- Load dimension tables first (no FK dependencies)

SELECT '====== LOADING COMPANY TABLE ======' AS info;

INSERT INTO company_dim (company_id, name, link, link_google, thumbnail)
SELECT company_id, name, link, link_google, thumbnail
FROM read_csv('https://storage.googleapis.com/sql_de/company_dim.csv', 
    AUTO_DETECT=true,
    HEADER=true);

SELECT '====== LOADING SKILL TABLE ======' AS info;

INSERT INTO skills_dim (skill_id, skills, type)
SELECT skill_id, skills, type
FROM read_csv('https://storage.googleapis.com/sql_de/skills_dim.csv', 
    AUTO_DETECT=true,
    HEADER=true)
WHERE skills IS NOT NULL;

-- Load fact table second (FK references company_dim - must load after dimensions)
SELECT '====== LOADING JOB POSTING TABLE ======' AS info;

INSERT INTO job_postings_fact (
    job_id, company_id, job_title_short, job_title, job_location, 
    job_via, job_schedule_type, job_work_from_home, search_location,
    job_posted_date, job_no_degree_mention, job_health_insurance, 
    job_country, salary_rate, salary_year_avg, salary_hour_avg
)
SELECT 
    job_id, company_id, job_title_short, job_title, job_location, 
    job_via, job_schedule_type, job_work_from_home, search_location,
    job_posted_date, job_no_degree_mention, job_health_insurance, 
    job_country, salary_rate, salary_year_avg, salary_hour_avg
FROM read_csv('https://storage.googleapis.com/sql_de/job_postings_fact.csv', 
    AUTO_DETECT=true,
    HEADER=true);

-- Load bridge table last (FKs reference skills_dim and job_postings_fact)
SELECT '====== LOADING SKILL JOB DIM TABLE ======' AS info;

INSERT INTO skills_job_dim (skill_id, job_id)
SELECT skill_id, job_id
FROM read_csv('https://storage.googleapis.com/sql_de/skills_job_dim.csv', 
    AUTO_DETECT=true,
    HEADER=true);


-- Verify referential integrity (should return 0 for all queries)
SELECT '=== Referential Integrity Check ===' AS info;
SELECT 
    'Orphaned company_ids in job_postings_fact' AS check_type,
    COUNT(*) AS orphaned_count
FROM job_postings_fact 
WHERE company_id NOT IN (SELECT company_id FROM company_dim);

SELECT 
    'Orphaned skill_ids in skills_job_dim' AS check_type,
    COUNT(*) AS orphaned_count
FROM skills_job_dim 
WHERE skill_id NOT IN (SELECT skill_id FROM skills_dim);

SELECT 
    'Orphaned job_ids in skills_job_dim' AS check_type,
    COUNT(*) AS orphaned_count
FROM skills_job_dim 
WHERE job_id NOT IN (SELECT job_id FROM job_postings_fact);


-- Verify data was loaded correctly
SELECT 'Company Dimendion' AS table_name, COUNT(*) record_count FROM company_dim
UNION ALL
SELECT 'Skills Dimension', COUNT(*) FROM skills_dim
UNION ALL
SELECT 'Job Posting Facts', COUNT(*) FROM job_postings_fact
UNION ALL
SELECT 'Skill Job Bridge', COUNT(*) FROM skills_job_dim;

SELECT '======= COMPANY DIMENSION TABLE =======' AS info;
SELECT * FROM company_dim
LIMIT 5;

SELECT '======= SKILL DIMENSION TABLE =======' AS info;
SELECT * FROM skills_dim
LIMIT 5;

SELECT '======= JOB POSTING FACT TABLE =======' AS info;
SELECT * FROM job_postings_fact
LIMIT 5;

SELECT '======= SKILL JOB BRIDGE TABLE =======' AS info;
SELECT * FROM skills_job_dim
LIMIT 5;