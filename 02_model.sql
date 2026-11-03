-- =====================================================================
-- 02_model.sql
-- Star-schema helpers: a month calendar and a student-month snapshot.
-- {start_month} / {end_month} define the analysis window (set in build.py).
-- =====================================================================

-- One row per month in the analysis window.
create or replace table dim_month as
select
    m::date                          as month,
    strftime(m, '%Y-%m')             as month_key,
    strftime(m, '%b %Y')             as month_label
from range(date '{start_month}', date '{end_month}' + interval 1 month, interval 1 month) t(m);

-- One row per student per month in which the student was enrolled.
-- Rule: active from the enrollment month up to the month BEFORE cancellation;
-- the cancellation month itself counts as a churn event.
create or replace table fct_student_month as
select
    d.month,
    s.student_id,
    s.plan_id,
    s.age_band,
    (s.enrollment_month = d.month)                       as is_new,
    coalesce(s.cancellation_month = d.month, false)      as is_churned,
    (s.cancellation_month is null or s.cancellation_month > d.month) as is_active_end_of_month
from dim_month d
join stg_students s
  on s.enrollment_month <= d.month
 and (s.cancellation_month is null or s.cancellation_month >= d.month);

-- Attendance enriched with the class slot (when the slot is known).
create or replace table fct_attendance as
select
    a.*,
    c.time_slot,
    c.start_time
from stg_attendance a
left join stg_classes c using (class_id)
where a.month between date '{attendance_start}' and date '{end_month}';
