# 🛒 Olist E-Commerce Analytics Dashboard

An end-to-end data analytics project: raw e-commerce data → SQL transformation → Python processing → interactive Streamlit dashboard, deployed live on Streamlit Community Cloud.

**🔗 Live dashboard:** _add your Streamlit Cloud URL here after deployment_

![Python](https://img.shields.io/badge/Python-3.12-blue)
![SQL](https://img.shields.io/badge/SQL-SQLite-lightgrey)
![Streamlit](https://img.shields.io/badge/Dashboard-Streamlit-FF4B4B)

---

## 📊 Overview

This project analyzes **~99,000 real orders** from [Olist](https://olist.com), a Brazilian e-commerce marketplace, covering **Sep 2016 – Oct 2018**. It answers three questions:

1. **Sales & Revenue** — What's driving revenue, and where?
2. **Delivery Performance** — How reliable is the logistics network?
3. **Customer Experience** — What actually drives customer satisfaction?

**Key finding:** delivery speed is the single strongest driver of customer satisfaction in this dataset — average review score falls from **4.32/5** (delivered 8+ days early) to **1.70/5** (delivered 8+ days late).

## 🏗️ Architecture

```
Raw CSVs (Kaggle)
      │
      ▼
SQLite (raw load, unmodified)  ──▶  scripts/02_load_to_sqlite.py
      │
      ▼
SQL views (cleaning + aggregation)  ──▶  sql/*.sql
      │
      ▼
Parquet exports (dashboard-ready)  ──▶  scripts/04_export_views.py
      │
      ▼
Streamlit multipage dashboard  ──▶  dashboard/
```

Data flows one direction, and each stage is a separate, auditable artifact — the `.sql` files show the actual transformation logic, not just the output.

## 📁 Repository Structure

```
olist_project/
├── data/
│   ├── raw/                  # Source CSVs (gitignored — see Setup below)
│   └── processed/            # Parquet exports the dashboard reads (committed)
├── db/                       # olist.db (gitignored — regenerate locally)
├── sql/                      # SQL transformation scripts (portfolio artifact)
│   ├── 01_cleaning.sql
│   ├── 02_sales_analysis.sql
│   ├── 03_logistics_analysis.sql
│   └── 04_customer_reviews.sql
├── scripts/                  # Python pipeline scripts, run in order
│   ├── 01_inspect_data.py
│   ├── 02_load_to_sqlite.py
│   ├── 03_run_sql.py
│   └── 04_export_views.py
├── dashboard/                # Streamlit app (deployment entry point)
│   ├── app.py                 # Home page
│   ├── pages/                 # 3 dashboard pages (auto sidebar nav)
│   ├── data_loader.py          # Shared Parquet-loading helper
│   └── style.py                 # Shared color palette / chart styling
├── logs/                      # Pipeline run logs + PROJECT_LOG.md
├── .streamlit/config.toml     # App theme (must stay at repo root)
└── requirements.txt
```

## 🗄️ Dataset

[Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) (Kaggle) — 9 relational tables covering orders, order items, payments, reviews, products, customers, sellers, and geolocation.

## ⚙️ Setup — running this project locally

Raw data and the SQLite database are **not** included in this repo (kept out via `.gitignore` to keep it lightweight). To reproduce the full pipeline:

1. **Clone the repo**
   ```bash
   git clone <your-repo-url>
   cd olist_project
   ```

2. **Download the dataset** from [Kaggle](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), unzip, and place the 9 CSVs into `data/raw/` with these names:
   ```
   customers.csv, geolocation.csv, order_items.csv, order_payments.csv,
   order_reviews.csv, orders.csv, products.csv, sellers.csv, category_translation.csv
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Run the pipeline** (raw CSV → SQLite → SQL views → Parquet)
   ```bash
   python scripts/02_load_to_sqlite.py
   python scripts/03_run_sql.py
   python scripts/04_export_views.py
   ```

5. **Launch the dashboard**
   ```bash
   cd dashboard
   streamlit run app.py
   ```

`data/processed/*.parquet` (the dashboard's actual data source) **is** committed to this repo, so if you only want to run the dashboard without reproducing the pipeline, you can skip straight to step 3 and 5.

## 🛠️ Tech Stack

- **SQL** (SQLite) — data cleaning, joins, window functions, aggregation
- **Python** (pandas, pyarrow) — pipeline orchestration, Parquet export
- **Streamlit** + **Plotly** — interactive multipage dashboard
- **Streamlit Community Cloud** — deployment

## 📝 Development Log

See [`logs/PROJECT_LOG.md`](logs/PROJECT_LOG.md) for a full stage-by-stage record of decisions, data quality findings, and what was built at each step.

## 📄 License

Dataset is publicly available on Kaggle under its own license. Code in this repository is available for reference/portfolio purposes.
