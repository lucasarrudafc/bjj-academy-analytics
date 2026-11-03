# Data Dictionary — Martial Arts Academy BI Dataset

The data comes from the management app of a small Brazilian jiu-jitsu academy (one instructor, adult and kids classes) and covers mid-2025 to November 2026. It is modeled as a star schema: dimension tables (`dim_*`), fact tables (`fact_*`) and one aggregate table (`agg_*`).

All files are UTF-8 CSV, comma-separated, with a header row. Dates use `YYYY-MM-DD`, months `YYYY-MM`, times `HH:MM`, and decimals use a dot. Every record was **fully anonymized**; see [Anonymization](#anonymization).

## Dimensions

### dim_students.csv
One row per adult student (18+). Minors are not included; see `agg_kids_monthly.csv`.

| Column | Type | Description |
|---|---|---|
| student_id | string | Random surrogate key (`STU_001`…). Its order does not follow names or enrollment order. |
| age_band | category | `18-25`, `26-35`, `36-45`, `46+`. Computed after a random age offset; see Anonymization. |
| belt_level | category | Generic rank level (`level_1` = lowest rank present). Shuffled across students. Blank when the student has no rank recorded. |
| student_group | category | Generic student segment (`group_a`, `group_b`, `group_c`). Blank when the student belongs to no group. |
| plan_id | string | FK → `dim_plans`. The student's current plan. Blank for inactive students who left without a plan. |
| enrollment_month | month | Month the student enrolled. |
| status | category | `active` / `inactive`. |
| cancellation_month | month | Month the student left. Blank for active students. |

### dim_instructors.csv
| Column | Type | Description |
|---|---|---|
| instructor_id | string | Surrogate key (`INS_001`…). |

### dim_classes.csv
One row per recurring class slot in the weekly schedule.

| Column | Type | Description |
|---|---|---|
| class_id | string | Surrogate key (`CLS_001`…). |
| modality | category | Martial art (`brazilian_jiu_jitsu`). |
| weekday | category | `monday` … `sunday`. |
| start_time / end_time | time | Slot start and end (`HH:MM`). |
| instructor_id | string | FK → `dim_instructors`. |

### dim_plans.csv
| Column | Type | Description |
|---|---|---|
| plan_id | string | Surrogate key (`PLN_001`…). |
| plan_name | category | Generic name (`plan_a`, `plan_b`…). |
| billing_frequency | category | Billing cycle. All plans are `monthly`. |
| classes_per_week | integer | Allowed classes per week. **Blank:** the source app does not record it. |

### dim_products.csv
| Column | Type | Description |
|---|---|---|
| product_id | string | Random surrogate key (`PRD_001`…). |
| product_category | category | `apparel`, `accessories`, `private_lessons`, `belt_exam`. |

## Facts

### fact_attendance.csv
One row per student per class attended.

| Column | Type | Description |
|---|---|---|
| attendance_id | string | Surrogate key (`ATT_00001`…). |
| attendance_date | date | Day of the class. |
| class_id | string | FK → `dim_classes`. **Blank** when the slot could not be determined (see notes). |
| student_id | string | FK → `dim_students`. |
| check_in_method | category | `facial`: confirmed automatically by the app's face recognition. `manual`: marked by the instructor. `imported`: attendance migrated from the academy's previous system, which only stored the date. |

### fact_payments.csv
One row per monthly fee (tuition), paid or open.

| Column | Type | Description |
|---|---|---|
| payment_id | string | Surrogate key (`PAY_0001`…). |
| student_id | string | FK → `dim_students`. |
| plan_id | string | FK → `dim_plans`. The student's current plan. Blank for inactive students without a plan. |
| reference_month | month | Month the fee covers. |
| due_date | date | Due date. Fees are due on day 10 of the reference month. |
| payment_date | date | Date paid. Blank if not paid. |
| amount | decimal | Fee amount (scaled; see Anonymization). |
| status | category | `paid`: paid on or before the due date. `late`: paid after the due date, or past due and unpaid. `pending`: not yet due and unpaid. |

The source app only stores payments that were made. Unpaid rows (`pending`, or `late` without a `payment_date`) were derived with the app's own billing rule: a payment covers its month, and the next fee is due on day 10 of the following month. Students without a directly billed plan get no derived rows.

### fact_sales.csv
| Column | Type | Description |
|---|---|---|
| sale_id | string | Surrogate key (`SAL_0001`…). |
| sale_date | date | Sale date. |
| product_id | string | FK → `dim_products`. |
| quantity | number | Units sold (hours, for private lessons). |
| amount | decimal | Sale total (scaled; see Anonymization). |

### fact_financial_transactions.csv
Cash movements that are neither tuition nor product sales: operating expenses already paid, and owner capital in or out.

| Column | Type | Description |
|---|---|---|
| transaction_id | string | Surrogate key (`TRX_0001`…). |
| transaction_date | date | Payment date. |
| type | category | `income` / `expense`. |
| category | category | `facilities`, `software`, `telecom`, `advertising`, `marketing`, `inventory_purchase`, `logistics`, `belt_supplies`, `safety_equipment`, `cleaning`, `office_supplies`, `training`, `owner_contribution`, `owner_withdrawal`, `other`. |
| amount | decimal | Amount, always positive (scaled; see Anonymization). |

Tuition is in `fact_payments` and sales are in `fact_sales`, so they do not repeat here. Inventory purchases appear once, as `inventory_purchase` expenses.

## Aggregate

### agg_kids_monthly.csv
| Column | Type | Description |
|---|---|---|
| reference_month | month | Month. |
| active_kids_students | integer | Students under 18 who were active at any time during that month. |

## Notes on blank keys
- `fact_attendance.class_id`: about 10% of the imported attendance falls on weekdays that have no slot in the current schedule (the timetable changed over time). Those rows have a blank `class_id`.
- `plan_id` (in `dim_students` and `fact_payments`): blank for a few inactive students who had no plan when they left.

## Anonymization

Every step below was applied before the data left the app, and the random draws were not stored anywhere.

**Removed entirely**
- Names, nicknames, national ID / document numbers, phone numbers, e-mails, addresses, social media, emergency contacts, guardian details, and every free-text field (notes, descriptions, reasons).
- All photos, images and facial-recognition data: reference photos, class photos, face crops and confidence scores.
- The academy's name and location, and the names of the instructor, classes, groups, plans and products.
- Internal accounting records outside the scope of this dataset: leads/prospects, current stock levels, purchase orders, opening cash adjustments and other internal transfers.

**Pseudonymized**
- Students, instructors, classes, plans, products and every transaction got new surrogate keys. Student and product codes were assigned in random order.

**Generalized and perturbed**
- **Age:** each student's age got an independent random offset of −3 to +3 years and was then reduced to a band. Birth dates are not included.
- **Rank:** belt names became generic levels, and the levels were then shuffled among students. The overall distribution is preserved, but a level cannot be linked to a person.
- **Minors:** students under 18 (and the few records without a birth date, which may belong to minors) were removed from every individual-level table. They appear only as a monthly count in `agg_kids_monthly.csv`.

**Monetary values**
- **Tuition** (`fact_payments.amount`): every fee was multiplied by one fixed random factor. The recurrence pattern is preserved, so the same original fee always maps to the same value, but the absolute values are not real.
- **Everything else** (`fact_sales`, `fact_financial_transactions`): each record got its own independent random factor, so no individual value or total matches the real figures.
- All values are rounded to 2 decimals. The factors are not disclosed.

Absolute monetary values and totals in this dataset are **not** the academy's real figures. Use them for trends, ratios, seasonality and dashboard design, not for financial conclusions.
