# Validation summary

## Row counts

- `agg_kids_monthly.csv`: 17 rows
- `dim_classes.csv`: 7 rows
- `dim_instructors.csv`: 1 rows
- `dim_plans.csv`: 4 rows
- `dim_products.csv`: 14 rows
- `dim_students.csv`: 20 rows
- `fact_attendance.csv`: 809 rows
- `fact_financial_transactions.csv`: 49 rows
- `fact_payments.csv`: 77 rows
- `fact_sales.csv`: 41 rows

## Sensitive data scan

- Every cell of every file was checked against the source app's names, nicknames, phones, e-mails, birth dates, document numbers, original record ids, photo/face-crop ids, instructor/class/group/plan/product names, and the terms of the academy and location.
- Also checked for e-mail/URL patterns, image file names and long digit sequences.
- Matches found: **0**
- Columns present in the dataset: active_kids_students, age_band, amount, attendance_date, attendance_id, belt_level, billing_frequency, cancellation_month, category, check_in_method, class_id, classes_per_week, due_date, end_time, enrollment_month, instructor_id, modality, payment_date, payment_id, plan_id, plan_name, product_category, product_id, quantity, reference_month, sale_date, sale_id, start_time, status, student_group, student_id, transaction_date, transaction_id, type, weekday. None of them holds names, photos, facial data or contact details.

## Referential integrity

- `fact_attendance.student_id` → `dim_students`: OK
- `fact_attendance.class_id` → `dim_classes`: OK (82 blank values, see notes)
- `fact_payments.student_id` → `dim_students`: OK
- `fact_payments.plan_id` → `dim_plans`: OK (5 blank values, see notes)
- `fact_sales.product_id` → `dim_products`: OK
- `dim_students.plan_id` → `dim_plans`: OK (5 blank values, see notes)
- `dim_classes.instructor_id` → `dim_instructors`: OK

**Result: PASSED**

## Notes
- Blank `class_id` values in `fact_attendance` are imported attendance on weekdays with no slot in the current timetable. Blank `plan_id` values belong to inactive students who had no plan.
- Individuals under 18 and records with no birth date do not appear in any individual-level table. They appear only in `agg_kids_monthly.csv`.
- No randomization factor or seed is stored in any file.
