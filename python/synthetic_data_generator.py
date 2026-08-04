"""
synthetic_data_generator.py

Generates a relationally consistent synthetic dataset for the
Dark Store Performance & Inventory Intelligence project.

Every foreign key produced here points to a row that actually exists in the
parent table, so the CSVs can be loaded straight into the schema defined in
database/schema.sql without integrity errors.

Usage:
    python synthetic_data_generator.py --outdir ../data --seed 42
"""

import argparse
import random
from datetime import datetime, timedelta

import pandas as pd
from faker import Faker


def parse_args():
    parser = argparse.ArgumentParser(description="Generate synthetic quick-commerce data")
    parser.add_argument("--outdir", default="../data", help="Output directory for CSV files")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducibility")
    parser.add_argument("--n_customers", type=int, default=1200)
    parser.add_argument("--n_orders", type=int, default=6000)
    parser.add_argument("--days_back", type=int, default=180, help="Order/inventory history window")
    return parser.parse_args()


def random_datetime_within(days_back):
    delta_days = random.randint(0, days_back)
    dt = datetime.now() - timedelta(days=delta_days)
    dt = dt.replace(
        hour=random.randint(7, 23),
        minute=random.randint(0, 59),
        second=random.randint(0, 59),
        microsecond=0,
    )
    return dt


def build_cities():
    rows = [
        ("Mumbai", "Maharashtra", "Tier1"),
        ("Delhi", "Delhi", "Tier1"),
        ("Bengaluru", "Karnataka", "Tier1"),
        ("Hyderabad", "Telangana", "Tier1"),
        ("Pune", "Maharashtra", "Tier1"),
        ("Chennai", "Tamil Nadu", "Tier1"),
        ("Ahmedabad", "Gujarat", "Tier2"),
        ("Jaipur", "Rajasthan", "Tier2"),
        ("Lucknow", "Uttar Pradesh", "Tier2"),
        ("Indore", "Madhya Pradesh", "Tier3"),
    ]
    df = pd.DataFrame(rows, columns=["city_name", "state", "tier"])
    df.insert(0, "city_id", range(1, len(df) + 1))
    return df


def build_dark_stores(cities_df, fake, n_per_city=(2, 4)):
    rows = []
    store_id = 1
    for _, city in cities_df.iterrows():
        n_stores = random.randint(*n_per_city)
        for i in range(n_stores):
            opened = fake.date_between(start_date="-2y", end_date="-30d")
            rows.append({
                "store_id": store_id,
                "store_name": f"{city['city_name']} Dark Store {i + 1}",
                "city_id": city["city_id"],
                "store_area_sqft": random.choice([1500, 2000, 2500, 3000, 3500]),
                "opened_date": opened,
                "is_active": random.random() > 0.05,
            })
            store_id += 1
    return pd.DataFrame(rows)


def build_categories():
    top_level = ["Fruits & Vegetables", "Dairy & Breakfast", "Snacks", "Beverages",
                 "Personal Care", "Household Essentials", "Bakery", "Frozen Food"]
    sub = {
        "Fruits & Vegetables": ["Fresh Fruits", "Fresh Vegetables"],
        "Dairy & Breakfast": ["Milk", "Cereal", "Eggs"],
        "Snacks": ["Chips", "Namkeen", "Chocolates"],
        "Beverages": ["Soft Drinks", "Juices", "Tea & Coffee"],
        "Personal Care": ["Skin Care", "Hair Care", "Oral Care"],
        "Household Essentials": ["Cleaning Supplies", "Laundry"],
        "Bakery": ["Bread", "Cakes"],
        "Frozen Food": ["Ice Cream", "Frozen Snacks"],
    }
    rows = []
    cid = 1
    parent_ids = {}
    for name in top_level:
        rows.append({"category_id": cid, "category_name": name, "parent_category_id": None})
        parent_ids[name] = cid
        cid += 1
    for parent, children in sub.items():
        for child in children:
            rows.append({"category_id": cid, "category_name": child,
                         "parent_category_id": parent_ids[parent]})
            cid += 1
    return pd.DataFrame(rows)


def build_products(categories_df, fake, n_products=250):
    leaf_categories = categories_df[categories_df["parent_category_id"].notna()]
    brands = ["FreshCo", "DailyBasket", "PureLeaf", "SnackHouse", "HomeCare",
              "NatureFirst", "QuickBite", "UrbanKitchen", "GreenValley", "PrimeGoods"]
    rows = []
    for pid in range(1, n_products + 1):
        cat = leaf_categories.sample(1).iloc[0]
        cost = round(random.uniform(10, 400), 2)
        margin = random.uniform(1.15, 1.6)
        rows.append({
            "product_id": pid,
            "product_name": f"{fake.word().capitalize()} {cat['category_name']}",
            "category_id": cat["category_id"],
            "brand": random.choice(brands),
            "unit_price": round(cost * margin, 2),
            "unit_cost": cost,
            "shelf_life_days": random.choice([3, 7, 15, 30, 90, 180, 365]),
            "is_active": random.random() > 0.03,
        })
    return pd.DataFrame(rows)


