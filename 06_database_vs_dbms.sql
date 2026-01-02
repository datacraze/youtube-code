-- RELATIONAL
CREATE TABLE IF NOT EXISTS dc.books_r (
    name text,
    author text,
    isbn text
);

INSERT INTO dc.books_r (name, author, isbn)
     VALUES ('Lord Of The Rings','J. R. R. Tolkien','ABC123'),
            ('Hobbit','J. R. R. Tolkien','CDE456');

select * from dc.books_r;

-- DOCUMENT
CREATE TABLE IF NOT EXISTS dc.books_d (
    id bigint,
    doc jsonb
);

INSERT INTO dc.books_d (id, doc)
     VALUES (1, '{"name": "Lord Of The Rings", "author": "J. R. R. Tolkien", "isbn": "ABC123"}'),
            (2, '{"name": "Hobbit", "author": "J. R. R. Tolkien", "isbn": "CDE456"}');

select * from dc.books_d;

-- SPECIALIZED: Vector
-- CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS dc.books_v (
    id bigint PRIMARY KEY,
    title text,
    embedding extensions.vector(3)
);

INSERT INTO dc.books_v (id, title, embedding)
     VALUES (1, 'Lord Of The Rings', '[0.1, 0.5, -0.2]'),
            (2, 'Hobbit', '[0.2, 0.4, -0.1]');

select * from dc.books_v;


--

SELECT schemaname, relname, last_autoanalyze, last_analyze
  FROM pg_stat_all_tables WHERE relname = 'products';

select * from dc.products;

explain analyze SELECT * FROM dc.products;

explain analyze SELECT * FROM dc.products where id = 20425;

drop index if exists dc.pk_products_idx;
create index if not exists pk_products_idx on dc.products (id);

explain analyze SELECT * FROM dc.products where id = 20425;