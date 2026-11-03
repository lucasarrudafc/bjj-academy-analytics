-- =====================================================================
-- 03_kpis.sql
-- Each query below is exported to JSON by scripts/build.py and feeds one
-- block of the dashboard. A query starts with a line "-- name: <id>".
-- =====================================================================

-- name: students_monthly
-- Active students at month end, new enrollments and cancellations.
select
    d.month_key,
    d.month_label,
    count(*) filter (where f.is_active_end_of_month)                  as active_students,
    count(*) filter (where f.is_new)                                  as new_students,
    count(*) filter (where f.is_churned)                              as churned_students,
    count(*) filter (where not f.is_new)                              as active_at_start,
    round(100.0 * count(*) filter (where f.is_churned)
          / nullif(count(*) filter (where not f.is_new), 0), 1)        as churn_rate_pct
from dim_month d
left join fct_student_month f using (month)
group by all
order by d.month_key;

-- name: tuition_monthly
-- Tuition billed per reference month, split by payment behaviour.
select
    d.month_key,
    d.month_label,
    coalesce(sum(p.amount) filter (where p.status = 'paid'), 0)      as paid_on_time,
    coalesce(sum(p.amount) filter (where p.status = 'late'), 0)      as paid_late,
    coalesce(sum(p.amount) filter (where p.status = 'pending'), 0)   as open_amount,
    coalesce(sum(p.amount), 0)                                       as billed,
    count(p.payment_id)                                              as invoices
from dim_month d
left join stg_payments p on p.reference_month = d.month
group by all
order by d.month_key;

-- name: attendance_monthly
-- Check-ins per month and average check-ins per attending student.
select
    d.month_key,
    d.month_label,
    count(a.attendance_id)                                           as check_ins,
    count(distinct a.student_id)                                     as attending_students,
    round(count(a.attendance_id) / nullif(count(distinct a.student_id), 0), 1)
                                                                     as check_ins_per_student
from dim_month d
join fct_attendance a using (month)
group by all
order by d.month_key;

-- name: attendance_by_weekday
-- Where the mat is busiest. Imported records on days with two slots have
-- no class_id, so the morning/evening split uses only assigned check-ins.
select
    weekday,
    weekday_num,
    count(*)                                                          as check_ins,
    count(*) filter (where time_slot = 'morning')                     as morning,
    count(*) filter (where time_slot = 'evening')                     as evening,
    count(*) filter (where time_slot is null)                         as unassigned
from fct_attendance
group by all
order by weekday_num;

-- name: check_in_method
-- Adoption of facial-recognition check-in after it went live.
select
    check_in_method,
    count(*)                                                          as check_ins,
    min(attendance_date)::varchar                                     as first_seen
from stg_attendance
group by all
order by check_ins desc;

-- name: revenue_mix_monthly
-- Operating revenue: tuition collected (by reference month) + product sales.
select
    d.month_key,
    d.month_label,
    coalesce((select sum(amount) from stg_payments p
              where p.reference_month = d.month and p.status in ('paid', 'late')), 0) as tuition,
    coalesce((select sum(amount) from stg_sales s where s.month = d.month), 0)       as product_sales
from dim_month d
order by d.month_key;

-- name: expenses_by_category
-- Operating expenses in the window (owner withdrawals excluded).
select
    category,
    sum(amount)                                                       as amount,
    count(*)                                                          as transactions
from stg_transactions
where type = 'expense'
  and not is_owner_flow
  and month between date '{start_month}' and date '{end_month}'
group by all
order by amount desc;

-- name: sales_by_category
select
    p.product_category,
    sum(s.quantity)                                                   as units,
    sum(s.amount)                                                     as amount
from stg_sales s
join stg_products p using (product_id)
where s.month between date '{start_month}' and date '{end_month}'
group by all
order by amount desc;

-- name: active_by_plan
-- Current mix of active students per plan.
select
    pl.plan_name,
    count(*)                                                          as students
from stg_students s
join stg_plans pl using (plan_id)
where s.status = 'active'
group by all
order by students desc;

-- name: active_by_age_band
select
    age_band,
    count(*)                                                          as students
from stg_students
where status = 'active'
group by all
order by age_band;

-- name: kids_monthly
select
    strftime(k.month, '%Y-%m')                                        as month_key,
    strftime(k.month, '%b %Y')                                        as month_label,
    k.active_kids_students
from stg_kids_monthly k
where k.month between date '{start_month}' and date '{end_month}'
order by 1;

-- name: headline
-- Single-row KPIs for the stat tiles.
with sm as (select * from fct_student_month),
first_m as (select min(month) m from dim_month),
last_m  as (select max(month) m from dim_month),
tuition as (
    select
        sum(amount) filter (where reference_month = (select m from first_m)) as first_month,
        sum(amount) filter (where reference_month = (select m from last_m))  as last_month
    from stg_payments
)
select
    (select count(*) from sm where month = (select m from last_m) and is_active_end_of_month)  as active_now,
    (select count(*) from sm where month = (select m from first_m) and is_active_end_of_month) as active_first,
    (select count(*) from sm where is_new)                                                    as new_in_window,
    (select count(*) from sm where is_churned)                                                as churned_in_window,
    round(100.0 * (select count(*) from stg_payments where status = 'paid')
          / nullif((select count(*) from stg_payments where status in ('paid', 'late')), 0), 0) as on_time_pct,
    round(100.0 * (t.last_month - t.first_month) / nullif(t.first_month, 0), 0)               as tuition_growth_pct,
    (select check_ins_per_student from (
        select round(count(*) / count(distinct student_id), 1) as check_ins_per_student
        from fct_attendance where month = (select m from last_m)))                            as check_ins_per_student_now,
    round(100.0 * (select count(*) from stg_attendance where check_in_method = 'facial'
                   and attendance_date >= (select min(attendance_date) from stg_attendance where check_in_method = 'facial'))
          / nullif((select count(*) from stg_attendance where attendance_date >= (select min(attendance_date) from stg_attendance where check_in_method = 'facial')), 0), 0)
                                                                                              as facial_share_pct
from tuition t;