def build_inventory(stores_df, products_df, days_back):
    rows = []
    inv_id = 1
    active_stores = stores_df[stores_df["is_active"]]
    sample_products = products_df.sample(min(80, len(products_df)), random_state=1)
    today = datetime.now().date()
    for _, store in active_stores.iterrows():
        for _, product in sample_products.iterrows():
            stock = random.randint(30, 150)
            for d in range(days_back, 0, -7):  # weekly snapshots keep file size reasonable
                stock_date = today - timedelta(days=d)
                received = random.randint(0, 40)
                sold = random.randint(0, min(stock + received, 60))
                wasted = random.randint(0, 5) if random.random() < 0.1 else 0
                closing = max(stock + received - sold - wasted, 0)
                rows.append({
                    "inventory_id": inv_id,
                    "store_id": store["store_id"],
                    "product_id": product["product_id"],
                    "stock_date": stock_date,
                    "opening_stock": stock,
                    "closing_stock": closing,
                    "reorder_level": 20,
                    "units_received": received,
                    "units_sold": sold,
                    "units_wasted": wasted,
                })
                stock = closing
                inv_id += 1
    return pd.DataFrame(rows)


def build_customers(cities_df, fake, n_customers):
    rows = []
    for cid in range(1, n_customers + 1):
        signup = fake.date_between(start_date="-2y", end_date="today")
        rows.append({
            "customer_id": cid,
            "full_name": fake.name(),
            "email": fake.unique.email(),
            "phone": fake.msisdn()[:10],
            "city_id": cities_df.sample(1).iloc[0]["city_id"],
            "signup_date": signup,
            "is_active": random.random() > 0.08,
        })
    return pd.DataFrame(rows)


def build_promotions():
    codes = [
        ("WELCOME10", "10% off first order", 10),
        ("SAVE15", "Flat 15% off", 15),
        ("WEEKEND20", "Weekend special 20% off", 20),
        ("FEST25", "Festival season discount", 25),
        ("FLASH5", "Flash sale 5% off", 5),
    ]
    rows = []
    for i, (code, desc, pct) in enumerate(codes, start=1):
        start = datetime.now().date() - timedelta(days=random.randint(60, 150))
        end = start + timedelta(days=random.randint(15, 45))
        rows.append({
            "promo_id": i, "promo_code": code, "description": desc,
            "discount_pct": pct, "start_date": start, "end_date": end,
        })
    return pd.DataFrame(rows)


def build_delivery_partners(cities_df, fake, n_per_city=(5, 10)):
    rows = []
    pid = 1
    for _, city in cities_df.iterrows():
        n_partners = random.randint(*n_per_city)
        for _ in range(n_partners):
            rows.append({
                "partner_id": pid,
                "partner_name": fake.name(),
                "city_id": city["city_id"],
                "vehicle_type": random.choice(["Bike", "Bicycle", "Scooter"]),
                "joined_date": fake.date_between(start_date="-2y", end_date="-10d"),
                "rating": round(random.uniform(3.2, 5.0), 1),
            })
            pid += 1
    return pd.DataFrame(rows)


