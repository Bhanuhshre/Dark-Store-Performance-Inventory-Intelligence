"""
data_cleaning.py

Cleans the raw synthetic CSVs before they are loaded into PostgreSQL:
- removes duplicate rows
- handles missing values with sensible per-column defaults
- standardizes text fields (trimming, casing) and date formats
- validates foreign-key columns aren't null where they shouldn't be
- reports a short data-quality summary for each table

Usage:
    python data_cleaning.py --indir ../data --outdir ../data/cleaned
"""

import argparse
import glob
import os

import pandas as pd

# Columns that must never be null for a row to be usable downstream.
REQUIRED_COLUMNS = {
    "customers": ["customer_id", "email", "city_id"],
    "orders": ["order_id", "customer_id", "store_id", "order_status"],
    "order_items": ["order_item_id", "order_id", "product_id", "quantity"],
    "products": ["product_id", "product_name", "category_id"],
    "inventory": ["inventory_id", "store_id", "product_id", "stock_date"],
    "dark_stores": ["store_id", "store_name", "city_id"],
    "deliveries": ["delivery_id", "order_id", "partner_id"],
    "payments": ["payment_id", "order_id", "payment_method"],
    "returns": ["return_id", "order_item_id", "return_date"],
}

# Text columns to trim and standardize casing on.
TEXT_COLUMNS = {
    "customers": ["full_name", "email"],
    "products": ["product_name", "brand"],
    "dark_stores": ["store_name"],
    "cities": ["city_name", "state"],
    "delivery_partners": ["partner_name"],
}

# Date/datetime columns to coerce and validate.
DATE_COLUMNS = {
    "orders": ["order_datetime"],
    "inventory": ["stock_date"],
    "customers": ["signup_date"],
    "dark_stores": ["opened_date"],
    "delivery_partners": ["joined_date"],
    "promotions": ["start_date", "end_date"],
    "deliveries": ["dispatched_at", "delivered_at"],
    "payments": ["paid_at"],
    "returns": ["return_date"],
}


def parse_args():
    parser = argparse.ArgumentParser(description="Clean raw synthetic CSVs")
    parser.add_argument("--indir", default="../data")
    parser.add_argument("--outdir", default="../data/cleaned")
    return parser.parse_args()


def clean_table(name, df):
    report = {"table": name, "rows_in": len(df)}

    # 1. Drop exact duplicate rows
    before = len(df)
    df = df.drop_duplicates()
    report["duplicates_removed"] = before - len(df)

    # 2. Standardize text columns
    for col in TEXT_COLUMNS.get(name, []):
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip()
            if col in ("email",):
                df[col] = df[col].str.lower()

    # 3. Coerce date/datetime columns
    for col in DATE_COLUMNS.get(name, []):
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], errors="coerce")

    # 4. Drop rows missing a required column
    required = REQUIRED_COLUMNS.get(name, [])
    before = len(df)
    for col in required:
        if col in df.columns:
            df = df[df[col].notna()]
    report["rows_dropped_missing_required"] = before - len(df)

    # 5. Fill sensible defaults for known optional numeric columns
    numeric_fill_zero = ["units_wasted", "units_received", "units_sold",
                          "discount_pct"]
    for col in numeric_fill_zero:
        if col in df.columns:
            df[col] = df[col].fillna(0)

    report["rows_out"] = len(df)
    return df, report


def main():
    args = parse_args()
    os.makedirs(args.outdir, exist_ok=True)

    reports = []
    for path in sorted(glob.glob(os.path.join(args.indir, "*.csv"))):
        name = os.path.splitext(os.path.basename(path))[0]
        df = pd.read_csv(path)
        cleaned_df, report = clean_table(name, df)
        cleaned_df.to_csv(os.path.join(args.outdir, f"{name}.csv"), index=False)
        reports.append(report)

    print(f"{'table':<20}{'rows_in':>10}{'dupes':>10}{'dropped':>12}{'rows_out':>12}")
    for r in reports:
        print(f"{r['table']:<20}{r['rows_in']:>10}{r['duplicates_removed']:>10}"
              f"{r['rows_dropped_missing_required']:>12}{r['rows_out']:>12}")


if __name__ == "__main__":
    main()
