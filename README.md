# 🏗️ Data Warehouse & Mart Build: Production ETL Pipeline

An end-to-end data engineering pipeline that ingests raw CSV files from Google Cloud Storage, normalizes them into a star schema data warehouse, and builds specialized analytical data marts on top.

---

## 🧾 Executive Summary

- ✅ **ETL Pipeline:** Full extract → transform → load pipeline from raw CSVs to a production-ready star schema
- ✅ **Dimensional Modeling:** Star schema with fact, dimension, and bridge tables for many-to-many relationships
- ✅ **Data Marts:** Three specialized marts (flat, skills demand, priority roles) each optimized for different analytical needs
- ✅ **Incremental Updates:** MERGE-based upsert pattern for production-grade incremental loading

---

## 🧩 Problem & Context

Job posting data lands as flat CSV files in Google Cloud Storage — not structured for analytical queries. Business stakeholders need answers to questions like:

- Which tech skills are growing in demand month over month?
- What are hiring trends by company, role, and location?
- How do salary ranges differ across skills and job levels?

**The Challenge:** Without a centralized, structured data layer, every analyst would write their own joins and filters — leading to inconsistent results and duplicated effort.

**The Solution:** A fully automated ETL pipeline that pulls CSVs from GCS, normalizes the data into a star schema warehouse, then builds purpose-built data marts to serve specific analytical workloads — reducing query complexity and improving performance for recurring use cases.

---

## 🧰 Tech Stack

| Tool | Purpose |
|------|---------|
| 🐤 DuckDB | File-based OLAP engine with native GCS support via `httpfs` |
| 🧮 SQL | DDL for schema design, DML for data loading and transformation |
| 📊 Star Schema | Dimensional modeling pattern (fact + dimension + bridge tables) |
| 🔧 Master Script | Single-command pipeline orchestration (`build_dw_marts.sql`) |
| ☁️ Google Cloud Storage | Source system for raw CSV files |
| 📦 Git/GitHub | Version control for all pipeline scripts |

---

## 📂 Repository Structure

```text
2_WH_Mart_Build/
├── 01_create_tables_dw.sql        # Star schema DDL
├── 02_load_schema_dw.sql          # Extract from GCS & load into warehouse
├── 03_create_flat_mart.sql        # Flat denormalized mart
├── 04_create_skills_mart.sql      # Skills demand time-series mart
├── 05_create_priority_mart.sql    # Priority roles snapshot mart
├── 06_update_priority_mart.sql    # Incremental MERGE update for priority mart
├── 07_create_company_mart.sql     # Company hiring mart (optional bonus)
├── build_dw_marts.sql             # Master script — runs all steps in order
└── README.md
```

---

## 🏗️ Pipeline Architecture

The pipeline has three logical layers:

```
[Google Cloud Storage CSVs]
        ↓  Extract & Load
[Data Warehouse — Star Schema]
        ↓  Transform & Aggregate
[Data Marts — Flat / Skills / Priority / Company]
        ↓  Serve
[BI Tools — Excel, Power BI, Tableau, Python]
```

---

## 🗄️ Data Warehouse (Star Schema)

**SQL Files:**
- `01_create_tables_dw.sql` — creates 4 core tables with FK constraints
- `02_load_schema_dw.sql` — loads dimension tables first, then fact, then bridge (respects FK dependency order)

**Schema:**

| Table | Type | Description |
|-------|------|-------------|
| `company_dim` | Dimension | Company metadata |
| `skills_dim` | Dimension | Skill name and category |
| `job_postings_fact` | Fact | One row per job posting |
| `skills_job_dim` | Bridge | Many-to-many: jobs ↔ skills |

**Grain:** One row per job posting in `job_postings_fact`

**Data Quality Checks included:**
- Referential integrity checks (orphaned FK counts — should all return 0)
- Row count verification per table after load

---

## 📋 Flat Mart

**SQL File:** `03_create_flat_mart.sql`

A fully denormalized snapshot joining all dimensions onto the fact table. Designed for ad-hoc exploration where analysts want everything in one place without writing joins.

**Key design choice:** Skills are aggregated into a nested `STRUCT` array (`skill_and_type`) per job posting, so each row still represents one job — no row explosion from the many-to-many skill relationship.

**Grain:** One row per job posting, with all dimensions joined

---

## 📈 Skills Demand Mart

**SQL File:** `04_create_skills_mart.sql`

A dimensional mart purpose-built for time-series skill demand analysis. Built as a proper mini star schema within its own schema (`skills_mart`).

**Tables:**

| Table | Description |
|-------|-------------|
| `dim_skills` | Skill name and category (copied from warehouse) |
| `dim_date_month` | Month-level date dimension with quarter attributes |
| `fact_skills_demand_monthly` | Aggregated skill demand by month and job title |

**Grain:** `skill_id + month_start_date + job_title_short`

