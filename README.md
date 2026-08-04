# Dark Store Performance & Inventory Intelligence

An end-to-end data analytics project for the quick commerce industry. It
designs a production-style relational database, generates a realistic
synthetic dataset, and answers real operational questions with SQL: which
dark stores are underperforming, which products are at risk of stockout,
where delivery SLAs are breaking down, and where revenue is leaking out of
the business.

## Introduction

This project was built to strengthen SQL and data analytics skills against a
business scenario that closely reflects real-world quick commerce
operations, rather than writing SQL only to demonstrate syntax. Every query
in this repository answers a specific business question that a dark store
operator, category manager, or delivery ops lead would actually ask.

## Project Overview

The objective is to design a normalized relational database and use SQL to
generate business insights for a quick commerce company running multiple
dark stores across several cities. Quick commerce businesses operate under
strict delivery timelines while managing thousands of products and
constantly shifting demand. This project uses SQL to analyze performance,
monitor operational KPIs, evaluate inventory health, identify delivery
bottlenecks, and support business intelligence reporting through a Power BI
layer.

## Business Problem

Quick commerce companies face several operational challenges every day:

- Managing inventory across multiple dark stores
- Maintaining product availability while reducing excess inventory
- Meeting delivery SLA commitments
- Reducing stockouts and lost sales
- Monitoring store performance across different cities
- Improving customer retention
- Increasing operational efficiency and profitability

This project uses data analytics to surface these problems and provide
insights that support better business decisions.

## Dataset

The dataset is fully synthetic, generated with a reproducible Python script
(`python/synthetic_data_generator.py`, seed 42) rather than pulled from a
single flat file, so every foreign key is relationally consistent by
construction. It ships in `data/` as ready-to-load CSVs, one per table:

| Table | Rows | Description |
|---|---|---|
| cities | 10 | Cities the business operates in, with tier classification |
| dark_stores | 30 | Fulfillment centers, 2-4 per city |
| categories | 28 | Product categories with parent/child hierarchy |
| products | 250 | SKUs with pricing, cost, and shelf life |
| inventory | 54,080 | Weekly stock snapshots per store/product over ~6 months |
| customers | 1,200 | Registered customers with signup and city data |
| promotions | 5 | Discount codes with active date windows |
| delivery_partners | 83 | Riders, by city and vehicle type |
| orders | 6,000 | Orders with status, promo, and totals |
| order_items | 20,744 | Line items per order |
| deliveries | 5,842 | Promised vs actual delivery time, by order |
| payments | 6,000 | Payment method, status, and amount, by order |
| returns | 644 | Item-level returns with reason and refund amount |

`data/sample_data.csv` is a small 50-row preview joining orders, customers,
and stores, useful for a quick look without opening the full tables.

## Tech Stack

- PostgreSQL
- SQL
- Python (pandas, Faker)
- Power BI
- Git / GitHub

## Database Design

The database follows a normalized relational schema defined in
`database/schema.sql`:

- Primary keys for unique record identification
- Foreign keys establishing relationships between all 13 tables
- Check constraints on statuses, ratings, and numeric ranges to keep data
  valid at the database level
- Indexes on every foreign key and frequently filtered column
  (`order_status`, `delivery_status`, `stock_date`, and so on)
- A self-referencing `categories` table to support a category hierarchy

`database/views_and_procedures.sql` adds a second layer on top of the base
schema: two views (`store_daily_performance`, `product_inventory_health`),
one materialized view (`monthly_city_revenue`) for fast dashboard reads, and
two stored procedures (`refresh_dashboard_views`, `flag_low_stock`) that
demonstrate operational, not just analytical, use of the database.

## Project Workflow

**1. Data Understanding** — explored the dataset, defined business entities
and relationships, identified the metrics that matter operationally.

**2. Data Cleaning** — `python/data_cleaning.py` removes duplicate rows,
handles missing values with column-appropriate defaults, standardizes text
casing and date formats, and drops rows missing required foreign keys.

**3. Database Design** — `database/schema.sql` creates all relational
tables, keys, and constraints.

**4. SQL Analysis** — 35 analytical queries across four focused files,
each solving a specific business problem.

**5. KPI Development** — `sql/kpi_queries.sql` calculates the core business
metrics used across the dashboards.

**6. Dashboard Creation** — `dashboard/README.md` is a build guide (model
relationships, page layout, DAX measures) for assembling the Power BI report
on top of the views in this repo.

## SQL Concepts Used

Every query in `sql/` was written and tested against the generated dataset
(via a local SQLite mirror during development, with PostgreSQL-only syntax
called out and commented separately where the two diverge). Concepts used:

- Joins across all 13 tables
- CASE statements
- Aggregate functions
- Common Table Expressions (CTEs)
- A recursive CTE (category hierarchy traversal)
- Correlated subqueries (store delay vs citywide average)
- Window functions (`ROW_NUMBER`, `RANK`, `NTILE`, `PERCENT_RANK`)
- `LAG` / `LEAD` for period-over-period comparisons
- Running totals
- Rolling averages
- Percentile-style bucketing
- Views and a materialized view
- Stored procedures
- Indexing for query optimization

## Business KPIs

Calculated in `sql/kpi_queries.sql`:

