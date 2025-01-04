DROP TABLE IF EXISTS public.casting_tst;

CREATE TABLE IF NOT EXISTS public.casting_tst (
    id uuid not null default gen_random_uuid() primary key,
    col_txt text,
    col_int int
);

INSERT INTO public.casting_tst(col_txt, col_int)
     VALUES ('test_ABC', 100),
            ('test_ABC', '100');

SELECT * FROM public.casting_tst;

SELECT '100'::int, 100::text;

SELECT CAST('7492bd12-1fff-4d02-9355-da5678d2da46' AS UUID) as id
     , 'test_ABC' as col_txt
     , 100 as col_int
  FROM public.casting_tst;

select CAST('7492bd12-1fff-4d02-9355-da5678d2da' AS UUID) as id
     , 'test_ABC' as col_txt
     , 100 as col_int;

-- [22P02] ERROR: invalid input syntax for type uuid: "7492bd12-1fff-4d02-9355-da5678d2da"


DO $$
BEGIN
 INSERT INTO public.casting_tst(id, col_txt, col_int)
      SELECT CAST('7492bd12-1fff-4d02-9355-da5678d2da' AS UUID) as id
           , 'test_ABC' as col_txt
           , 100 as col_int
        FROM public.casting_tst;
EXCEPTION
    WHEN invalid_text_representation THEN
        RAISE NOTICE 'caught invalid type conversion';
END $$;



with validated_uuids as (
  select value,
         value ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' as is_valid
  from (values ('7492bd12-1fff-4d02-9355-da5678d2da'),
               ('7492bd12-1fff-4d02-9355-da5678d2da46')
  ) as t(value)
)
select is_valid, case when is_valid then cast(value as uuid) end
  from validated_uuids;

DROP FUNCTION IF EXISTS public.is_valid_uuid(text);

CREATE OR REPLACE FUNCTION is_valid_uuid(text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
BEGIN
    RETURN $1 ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
EXCEPTION
    WHEN OTHERS THEN
        RETURN false;
END;
$$;

SELECT CASE
    WHEN is_valid_uuid(value) THEN value::uuid
    END as uuid_value
FROM (VALUES
    ('7492bd12-1fff-4d02-9355-da5678d2da46'),
    ('7492bd12-1fff-4d02-9355-da5678d2da')
) as t(value);