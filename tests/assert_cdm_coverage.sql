-- Coverage gate: compare what this project builds against the PUBLISHED OMOP CDM v5.4 spec.
--
-- Ordinary tests assert things about rows that exist. They cannot see a table that was never
-- built, which is how OBSERVATION_PERIOD went missing while every build stayed green. Absence
-- needs a different instrument: an inventory from OUTSIDE the thing being checked.
--
-- That inventory is `seeds/cdm_v54_tables.csv`, downloaded verbatim from OHDSI's
-- CommonDataModel repository. Nobody on this project has to know what OMOP requires; the spec
-- says, and this test reads it. `seeds/cdm_scope.csv` records our decision for each table, so
-- an unbuilt table has to be signed for rather than simply absent.
--
-- Three ways to fail:
--   MISSING_REQUIRED   the spec marks the table required and we did not build it
--   UNDECLARED         a spec table nobody has ruled in or out (silence, not a decision)
--   NOT_MATERIALIZED   declared BUILT but absent from the warehouse
with spec as (
    select lower(cdm_table_name) as cdm_table_name, upper(is_required) as is_required
    from {{ ref('cdm_v54_tables') }}
),
scope as (
    select lower(cdm_table_name) as cdm_table_name, upper(status) as status
    from {{ ref('cdm_scope') }}
),
-- What actually materialized, read from the warehouse rather than from the dbt graph, so this
-- proves the table exists rather than that a model was defined.
materialized as (
    select lower(table_name) as table_name
    from {{ target.database }}.information_schema.tables
    where lower(table_schema) = 'omop'
)
select sp.cdm_table_name, 'MISSING_REQUIRED' as violation,
       'spec marks this table required; no model builds it' as detail
from spec sp
left join scope sc on sc.cdm_table_name = sp.cdm_table_name
where sp.is_required = 'TRUE'
  and coalesce(sc.status, '') <> 'BUILT'

union all
select sp.cdm_table_name, 'UNDECLARED',
       'in the CDM spec but absent from cdm_scope.csv; rule it in or out with a reason'
from spec sp
left join scope sc on sc.cdm_table_name = sp.cdm_table_name
where sc.cdm_table_name is null

union all
select sc.cdm_table_name, 'NOT_MATERIALIZED',
       'declared BUILT but no such table in the OMOP schema'
from scope sc
left join materialized m on m.table_name = sc.cdm_table_name
where sc.status = 'BUILT'
  and m.table_name is null
