-- =====================================================================
-- 01_staging.sql
-- Load the anonymized CSV exports into typed staging tables.
-- {raw} is replaced by scripts/build.py with the path to data/raw.
-- =====================================================================

-- ---------- Dimensions ----------

create or replace table stg_students as
select
    student_id,
    -- Privacy hardening: only one student falls in "46+", so the two
    -- oldest bands are merged to avoid a group of one.
    case when age_band in ('36-45', '46+') then '36+' else age_band end as age_band,
    nullif(belt_level, '')                              as belt_level,
    coalesce(nullif(student_group, ''), 'no_group')     as student_group,
    nullif(plan_id, '')                                 as plan_id,
    strptime(nullif(enrollment_month, ''), '%Y-%m')::date   as enrollment_month,
    status,
    strptime(nullif(cancellation_month, ''), '%Y-%m')::date as cancellation_month
from read_csv('{raw}/dim_students.csv', all_varchar = true, header = true);

create or replace table stg_classes as
select
    class_id,
    modality,
    weekday,
    start_time::time as start_time,
    end_time::time   as end_time,
    case when start_time::time < time '12:00' then 'morning' else 'evening' end as time_slot,
    instructor_id
from read_csv('{raw}/dim_classes.csv', all_varchar = true, header = true);

create or replace table stg_plans as
select plan_id, plan_name, billing_frequency
from read_csv('{raw}/dim_plans.csv', all_varchar = true, header = true);

create or replace table stg_products as
select product_id, product_category
from read_csv('{raw}/dim_products.csv', all_varchar = true, header = true);

-- ---------- Facts ----------

create or replace table stg_attendance as
select
    a.attendance_id,
    a.attendance_date::date                         as attendance_date,
    date_trunc('month', a.attendance_date::date)    as month,
    lower(dayname(a.attendance_date::date))         as weekday,
    isodow(a.attendance_date::date)                 as weekday_num,
    nullif(a.class_id, '')                          as class_id,
    a.student_id,
    a.check_in_method
from read_csv('{raw}/fact_attendance.csv', all_varchar = true, header = true) a;

create or replace table stg_payments as
select
    payment_id,
    student_id,
    nullif(plan_id, '')                             as plan_id,
    strptime(reference_month, '%Y-%m')::date        as reference_month,
    due_date::date                                  as due_date,
    nullif(payment_date, '')::date                  as payment_date,
    amount::decimal(12, 2)                          as amount,
    status
from read_csv('{raw}/fact_payments.csv', all_varchar = true, header = true);

create or replace table stg_sales as
select
    sale_id,
    sale_date::date                                 as sale_date,
    date_trunc('month', sale_date::date)            as month,
    product_id,
    quantity::integer                               as quantity,
    amount::decimal(12, 2)                          as amount
from read_csv('{raw}/fact_sales.csv', all_varchar = true, header = true);

create or replace table stg_transactions as
select
    transaction_id,
    transaction_date::date                          as transaction_date,
    date_trunc('month', transaction_date::date)     as month,
    type,
    category,
    -- Owner contributions/withdrawals are equity movements, not operating
    -- income or expenses, so they are flagged and left out of the P&L view.
    category in ('owner_contribution', 'owner_withdrawal') as is_owner_flow,
    amount::decimal(12, 2)                          as amount
from read_csv('{raw}/fact_financial_transactions.csv', all_varchar = true, header = true);

create or replace table stg_kids_monthly as
select
    strptime(reference_month, '%Y-%m')::date        as month,
    active_kids_students::integer                   as active_kids_students
from read_csv('{raw}/agg_kids_monthly.csv', all_varchar = true, header = true);