- Fill Rate
- SLA Percentage
- Inventory Turnover
- Out-of-Stock Rate
- Revenue Lost Due to Stockouts (estimated)
- Average Order Value
- Repeat Customer Rate
- Revenue per Store
- Revenue per City
- Cancellation Rate
- Return Rate

## Business Analysis

- **Dark Store Performance** — `sql/kpi_queries.sql`, `database/views_and_procedures.sql`
- **Inventory Analysis** — `sql/inventory_analysis.sql`
- **Delivery Performance** — `sql/delivery_analysis.sql`
- **Product Performance** — `sql/sales_analysis.sql`
- **Customer Behavior** — `sql/customer_analysis.sql`
- **Peak Hour Analysis** — `sql/delivery_analysis.sql`, query 6
- **Weekend vs Weekday Sales** — `sql/sales_analysis.sql`, query 3
- **Promotion Effectiveness** — `sql/sales_analysis.sql`, query 5
- **Revenue Leakage** — `sql/kpi_queries.sql`, query 5 (estimated stockout loss);
  `sql/kpi_queries.sql`, query 10-11 (cancellations and returns)

## Power BI Dashboard

Planned as five report pages, all detailed with model relationships and DAX
measures in `dashboard/README.md`:

- **Executive Dashboard** — high-level overview of overall business
  performance and key KPIs
- **Sales Dashboard** — revenue, order volume, customer trends, sales
  performance
- **Inventory Dashboard** — stock levels, availability, turnover, stockout
  trends
- **Dark Store Dashboard** — store performance comparison across locations
- **Delivery Dashboard** — delivery times, SLA compliance, cancellations

`docs/ER_Diagram.png` and `docs/Database_Schema.png` document the schema
this report connects to.

## Key Learnings

Working on this project reinforced how SQL is used in real business
environments rather than only in academic exercises: designing a normalized
relational database, building relationships between tables, and improving
query performance with indexes. It also involved writing advanced SQL with
window functions, CTEs, and analytical functions to answer specific
operational questions, and translating those results into KPIs and Power BI
dashboards that a business user could actually read and act on.

## Future Improvements

- Demand forecasting
- Inventory prediction
- Customer segmentation
- Fraud detection
- Real-time dashboard refresh
- Automated ETL pipeline
- Docker deployment

## Getting Started

```bash
# 1. Set up a virtual environment and install dependencies
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 2. (Optional) Regenerate the synthetic dataset
cd python
python synthetic_data_generator.py --outdir ../data --seed 42
python data_cleaning.py --indir ../data --outdir ../data

# 3. Build the database
psql -U <user> -d <database> -f database/schema.sql
psql -U <user> -d <database> -f database/views_and_procedures.sql

# 4. Load the CSVs (example using psql's \copy)
psql -U <user> -d <database>
\copy cities FROM 'data/cities.csv' CSV HEADER
\copy dark_stores FROM 'data/dark_stores.csv' CSV HEADER
\copy categories FROM 'data/categories.csv' CSV HEADER
\copy products FROM 'data/products.csv' CSV HEADER
\copy customers FROM 'data/customers.csv' CSV HEADER
\copy promotions FROM 'data/promotions.csv' CSV HEADER
\copy delivery_partners FROM 'data/delivery_partners.csv' CSV HEADER
\copy orders FROM 'data/orders.csv' CSV HEADER
\copy order_items FROM 'data/order_items.csv' CSV HEADER
\copy inventory FROM 'data/inventory.csv' CSV HEADER
\copy deliveries FROM 'data/deliveries.csv' CSV HEADER
\copy payments FROM 'data/payments.csv' CSV HEADER
\copy returns FROM 'data/returns.csv' CSV HEADER

# 5. Run the analysis queries
psql -U <user> -d <database> -f sql/kpi_queries.sql
```

Load order matters: parent tables (`cities`, `categories`) before tables
that reference them (`dark_stores`, `products`), and both before `orders`
and its dependents.

## Repository Structure

```
Dark-Store-Performance-Inventory-Intelligence/
│
├── README.md
├── LICENSE
├── requirements.txt
│
├── data/
│   ├── cities.csv
│   ├── dark_stores.csv
│   ├── categories.csv
│   ├── products.csv
│   ├── inventory.csv
│   ├── customers.csv
│   ├── promotions.csv
│   ├── delivery_partners.csv
│   ├── orders.csv
│   ├── order_items.csv
│   ├── deliveries.csv
│   ├── payments.csv
│   ├── returns.csv
│   └── sample_data.csv
│
├── database/
│   ├── schema.sql
│   └── views_and_procedures.sql
│
├── sql/
│   ├── inventory_analysis.sql
│   ├── delivery_analysis.sql
│   ├── sales_analysis.sql
│   ├── customer_analysis.sql
│   └── kpi_queries.sql
│
├── python/
│   ├── data_cleaning.py
│   └── synthetic_data_generator.py
│
├── dashboard/
│   ├── README.md
│   └── dashboard_screenshots/
│
└── docs/
    ├── ER_Diagram.png
    └── Database_Schema.png
```

## Conclusion

This project demonstrates the ability to design relational databases, write
advanced SQL queries, analyze business data, develop meaningful KPIs, and
build interactive Power BI dashboards. It reflects how data analytics can be
applied to solve practical business problems in the quick commerce industry.
