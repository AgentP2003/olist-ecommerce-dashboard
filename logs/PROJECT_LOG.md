# Project Log — Olist E-Commerce Dashboard

Running log of everything done on this project, in order. Update this after
every stage/session.

---

## Stage 0: Planning
- **Goal:** DS-focused portfolio project. SQL + Python transformation → dashboard → deployment. No ML by design (deployment/pipeline practice is the point).
- **Dataset chosen:** Olist Brazilian E-Commerce Public Dataset (Kaggle)
  - Link: https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
  - Why: relational (9 linked tables) → forces real SQL joins/CTEs/window functions, real business data, not overused like Titanic/Superstore.
- **Stack decided:**
  - DB: SQLite (zero-setup, file-based, easy for Streamlit Cloud)
  - Transformation: SQL (kept as visible `.sql` files — portfolio artifact) + Python (pandas layer on top)
  - Dashboard: Streamlit
  - Hosting: Streamlit Community Cloud + GitHub

## Stage 1: Data Acquisition & Setup — ✅ DONE

**Date:** 2026-08-15

1. User downloaded all 9 CSVs manually from Kaggle and uploaded them.
2. Created project folder structure:
   ```
   olist_project/
   ├── data/raw/        <- original CSVs, untouched
   ├── db/               <- olist.db (SQLite database)
   ├── sql/              <- SQL transformation scripts (portfolio artifact)
   ├── scripts/          <- Python scripts (numbered, run in order)
   └── logs/             <- inspection logs, this file
   ```
3. **`scripts/01_inspect_data.py`** — inspected all 9 CSVs: shape, dtypes, nulls, duplicates, sample rows.
   - Output: `logs/01_data_inspection.log`
   - Findings:
     - `geolocation`: 261,831 duplicate rows (expected, multiple lat/lng per zip) — to dedupe in SQL
     - `order_reviews`: high nulls in comment title/message (normal — most reviews are rating-only)
     - `orders`: nulls in approval/delivery date columns (160–2,965 rows) — expected for cancelled/undelivered orders; useful for delivery performance analysis
     - `products`: 610 rows missing category name; 2 rows missing dimensions — to clean in SQL
     - All other tables: clean, no nulls, no dupes
4. **`scripts/02_load_to_sqlite.py`** — loaded all 9 CSVs into SQLite **as-is, unmodified**, prefixed `raw_*` (e.g. `raw_orders`, `raw_customers`).
   - Output: `db/olist.db`
   - Rationale: keeping raw load separate from cleaning means all cleaning/transformation logic lives visibly in `.sql` files, not hidden in the Python ingestion step.
   - Verified row counts match source CSVs exactly.

**Tables in `olist.db` after Stage 1:**
| Table | Rows | Cols |
|---|---|---|
| raw_customers | 99,441 | 5 |
| raw_geolocation | 1,000,163 | 5 |
| raw_order_items | 112,650 | 7 |
| raw_order_payments | 103,886 | 5 |
| raw_order_reviews | 99,224 | 7 |
| raw_orders | 99,441 | 8 |
| raw_products | 32,951 | 9 |
| raw_sellers | 3,095 | 4 |
| raw_category_translation | 71 | 2 |

## Stage 2: SQL Transformation — ✅ DONE

**Date:** 2026-08-15

**Decisions:**
- Dashboard scope: broad, 3-page (Sales & Revenue / Delivery Performance / Customer Experience)
- SQL output: **views** (not materialized tables) — lighter, recomputed live, standard practice
- 4 SQL scripts, run in order via `scripts/03_run_sql.py`

**`sql/01_cleaning.sql`** — base cleaning layer (6 views)
- `clean_orders` — typed dates, `delivery_delay_days`, `delivery_duration_days`, `is_on_time` flag derived
- `clean_products` — joined with English category translation, nulls → 'unknown'
- `clean_geolocation` — 1,000,163 raw rows deduped to 19,015 unique zip prefixes (avg lat/lng + most frequent city/state via window function; initial correlated-subquery approach was too slow, rewrote using `ROW_NUMBER() OVER (PARTITION BY ...)`)
- `clean_order_items` — typed, added `item_total_value` (price + freight)
- `clean_payments` — excluded 3 rows with `payment_type = 'not_defined'`
- `clean_reviews` — added `has_title`/`has_message` boolean flags

**`sql/02_sales_analysis.sql`** — Page 1 views (4 views)
- `sales_monthly_trend`, `sales_by_category`, `sales_by_state`, `sales_payment_breakdown`
- Excludes `canceled`/`unavailable` order statuses from revenue (no real transaction completed)
- Finding: clear revenue growth trend 2016→2018; Sep 2016 and Sep 2018 are partial months (1-2 orders) — flag for dashboard to exclude/annotate

**`sql/03_logistics_analysis.sql`** — Page 2 views (4 views)
- `logistics_delivery_by_state`, `logistics_delay_distribution`, `logistics_freight_ratio`, `logistics_route_performance`
- Finding: on-time delivery rate ranges from ~76% (AL) to high 90s% by state; some seller→customer routes average 30+ days