def build_orders_and_children(customers_df, stores_df, products_df, promotions_df,
                               partners_df, days_back, n_orders):
    active_customers = customers_df[customers_df["is_active"]]
    active_stores = stores_df[stores_df["is_active"]]
    active_products = products_df[products_df["is_active"]]

    orders_rows, items_rows, deliveries_rows, payments_rows, returns_rows = [], [], [], [], []
    order_id = 1
    item_id = 1
    return_id = 1
    status_choices = ["Delivered"] * 82 + ["Cancelled"] * 10 + ["Returned"] * 5 + ["Placed"] * 3
    payment_methods = ["UPI", "Card", "Wallet", "COD", "NetBanking"]

    # cache stores per city and partners per city for consistent geography
    stores_by_city = {cid: g for cid, g in active_stores.groupby("city_id")}
    partners_by_city = {cid: g for cid, g in partners_df.groupby("city_id")}

    for _ in range(n_orders):
        customer = active_customers.sample(1).iloc[0]
        city_stores = stores_by_city.get(customer["city_id"])
        if city_stores is None or city_stores.empty:
            continue
        store = city_stores.sample(1).iloc[0]
        order_dt = random_datetime_within(days_back)
        status = random.choice(status_choices)
        use_promo = random.random() < 0.25
        promo_id = int(promotions_df.sample(1).iloc[0]["promo_id"]) if use_promo else None

        n_items = random.randint(1, 6)
        chosen_products = active_products.sample(n_items)
        line_total_sum = 0.0
        item_rows_for_order = []
        for _, product in chosen_products.iterrows():
            qty = random.randint(1, 4)
            price = float(product["unit_price"])
            line_total = round(qty * price, 2)
            line_total_sum += line_total
            item_rows_for_order.append({
                "order_item_id": item_id,
                "order_id": order_id,
                "product_id": product["product_id"],
                "quantity": qty,
                "unit_price": price,
                "line_total": line_total,
            })
            item_id += 1

        discount_pct = 0
        if promo_id is not None:
            discount_pct = float(promotions_df.loc[
                promotions_df["promo_id"] == promo_id, "discount_pct"].iloc[0])
        total_amount = round(line_total_sum * (1 - discount_pct / 100), 2)

        orders_rows.append({
            "order_id": order_id,
            "customer_id": customer["customer_id"],
            "store_id": store["store_id"],
            "promo_id": promo_id,
            "order_datetime": order_dt,
            "order_status": status,
            "total_amount": total_amount,
        })
        items_rows.extend(item_rows_for_order)

        # Payment
        pay_status = "Success" if status != "Cancelled" else random.choice(["Failed", "Refunded"])
        payments_rows.append({
            "payment_id": order_id,
            "order_id": order_id,
            "payment_method": random.choice(payment_methods),
            "payment_status": pay_status,
            "paid_amount": total_amount if pay_status == "Success" else 0.0,
            "paid_at": order_dt + timedelta(minutes=random.randint(1, 5)),
        })

        # Delivery (skip for pure "Placed"/not-yet-dispatched orders sometimes)
        if status in ("Delivered", "Cancelled", "Returned"):
            city_partners = partners_by_city.get(customer["city_id"])
            if city_partners is not None and not city_partners.empty:
                partner = city_partners.sample(1).iloc[0]
                promised = random.choice([10, 15, 20, 30])
                if status == "Delivered":
                    actual = max(4, int(random.gauss(promised, 6)))
                    d_status = "Delivered" if actual <= promised + 5 else "Delayed"
                elif status == "Cancelled":
                    actual = None
                    d_status = "Cancelled"
                else:
                    actual = max(4, int(random.gauss(promised, 8)))
                    d_status = "Delayed"
                dispatched = order_dt + timedelta(minutes=random.randint(1, 4))
                delivered = (dispatched + timedelta(minutes=actual)) if actual else None
                deliveries_rows.append({
                    "delivery_id": order_id,
                    "order_id": order_id,
                    "partner_id": partner["partner_id"],
                    "promised_time_mins": promised,
                    "actual_time_mins": actual,
                    "dispatched_at": dispatched,
                    "delivered_at": delivered,
                    "delivery_status": d_status,
                })

        # Returns (only for a slice of "Returned" orders, at item level)
        if status == "Returned" and item_rows_for_order:
            n_returns = random.randint(1, len(item_rows_for_order))
            for item in random.sample(item_rows_for_order, n_returns):
                returns_rows.append({
                    "return_id": return_id,
                    "order_item_id": item["order_item_id"],
                    "return_reason": random.choice([
                        "Damaged product", "Wrong item delivered", "Item expired",
                        "Quality issue", "Changed mind",
                    ]),
                    "return_date": (order_dt + timedelta(days=random.randint(1, 5))).date(),
                    "refund_amount": item["line_total"],
                })
                return_id += 1

        order_id += 1

    return (
        pd.DataFrame(orders_rows),
        pd.DataFrame(items_rows),
        pd.DataFrame(deliveries_rows),
        pd.DataFrame(payments_rows),
        pd.DataFrame(returns_rows),
    )


def main():
    args = parse_args()
    random.seed(args.seed)
    Faker.seed(args.seed)
    fake = Faker()

    import os
    os.makedirs(args.outdir, exist_ok=True)

    print("Generating cities...")
    cities_df = build_cities()

    print("Generating dark stores...")
    stores_df = build_dark_stores(cities_df, fake)

    print("Generating categories...")
    categories_df = build_categories()

    print("Generating products...")
    products_df = build_products(categories_df, fake)

    print("Generating inventory history...")
    inventory_df = build_inventory(stores_df, products_df, args.days_back)

    print("Generating customers...")
    customers_df = build_customers(cities_df, fake, args.n_customers)

    print("Generating promotions...")
    promotions_df = build_promotions()

    print("Generating delivery partners...")
    partners_df = build_delivery_partners(cities_df, fake)

    print("Generating orders, order items, deliveries, payments, returns...")
    orders_df, items_df, deliveries_df, payments_df, returns_df = build_orders_and_children(
        customers_df, stores_df, products_df, promotions_df, partners_df,
        args.days_back, args.n_orders,
    )

    tables = {
        "cities": cities_df,
        "dark_stores": stores_df,
        "categories": categories_df,
        "products": products_df,
        "inventory": inventory_df,
        "customers": customers_df,
        "promotions": promotions_df,
        "delivery_partners": partners_df,
        "orders": orders_df,
        "order_items": items_df,
        "deliveries": deliveries_df,
        "payments": payments_df,
        "returns": returns_df,
    }

    for name, df in tables.items():
        path = f"{args.outdir}/{name}.csv"
        df.to_csv(path, index=False)
        print(f"  wrote {path}  ({len(df)} rows)")

    print("Done.")


if __name__ == "__main__":
    main()
