DROP TABLE IF EXISTS public.products;

CREATE TABLE IF NOT EXISTS public.products (
  product_name TEXT,
  product_category TEXT,
  product_description TEXT
);

INSERT INTO products (product_name, product_category, product_description)
VALUES ('Product 1', 'Toys', 'Toy Soldier')
     , ('Product 1', 'Toys', 'Toy Soldier')
     , ('Product 2', 'Furniture', 'Desk');

SELECT * FROM products;

ALTER TABLE public.products ADD COLUMN IF NOT EXISTS actively_sold bool not null default TRUE;

INSERT INTO products (product_name, product_category, product_description, actively_sold)
VALUES ('Product 1', 'Toys', 'Toy Soldier - old version - retired', False);

SELECT * FROM products;

SELECT product_name
     , product_category
  FROM products;

-- how to find?
SELECT count(distinct f.product_name)
     , count(f.product_name)
  FROM products f;

SELECT md5(p.*::text)
     , count(*)
  FROM products p
 GROUP BY md5(p.*::text);

 SELECT product_name
      , count(*)
   FROM products
  GROUP BY product_name
  HAVING count(*) > 1;

SELECT product_name
  FROM (
   SELECT product_name
        , count(*) over (partition by product_name) rc
     FROM products
 ) sq
WHERE rc > 1;

SELECT product_name
     , rn
 FROM (
   SELECT product_name
        , row_number() over (partition by product_name) rn
     FROM products
 ) sq
WHERE rn=2;

-- how to remove?
SELECT DISTINCT
       product_name
     , product_category
     , product_description
  FROM products;

SELECT DISTINCT
       product_name
     , product_category
  FROM products;

SELECT product_name
     , product_category
     , product_description
  FROM (
   SELECT product_name
        , product_category
        , product_description
        , row_number() over (partition by product_name) rn
     FROM products
 ) sq
WHERE rn=1;

-- delete all
WITH dups AS (
   SELECT product_name
     FROM (
       SELECT product_name
            , row_number() over (partition by product_name) rn
         FROM products
     ) sq
    WHERE rn=2
)
DELETE
  FROM public.products p
 WHERE EXISTS (SELECT 1 FROM dups WHERE dups.product_name = p.product_name);

SELECT * FROM products;

-- delete all but one
DELETE
  FROM public.products p
 WHERE EXISTS (SELECT 1
                 FROM (SELECT row_number() over (partition by product_name) as rn
                         FROM public.products pi
                        WHERE md5(p.*::text) = md5(pi.*::text)) sq
                WHERE rn > 1
                );

SELECT ctid, * FROM public.products;

-- delete all but one - CTID
WITH dups AS (
   SELECT ctid
        , row_number() over (partition by product_name) rn
     FROM products p
)
DELETE
  FROM public.products p
 USING dups
 WHERE dups.ctid = p.ctid
   AND dups.rn > 1;

SELECT * FROM public.products;


-- alternative to delete
SELECT product_name
     , string_agg(coalesce(product_description,''), ' / ') as desc_merge_with_dups
     , string_agg(distinct coalesce(product_description,''), ' / ') desc_merge_without_dups
  FROM products
 GROUP BY product_name;


-- bonus

SELECT * FROM public.products;

SELECT DISTINCT ON (product_name)
       product_name
     , product_category
     , product_description
  FROM products;
