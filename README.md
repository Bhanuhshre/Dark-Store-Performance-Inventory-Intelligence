# Dark-Store-Performance-Inventory-Intelligence
Designed an enterprise-scale analytics solution using PostgreSQL, Python, and Power BI to identify underperforming dark stores, inventory stockout risks, delivery SLA bottlenecks, and revenue leakage, enabling data-driven operational decision-making through advanced KPI reporting

## Introduction

This project is an end-to-end data analytics portfolio project focused on the quick commerce industry. I built this project to strengthen my SQL and data analytics skills by working on a business scenario that closely reflects real-world operations.

The goal of the project is to analyze business performance using SQL and Power BI while solving practical problems related to inventory management, delivery performance, customer behavior, and business operations. Instead of writing SQL queries only to demonstrate syntax, every analysis in this project answers a meaningful business question that could help decision-makers improve operational efficiency.

---

# Project Overview

The objective of this project is to design a production-style relational database and use SQL to generate business insights for a quick commerce company.

Quick commerce businesses operate under strict delivery timelines while managing multiple dark stores, thousands of products, and constantly changing customer demand. Through this project, SQL is used to analyze business performance, monitor operational KPIs, evaluate inventory health, identify delivery bottlenecks, and support business intelligence reporting.

The project also includes Power BI dashboards that present the results in a clear and interactive format for business users.

---

# Business Problem

Quick commerce companies face several operational challenges every day, including:

* Managing inventory across multiple dark stores
* Maintaining product availability while reducing excess inventory
* Meeting delivery SLA commitments
* Reducing stockouts and lost sales
* Monitoring store performance across different cities
* Improving customer retention
* Increasing operational efficiency and profitability

This project uses data analytics to identify these challenges and provide insights that can support better business decisions.

---

# Dataset

This project uses a Quick Commerce dataset from Kaggle along with additional synthetic tables created to simulate a production database.

### Synthetic Tables

* Customers
* Orders
* Order Items
* Products
* Categories
* Inventory
* Dark Stores
* Deliveries
* Delivery Partners
* Cities
* Promotions
* Payments
* Returns

These additional tables create realistic relationships that support advanced SQL analysis and business reporting.

---

# Tech Stack

* PostgreSQL
* SQL
* Python
* Pandas
* Power BI
* Git
* GitHub

---

# Database Design

The database follows a normalized relational schema to reduce data redundancy and maintain data consistency.

The design includes:

* Primary keys for unique record identification
* Foreign keys to establish relationships between tables
* Constraints to maintain data integrity
* Indexes to improve query performance
* Proper normalization for efficient storage and easier maintenance

This structure closely resembles how transactional databases are designed in production environments.

---

# Project Workflow

The project was completed in the following phases:

### 1. Data Understanding

* Explored the dataset
* Understood business entities and relationships
* Identified important metrics

### 2. Data Cleaning

* Removed duplicate records
* Handled missing values
* Corrected inconsistent data
* Standardized formats

### 3. Database Design

* Created relational tables
* Defined keys and constraints
* Built relationships between entities

### 4. SQL Analysis

* Wrote analytical SQL queries
* Solved real business problems
* Generated operational insights

### 5. KPI Development

* Calculated business metrics
* Measured operational performance
* Evaluated inventory and delivery efficiency

### 6. Dashboard Creation

* Built interactive Power BI dashboards
* Created business-friendly visualizations
* Presented KPIs for decision-making

---

# SQL Concepts Used

This project applies a wide range of SQL concepts to answer real business questions rather than simply demonstrating SQL syntax.

The project includes:

* Joins
* CASE Statements
* Aggregate Functions
* Common Table Expressions (CTEs)
* Recursive CTEs
* Correlated Subqueries
* Window Functions
* Ranking Functions
* LAG and LEAD
* Running Totals
* Rolling Averages
* Percentiles
* Views
* Materialized Views
* Stored Procedures
* Query Optimization

Each SQL query is designed to solve a practical business problem related to operations, inventory, customer behavior, or business performance.

---

# Business KPIs

The following KPIs are calculated throughout the project:

* Fill Rate
* SLA Percentage
* Inventory Turnover
* Out-of-stock Rate
* Revenue Lost Due to Stockouts
* Average Order Value
* Repeat Customer Rate
* Revenue per Store
* Revenue per City
* Cancellation Rate
* Return Rate

These KPIs help measure overall business health and operational efficiency.

---

# Business Analysis

The project includes several business analyses, such as:

* Dark Store Performance
* Inventory Analysis
* Delivery Performance
* Product Performance
* Customer Behavior
* Peak Hour Analysis
* Weekend vs Weekday Sales
* Promotion Effectiveness
* Revenue Leakage

Each analysis focuses on identifying trends, measuring performance, and providing insights that can support business decisions.

---

# Power BI Dashboard

The Power BI report consists of multiple dashboard pages designed for different business functions.

### Executive Dashboard

Provides a high-level overview of overall business performance and key KPIs.

### Sales Dashboard

Tracks revenue, order volume, customer trends, and sales performance.

### Inventory Dashboard

Monitors inventory levels, stock availability, turnover, and stockout trends.

### Dark Store Dashboard

Compares store performance across locations and highlights operational efficiency.

### Delivery Dashboard

Analyzes delivery times, SLA compliance, cancellations, and delivery performance.

---


# Key Learnings

Working on this project helped me understand how SQL is used in real business environments rather than only in academic exercises.

I learned how to design a normalized relational database, build relationships between tables, and improve query performance using indexes and query optimization techniques. I also gained practical experience writing advanced SQL queries with window functions, CTEs, and analytical functions to solve business problems.

Building KPIs and Power BI dashboards helped me understand how business users interpret data and how analytics supports operational decision-making. Overall, this project strengthened both my technical skills and my understanding of business analytics.

---

# Future Improvements

Some enhancements that can be added in future versions include:

* Demand Forecasting
* Inventory Prediction
* Customer Segmentation
* Fraud Detection
* Real-time Dashboard
* Automated ETL Pipeline
* Docker Deployment

These improvements would make the project more scalable and closer to a production-ready analytics solution.

---

# Conclusion

This project demonstrates my ability to design relational databases, write advanced SQL queries, analyze business data, develop meaningful KPIs, and build interactive Power BI dashboards. It reflects how data analytics can be applied to solve practical business problems in the quick commerce industry and represents the skills I have developed as part of my preparation for data analytics and business intelligence roles.

