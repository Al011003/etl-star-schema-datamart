--step 1: DW create star schema
.read 01_create_table_warehouse.sql

--step 2: DW - load data from csv
.read 02_load_schema_dw.sql