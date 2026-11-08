-- Drops helper objects from timescaledb-extras that depend on TimescaleDB catalog types.
-- They block ALTER EXTENSION timescaledb UPDATE whenever an update rebuilds the catalog table
-- they depend on, and then pg_upgrade fails because the old TimescaleDB version stays referenced.
-- They can be recreated from https://github.com/timescale/timescaledb-extras if still needed.
-- See: https://github.com/timescale/timescaledb-extras/issues/34
\set QUIET on
SET client_min_messages = warning;

-- From timescaledb-extras (views/functions for chunk details)
DROP FUNCTION IF EXISTS public.get_dimension_details(regclass);
DROP VIEW IF EXISTS public.chunks_tstz;
DROP VIEW IF EXISTS public.chunks_ts;

-- From timescaledb-extras backfill.sql (removed upstream in 2025)
DO $$
DECLARE
	routine regprocedure;
BEGIN
	FOR routine IN
		SELECT p.oid::regprocedure
		FROM pg_proc p
		JOIN pg_namespace n ON n.oid = p.pronamespace
		WHERE n.nspname = 'public'
		AND p.proname IN ('compress_dimension_slice', 'decompress_dimension_slice')
		AND pg_get_function_arguments(p.oid) LIKE '%\_timescaledb\_catalog.dimension\_slice%'
	LOOP
		RAISE WARNING 'Dropping % (timescaledb-extras backfill helper), it blocks updating TimescaleDB', routine;
		EXECUTE format('DROP ROUTINE %s', routine);
	END LOOP;
END
$$;
