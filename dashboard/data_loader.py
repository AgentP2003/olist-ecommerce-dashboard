"""
data_loader.py
----------------
Shared data-loading module for the Streamlit dashboard. All dashboard
pages import from here rather than reading Parquet files directly -
keeps loading logic (and caching) in one place.

Usage (from a dashboard page):
    from data_loader import load_view
    df = load_view("sales_monthly_trend")
"""
import pandas as pd
import os
import streamlit as st

PROCESSED_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "processed")

VALID_VIEWS = {
    "sales_monthly_trend",
    "sales_by_category",
    "sales_by_state",
    "sales_payment_breakdown",
    "logistics_delivery_by_state",
    "logistics_delay_distribution",
    "logistics_freight_ratio",
    "logistics_route_performance",
    "reviews_score_distribution",
    "reviews_score_by_delay",
    "reviews_score_by_category",
    "reviews_score_by_payment",
}

@st.cache_data
def load_view(view_name: str) -> pd.DataFrame:
    """
    Load a pre-exported analysis view from data/processed/<view_name>.parquet.
    Cached by Streamlit so repeated calls across page reruns don't hit disk again.
    """
    if view_name not in VALID_VIEWS:
        raise ValueError(
            f"Unknown view '{view_name}'. Valid views: {sorted(VALID_VIEWS)}"
        )
    path = os.path.join(PROCESSED_DIR, f"{view_name}.parquet")
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"{path} not found. Run scripts/04_export_views.py to generate it."
        )
    return pd.read_parquet(path)
