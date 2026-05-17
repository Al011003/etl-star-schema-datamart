--.read build_marts.sql

--step 1: DW create star schema
.read 01_create_table_warehouse.sql

--step 2: DW - load data from csv
.read 02_load_schema_dw.sql

--step 3: DW - make job mart
.read 03_create_flat_mart.sql

--step 4: DW -  make skills mart
.read 04_create_skills_mart.sql

--step 5: DW - make priority mart
.read 05_create_priority_mart.sql

--step 6: DW - udpated priority role
.read 06_updated_priority_mart.sql

--step 7: DW - make data mart for company
.read 07_create_company_mart.sql