**`sql/04_customer_reviews.sql`** — Page 3 views (4 views)
- `reviews_score_distribution`, `reviews_score_by_delay`, `reviews_score_by_category`, `reviews_score_by_payment`
- **Key finding (good dashboard headline):** avg review score drops from 4.32 (delivered 8+ days early) to 1.70 (delivered 8+ days late) — delivery delay is the strongest visible driver of satisfaction in this dataset

**`scripts/03_run_sql.py`** — runs all 4 SQL scripts in order against `db/olist.db`, idempotent (all views use `DROP VIEW IF EXISTS`). Full rebuild (raw CSV → all 20 views) takes under 2 seconds.

**Total views in database: 20** (6 cleaning + 4 sales + 4 logistics + 4 reviews + 2 internal helper views for geolocation mode calculation)

## Stage 3: Python Layer — ✅ DONE

**Date:** 2026-08-15

**Decision:** Fully decouple the dashboard from the database. Python exports each analysis view to Parquet; Streamlit app reads only from Parquet files, never queries SQLite live. Rationale: avoids SQLite file-locking/concurrency issues on Streamlit Cloud, faster app cold-starts, and the app has zero dependency on the DB being present/correct at runtime.

**`scripts/04_export_views.py`**
- Connects to `db/olist.db`, exports all 12 dashboard-facing analysis views (4 sales + 4 logistics + 4 reviews) to individual Parquet files in `data/processed/`
- Excludes the 6 `clean_*` base views (intermediate only) and 2 internal `_geo_*` helper views — dashboard only needs final aggregated views
- All 12 files total well under 100KB combined (pre-aggregated summary data, not row-level)
- Installed `pyarrow` as a dependency for Parquet support

**`dashboard/data_loader.py`**
- Shared module the dashboard pages will import from (`from data_loader import load_view`)
- `load_view(view_name)` reads the corresponding Parquet file, validated against an allow-list, wrapped in `@st.cache_data` so repeated calls across Streamlit reruns don't hit disk again
- Tested standalone — loads correctly with proper dtypes preserved

**Data pipeline end-to-end (re-run order):**
```
python scripts/02_load_to_sqlite.py    # raw CSVs -> olist.db
python scripts/03_run_sql.py           # build all 20 SQL views
python scripts/04_export_views.py      # export 12 views -> Parquet
```

## Stage 4: Dashboard (Streamlit) — ✅ DONE

**Date:** 2026-08-15

**Decisions:**
- Navigation: Streamlit native multipage (auto sidebar nav via `pages/` folder)
- Visual style: bold & colorful — custom Plotly styling with a saturated 10-color palette, Plasma/RdYlGn scales for continuous data
- Charting library: Plotly (via `plotly.express`) for interactivity and vibrant visuals

**Structure built:**
```
dashboard/
├── app.py                          <- Home page (run: streamlit run app.py)
├── data_loader.py                  <- load_view() - reads Parquet, @st.cache_data (from Stage 3)
├── style.py                        <- PALETTE, SEQUENTIAL, QUALITY color scales, apply() layout helper
├── requirements.txt                <- streamlit, pandas, plotly, pyarrow
├── .streamlit/config.toml          <- app-wide theme colors (red primary #FF4B4B)
└── pages/
    ├── 1_Sales_Revenue.py          <- monthly trend, top categories, top states, payment breakdown
    ├── 2_Delivery_Performance.py   <- on-time rate by state, delay distribution, freight ratio, slowest routes
    └── 3_Customer_Experience.py    <- review distribution, delay-vs-score (headline chart), worst categories, payment vs score
```

**app.py (Home):** headline KPIs (total revenue, orders, avg review score, states covered) and a 3-column guide to the pages.

**Page 1 (Sales & Revenue):** monthly revenue bar chart (Sep 2016 / Sep 2018 excluded — partial months, 1-2 orders each), top 10 categories, top 10 states, payment method donut + breakdown table.

**Page 2 (Delivery Performance):** on-time % by state with national-average line, delay-distribution histogram, freight-cost-as-%-of-price by category, 15 slowest seller→customer routes.

**Page 3 (Customer Experience):** review score distribution, delay-vs-score bar chart (called out as the headline finding), lowest-rated categories, review score by payment type/installments (grouped bar).

**Bug found & fixed:** Plotly charts were rendering a stray `<b>undefined</b>` title (a Streamlit/Plotly version quirk when no explicit title is set on the figure). Fixed by forcing `title=dict(text="")` inside `style.apply()`, which every chart on every page passes through.

**Testing performed:**
- Ran the app locally (`streamlit run app.py`) inside the sandbox; confirmed all 4 routes (Home + 3 pages) return HTTP 200 with a clean server log (no exceptions)
- Directly executed each page's data-loading/transform logic outside Streamlit to catch pandas/logic errors — all passed
- Used Playwright (headless Chromium) to screenshot every page and visually verify correct chart rendering, correct colors/theme, and confirmed the "undefined" title bug was fully resolved after the fix

