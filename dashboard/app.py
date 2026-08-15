"""
app.py
-------
Home page of the Olist E-Commerce Dashboard. Streamlit auto-discovers
pages in the pages/ folder for sidebar navigation.

Run locally with: streamlit run app.py
"""
import streamlit as st

st.set_page_config(
    page_title="Olist E-Commerce Dashboard",
    page_icon="🛒",
    layout="wide",
)

st.title("🛒 Olist E-Commerce Dashboard")
st.markdown(
    """
    Analysis of **~99,000 real orders** from the Olist Brazilian marketplace
    (2016–2018), built with **SQL** (data cleaning & aggregation) and
    **Python/Streamlit** (this dashboard).
    """
)

st.divider()

col1, col2, col3, col4 = st.columns(4)
col1.metric("Total Revenue", "R$ 15.7M")
col2.metric("Total Orders", "98,199")
col3.metric("Avg Review Score", "4.09 / 5")
col4.metric("States Covered", "27")

st.divider()

st.subheader("What's in this dashboard")

c1, c2, c3 = st.columns(3)
with c1:
    st.markdown("### 📈 Sales & Revenue")
    st.write(
        "Monthly revenue trends, top product categories, revenue by state, "
        "and how customers pay."
    )
with c2:
    st.markdown("### 🚚 Delivery Performance")
    st.write(
        "On-time delivery rates by state, delay distribution, freight cost "
        "ratios, and the slowest shipping routes."
    )
with c3:
    st.markdown("### ⭐ Customer Experience")
    st.write(
        "Review score patterns — and the single strongest driver of "
        "satisfaction in this dataset: **delivery speed**."
    )

st.info("👈 Use the sidebar to explore each page.", icon="ℹ️")

st.divider()
st.caption(
    "Data: Olist Brazilian E-Commerce Public Dataset (Kaggle) · "
    "Pipeline: raw CSV → SQLite → SQL views → Parquet → Streamlit"
)
