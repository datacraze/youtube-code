-- 1. System-Level Storage Parameters

SELECT
   name,
   setting,
   unit,
   short_desc
FROM pg_settings
WHERE name IN ('block_size', 'wal_segment_size', 'data_directory', 'segment_size');

-- 2. Mapping Logical Objects to Physical Files - To find the specific file path on disk for a table (relation), matching the PGDATA/base/[db_oid]/[rel_filenode] structure:

DROP TABLE IF EXISTS dc.products CASCADE;

CREATE TABLE dc.products (
	id SERIAL,
	product_name VARCHAR(100),
	product_code VARCHAR(10),
	product_quantity NUMERIC(10,2),
	manufactured_date DATE,
	added_by TEXT DEFAULT 'admin',
	created_date TIMESTAMP DEFAULT now()
);

INSERT INTO dc.products (product_name, product_code, product_quantity, manufactured_date)
     SELECT 'Product '||floor(random() * 10000 + 1)::int,
            'PRD'||floor(random() * 10 + 1)::int,
            random() * 10 + 1,
            CAST((NOW() - (random() * (interval '90 days')))::timestamp AS date)
       FROM generate_series(1, 1000000) s(i);

SELECT
   d.datname AS database_name,
   d.oid AS database_oid,
   c.relname AS relation_name,
   pg_relation_filepath(c.oid) AS physical_relative_path,
   pg_relation_size(c.oid) AS size_bytes,
   pg_size_pretty(pg_relation_size(c.oid)) as pretty_size
FROM pg_class c
JOIN pg_database d ON d.datname = current_database()
WHERE c.relname = 'products';

-- 3. Deep Dive: Inspecting Page Headers
CREATE EXTENSION IF NOT EXISTS pageinspect SCHEMA extensions;

-- Read the raw page header - This queries the header of the first page (block 0) of a table:
SELECT * FROM extensions.page_header(extensions.get_raw_page('dc.products', 0));

-- See the ItemId array (Tuples) - To see the line pointers (LP) and their offsets:
SELECT * FROM extensions.heap_page_items(extensions.get_raw_page('dc.products', 0));
