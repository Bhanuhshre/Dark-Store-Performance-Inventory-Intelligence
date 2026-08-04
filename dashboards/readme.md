# Power BI Dashboard

This folder is where `Dark_Store_Analytics.pbix` lives once you build it in Power
BI Desktop. A `.pbix` is a binary file tied to a live Power BI application, so it
isn't something that can be generated outside of Power BI itself — this guide
gives you everything needed to build it in under an hour, connected straight to
the views in `database/views_and_procedures.sql`.

## 1. Connect to the data

- Open Power BI Desktop → Get Data → PostgreSQL database
- Point it at your database and load these objects directly instead of raw
  tables where possible, since they're already aggregated:
  - `store_daily_performance`
  - `product_inventory_health`
  - `monthly_city_revenue`
- Also load the base tables you'll need for slicers and joins: `orders`,
  `order_items`, `products`, `categories`, `customers`, `cities`,
  `dark_stores`, `deliveries`, `delivery_partners`, `payments`, `returns`

## 2. Build the model

- Mark `cities` and `dark_stores` as dimension tables; set 1-to-many
  relationships out to `orders`, `customers`, and `delivery_partners`
- Mark `products` and `categories` as dimensions feeding `order_items`
  and `inventory`
- Create a dedicated `Date` table (Power Query `CALENDAR` or DAX
  `CALENDARAUTO()`) and relate it to `order_datetime`, `stock_date`, and
  `delivered_at` for consistent time intelligence

## 3. Suggested pages

**Executive Dashboard**
- Total revenue, total orders, AOV, SLA %, fill rate — as KPI cards
- Revenue trend line by month
- Revenue by city map or bar chart

**Sales Dashboard**
- Revenue by category (bar)
- Top 10 products by revenue (table)
- Weekday vs weekend revenue (clustered column)
- Promotion effectiveness (table: promo code, orders, AOV, revenue)

**Inventory Dashboard**
- Out-of-stock rate by store (bar)
- Inventory turnover by store (bar)
- Low-stock table sourced from `product_inventory_health` where
  `needs_reorder = TRUE`
- Estimated revenue lost to stockouts (from `sql/kpi_queries.sql`, query 5)

**Dark Store Dashboard**
- Store scorecard table: revenue, fill rate, SLA %, cancellation rate
- Store comparison by city (matrix)

**Delivery Dashboard**
- SLA % by store and by city
- Delivery partner scorecard (from `sql/delivery_analysis.sql`, query 3)
- Average delay by hour of day (line chart, peak-hour view)

## 4. Suggested DAX measures

```dax
Total Revenue = SUM(orders[total_amount])

SLA % =
DIVIDE(
    CALCULATE(COUNTROWS(deliveries), deliveries[actual_time_mins] <= deliveries[promised_time_mins]),
    COUNTROWS(deliveries)
)

Fill Rate % =
DIVIDE(
    SUM(inventory[units_sold]),
    SUM(inventory[opening_stock]) + SUM(inventory[units_received])
)

Cancellation Rate % =
DIVIDE(
    CALCULATE(COUNTROWS(orders), orders[order_status] = "Cancelled"),
    COUNTROWS(orders)
)

MoM Revenue Growth % =
VAR CurrentRevenue = [Total Revenue]
VAR PriorRevenue = CALCULATE([Total Revenue], DATEADD('Date'[Date], -1, MONTH))
RETURN DIVIDE(CurrentRevenue - PriorRevenue, PriorRevenue)
```

## 5. Save

File → Save As → `Dark_Store_Analytics.pbix` in this folder. Export key pages
as PNG into `docs/dashboard_screenshots/` for the README.
