SELECT name
     , setting
     , unit
     , short_desc
  FROM pg_settings
 WHERE name ilike '%vacuum%';

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

select * from dc.products;

ALTER TABLE dc.products SET (autovacuum_enabled = false, toast.autovacuum_enabled = false);

SELECT relname
     , relnamespace
     , reloptions
  FROM pg_class
 WHERE relname = 'products';

CREATE EXTENSION IF NOT EXISTS tsm_system_rows SCHEMA extensions;

select * from dc.products tablesample extensions.system_rows (5);

with ids as (select id from dc.products tablesample extensions.system_rows (50000))
delete
  from dc.products p
 using ids
 where ids.id = p.id;

ANALYZE dc.products;

select * from tools.get_table_details(v_schema := 'dc', v_table := 'products');

select n_live_tup, n_dead_tup, relname from pg_stat_all_tables where relname = 'products';

SELECT * FROM extensions.heap_page_items(extensions.get_raw_page('dc.products', 1000));

SELECT *
  FROM extensions.heap_page_items(extensions.get_raw_page('dc.products', 10))
 WHERE t_xmax <> 0; -- Filter for rows that have been touched (deleted/updated)


SELECT *
  FROM extensions.heap_page_items(extensions.get_raw_page('dc.products', 0)) ;

vacuum full dc.products;



--- get_table_details that I use above: based on: https://wiki.postgresql.org/wiki/Category:Administration

--DROP FUNCTION IF EXISTS get_table_details(text,text);

CREATE OR REPLACE FUNCTION get_table_details(v_schema text default 'dc', v_table text default 'all')
RETURNS TABLE ( table_schema text
              , table_name text
              , statistics_missing bool
              , object_size text
              , table_size text
              , wasted_size text
              , table_bloat float
              , waste_to_size_ratio_pct float)
LANGUAGE sql
AS
$$
    WITH get_tables_with_size AS (
        SELECT table_name
             , table_schema
          FROM information_schema.tables t
         WHERE table_schema = v_schema
           AND table_name = CASE WHEN v_table='all' THEN table_name
                                 ELSE v_table
                             END-- if you want to get all tables omit the table parameter
    ), get_db_tables_size_and_waste AS (
        SELECT ma
             , bs
             , table_schema
             , table_name
             , (datawidth+(hdr+ma-(CASE WHEN hdr%ma=0 THEN ma ELSE hdr%ma END)))::NUMERIC AS datahdr
             , (maxfracsum*(nullhdr+ma-(CASE WHEN nullhdr%ma=0 THEN ma ELSE nullhdr%ma END))) AS nullhdr2
          FROM (SELECT gtws.table_schema
                     , gtws.table_name
                     , const.hdr
                     , const.ma
                     , const.bs
                     , SUM((1-sq.null_frac)*sq.avg_width) AS datawidth
                     , MAX(sq.null_frac) AS maxfracsum
                     , hdr+(SELECT 1+COUNT(*)/8
                              FROM pg_stats s2
                             WHERE null_frac<>0
                               AND s2.schemaname = sq.nspname
                               AND s2.tablename = sq.relname) AS nullhdr
                 FROM get_tables_with_size gtws
            LEFT JOIN (SELECT s.null_frac
                            , s.avg_width
                            , c.relname
                            , n.nspname
                         FROM pg_stats s
                   INNER JOIN pg_class c ON c.relname = s.tablename
                   INNER JOIN pg_attribute a ON c.oid = a.attrelid AND a.attname = s.attname
                    LEFT JOIN pg_namespace n ON n.oid = c.relnamespace ) sq on sq.relname = gtws.table_name and sq.nspname = gtws.table_schema
            LEFT JOIN (SELECT current_setting('block_size')::NUMERIC as bs
                            , CASE WHEN SUBSTRING(v,12,3) IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr
                            , CASE WHEN v ~ 'mingw32' THEN 8 ELSE 4 END AS ma
                         FROM version() v) const ON TRUE
            GROUP BY gtws.table_schema
                   , gtws.table_name
                   , sq.nspname
                   , sq.relname
                   , const.hdr
                   , const.ma
                   , const.bs
          ) td
    ), prettify_tables_details AS (
          SELECT rs.table_schema
               , rs.table_name
               , cc.reltuples
               , cc.relpages
               , bs
               , pg_total_relation_size(cc.oid) AS total_bytes
               , pg_indexes_size(cc.oid) AS index_bytes
               , pg_total_relation_size(cc.reltoastrelid) AS toast_bytes
               , CEIL((cc.reltuples*((datahdr+ma-(CASE
                                                    WHEN datahdr%ma=0 THEN ma
                                                    ELSE datahdr%ma
                                                  END))+nullhdr2+4))/(bs-20::FLOAT)) AS otta
            FROM get_db_tables_size_and_waste rs
      INNER JOIN pg_class cc ON cc.relname = rs.table_name
      INNER JOIN pg_namespace nn ON cc.relnamespace = nn.oid
                                AND nn.nspname = rs.table_schema
                                AND nn.nspname <> 'information_schema'
       LEFT JOIN pg_index i ON indrelid = cc.oid
       LEFT JOIN pg_class c2 ON c2.oid = i.indexrelid
    )
    SELECT table_schema
         , table_name
         , statistics_missing
         , object_size
         , table_size
         , wasted_size
         , table_bloat
         , waste_to_size_ratio_pct
    FROM (
    SELECT DISTINCT
           table_schema::text
         , table_name::text
         , CASE WHEN (CASE WHEN relpages < otta THEN 0 ELSE bs*(relpages-otta)::BIGINT END) IS NULL THEN TRUE ELSE FALSE END as statistics_missing
         , pg_size_pretty(total_bytes) as object_size -- table + indexes + toast
         , pg_size_pretty((total_bytes-index_bytes-COALESCE(toast_bytes,0))) AS table_size
         , ROUND((CASE WHEN otta=0 THEN 0.0 ELSE relpages::FLOAT/ nullif(otta,0) END)::NUMERIC,1) AS table_bloat
         , pg_size_pretty(CASE WHEN relpages < otta THEN 0 ELSE bs*(relpages-otta)::BIGINT END) AS wasted_size
         , (CASE WHEN relpages < otta THEN 0 ELSE bs*(relpages-otta)::BIGINT END  / nullif(total_bytes,0))*100 AS waste_to_size_ratio_pct
         , (CASE WHEN relpages < otta THEN 0 ELSE bs*(relpages-otta)::BIGINT END) as wasted_bytes
        FROM prettify_tables_details
    ) sq
    ORDER BY wasted_bytes DESC NULLS LAST;
$$
;

ALTER FUNCTION get_table_details(text,text) OWNER TO dc_admin;
