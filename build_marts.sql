--.read build_marts.sql

--step 1: DW create star schema
.read 01_create_table_warehouse.sql

--step 2: DW - load data from csv
.read 02_load_schema_dw.sql

--step 3: DW - make job mart
.read 03_create_flat_mart.sql

--step 4: DW -  make skills mart
.read 04_create_skills_mart.sql