**Reference numbers surfaced in the dashboard:**
- Total revenue ≈ R$15.7M · 98,199 orders · avg review score 4.09/5 · 27 states
- Best on-time state: RO (97.1%) · worst: AL (76.1%) · avg delivery time 18.8 days
- Review score falls from 4.32 → 1.70 as delivery goes from 8+ days early to 8+ days late

## Stage 5: GitHub Structure — ✅ DONE

**Date:** 2026-08-16

**Decisions confirmed with user:**
- Exclude `data/raw/*.csv` and `db/olist.db` from git (kept locally, gitignored for GitHub) — repo stays lean, only code + small Parquet outputs are pushed
- Whole `olist_project/` is the repo root — single cohesive repo showing the full SQL → Python → dashboard pipeline

**Important fix found via Streamlit Cloud docs:** `.streamlit/config.toml` must live at the **repo root**, not next to the app entrypoint, whenever the entrypoint file is in a subdirectory (Community Cloud only recognizes one config file, at the root). Moved `dashboard/.streamlit/config.toml` → `.streamlit/config.toml` at project root. Also moved `requirements.txt` to the project root (Streamlit Cloud checks entrypoint directory first, then root — root is the cleaner convention for this repo layout). Re-verified the app still runs correctly after both moves.

**Files created:**
- **`.gitignore`** — excludes `data/raw/*.csv`, `db/*.db`, Python cache/venv files, `.streamlit/secrets.toml`, OS cruft. Explicitly keeps `data/raw/.gitkeep` and `db/.gitkeep` so the folder structure stays visible in the repo. `data/processed/*.parquet` and all `logs/*.log` files ARE committed (small, and useful portfolio/validation evidence).
- **`README.md`** — full project README: architecture diagram, repo structure, dataset info, local setup instructions (clone → download CSVs → run 3 pipeline scripts → launch dashboard), tech stack, link to PROJECT_LOG.md, live Streamlit Cloud URL (added in Stage 6)
- **`data/raw/.gitkeep`**, **`db/.gitkeep`** — placeholders so gitignored-but-empty folders still exist in the repo

**Git setup:**
- Ran `git init`, staged all files, confirmed via `git check-ignore -v` that raw CSVs and `olist.db` are correctly excluded while remaining untouched on local disk
- First commit made: 37 files tracked, **`.git` folder is only 520KB** (vs. the ~91MB it would be with raw data included)

**What's committed (37 files):** `.gitignore`, `README.md`, `requirements.txt`, `.streamlit/config.toml`, all 4 `sql/*.sql` scripts, all 4 `scripts/*.py` pipeline scripts, all 12 `data/processed/*.parquet` files, all dashboard code (`app.py`, `data_loader.py`, `style.py`, 3 pages), all `logs/*` (including `PROJECT_LOG.md`), and the 2 `.gitkeep` placeholders.

**What's local-only (not in git):** `data/raw/*.csv` (9 files, ~120MB), `db/olist.db` (~112MB).

**Next step for the user:** create a new GitHub repo, then from inside `olist_project/`:
```bash
git remote add origin <your-github-repo-url>
git branch -M main
git push -u origin main
```

## Stage 6: Deployment (Streamlit Cloud) — ✅ DONE

**Date:** 2026-08-16

**Repo:** https://github.com/AgentP2003/olist-ecommerce-dashboard
**Live app:** https://olist-ecommerce-dashboardbranchmain-tnnk8f4rhzfstnr2cj3oes.streamlit.app

**What was done:**
- Pushed local repo to GitHub (`git remote add origin` → `git push -u origin main`), first push authenticated via browser (Git Credential Manager)
- Deployed on Streamlit Community Cloud: repo `AgentP2003/olist-ecommerce-dashboard`, branch `main`, Main file path `dashboard/app.py`
- Verified all 4 pages (Home, Sales & Revenue, Delivery Performance, Customer Experience) render correctly on the live URL, matching local testing
- Confirmed local reproducibility end-to-end: `data/raw/*.csv` (9 files) + `db/olist.db` + all pipeline scripts are present locally, so the full pipeline (raw CSV → SQLite → SQL views → Parquet → dashboard) can be rebuilt from scratch at any time. `db/olist.db` itself is fully derived/regenerable from raw CSVs via `scripts/02_load_to_sqlite.py` + `scripts/03_run_sql.py` — not something that needs separate backup.
- Updated `README.md` with the live dashboard link, live badge, and correct clone URL (previously placeholders)

**Issues hit during deployment (for reference):**
- Local `streamlit` command not recognized on Windows (PATH issue) — worked around with `python -m streamlit run app.py` instead of the bare `streamlit` command
- First Streamlit Cloud app-creation form submission had fields mis-filled (repo/branch/path values landed in the wrong boxes) — resolved by clearing and re-entering each field individually

**Project status: all 6 stages complete.** Full pipeline is live, reproducible, version-controlled, and documented (technical + non-technical write-ups also produced separately for portfolio use).