**Key design decision — additive measures only:**  
All measures (`posting_count`, `remote_posting_count`, `health_insurance_count`, `no_degree_count`) are counts/sums — never ratios or percentages stored directly. Ratios are computed at query time. This means the fact table can be safely re-aggregated at any level without double-counting.

---

## 🎯 Priority Roles Mart

**SQL Files:**
- `05_create_priority_mart.sql` — initial build
- `06_update_priority_mart.sql` — incremental update using MERGE

A snapshot mart for tracking a curated list of priority job roles and their postings. Demonstrates production-grade incremental update patterns.

**Tables:**

| Table | Description |
|-------|-------------|
| `priority_roles` | Dimension: which roles to track + priority level |
| `priority_jobs_snapshot` | Snapshot of job postings for tracked roles |

**How the MERGE works (Step 6):**
1. Updates `priority_roles` — promotes Data Engineer to priority 1, adds Data Scientist as priority 2
2. Rebuilds a temp source table with the latest priority assignments
3. `MERGE INTO priority_jobs_snapshot`:
   - `WHEN MATCHED AND priority changed` → UPDATE the priority level and timestamp
   - `WHEN NOT MATCHED` → INSERT new jobs (e.g., Data Scientist postings)
   - `WHEN NOT MATCHED BY SOURCE` → DELETE jobs no longer in scope

This single MERGE handles inserts, updates, and deletes atomically — the standard upsert pattern for production incremental loads.

---

## 🏢 Company Hiring Mart *(Bonus)*

**SQL File:** `07_create_company_mart.sql`

An optional mart for company-level hiring trend analysis. More complex schema with two bridge tables to handle many-to-many relationships between companies, locations, and job titles.

**Grain:** `company_id + job_title_short_id + job_country + month_start_date`

**Notable technique — surrogate key generation without sequences:**  
DuckDB doesn't have `SEQUENCE` or `AUTO_INCREMENT` in the same way as other databases. Instead, surrogate keys are generated using a self-join CTE:

```sql
WITH distinct_titles AS (
    SELECT DISTINCT job_title_short FROM job_postings_fact
),
numbered_titles AS (
    SELECT 
        t1.job_title_short,
        COUNT(t2.job_title_short) + 1 AS job_title_short_id
    FROM distinct_titles t1
    LEFT JOIN distinct_titles t2 ON t2.job_title_short < t1.job_title_short
    GROUP BY t1.job_title_short
)
```

---

## 💡 Data Engineering Skills Demonstrated

### ETL Patterns
- **Idempotent scripts** — `DROP TABLE IF EXISTS` / `DROP SCHEMA IF EXISTS CASCADE` so every script is safely re-runnable
- **FK-ordered loading** — dimensions load before facts, bridge tables load last
- **MERGE upsert pattern** — incremental updates with INSERT, UPDATE, DELETE in a single atomic statement
- **Pipeline orchestration** — master script runs all steps in dependency order

### Dimensional Modeling
- Star schema with fact, dimension, and bridge tables
- Proper grain definition at each mart level
- Additive measures only in fact tables (ratios derived at query time)
- Bridge tables for many-to-many relationships

### SQL Techniques
- `DATE_TRUNC`, `EXTRACT` for temporal dimensions
- `ARRAY_AGG` + `STRUCT_PACK` for nested skill arrays in flat mart
- `CASE WHEN` for boolean-to-integer conversion (enables `SUM` aggregation of flags)
- CTEs for complex multi-step transformations
- `MERGE INTO` with all three clauses (`MATCHED`, `NOT MATCHED`, `NOT MATCHED BY SOURCE`)

### Production Practices
- Data quality checks embedded in load scripts (referential integrity, row counts)
- Separate schemas per mart for clean logical separation
- Clear script naming convention for dependency order (`01_`, `02_`, etc.)

---

## 🚀 How to Run

### Prerequisites
- DuckDB installed (`brew install duckdb` or download from [duckdb.org](https://duckdb.org))
- Public internet access to `storage.googleapis.com`

### Option A — Run full pipeline with master script
```bash
duckdb my_warehouse.db < build_dw_marts.sql
```

### Option B — Run step by step
```bash
duckdb my_warehouse.db < 01_create_tables_dw.sql
duckdb my_warehouse.db < 02_load_schema_dw.sql
duckdb my_warehouse.db < 03_create_flat_mart.sql
duckdb my_warehouse.db < 04_create_skills_mart.sql
duckdb my_warehouse.db < 05_create_priority_mart.sql
duckdb my_warehouse.db < 06_update_priority_mart.sql
duckdb my_warehouse.db < 07_create_company_mart.sql  # optional
```

### Verify
```sql
-- Connect to your database
duckdb my_warehouse.db

-- Check all tables loaded
SELECT table_schema, table_name, estimated_size
FROM duckdb_tables()
ORDER BY table_schema, table_name;
```
