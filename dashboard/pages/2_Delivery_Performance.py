"""
2_Delivery_Performance.py
----------------------------
Dashboard Page 2: Delivery / Logistics Performance.
Uses views: logistics_delivery_by_state, logistics_delay_distribution,
            logistics_freight_ratio, logistics_route_performance
"""
import streamlit as st
import plotly.express as px
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import style
from data_loader import load_view

st.set_page_config(page_title="Delivery Performance | Olist Dashboard", page_icon="🚚", layout="wide")
st.title("🚚 Delivery Performance")

by_state = load_view("logistics_delivery_by_state")
delay_dist = load_view("logistics_delay_distribution")
freight = load_view("logistics_freight_ratio")
routes = load_view("logistics_route_performance")

# ---------------------------------------------------------------------
# Headline metrics
# ---------------------------------------------------------------------
best_row = by_state.loc[by_state["pct_on_time"].idxmax()]
worst_row = by_state.loc[by_state["pct_on_time"].idxmin()]

col1, col2, col3 = st.columns(3)
col1.metric("Best On-Time State", best_row["customer_state"], f"{best_row['pct_on_time']:.1f}% on time")
col2.metric("Worst On-Time State", worst_row["customer_state"], f"{worst_row['pct_on_time']:.1f}% on time", delta_color="inverse")
col3.metric("Avg Delivery Time (all states)", f"{by_state['avg_delivery_days'].mean():.1f} days")

st.divider()

# ---------------------------------------------------------------------
# On-time rate by state
# ---------------------------------------------------------------------
st.subheader("On-Time Delivery Rate by Customer State")
sorted_state = by_state.sort_values("pct_on_time")
fig = px.bar(
    sorted_state,
    x="customer_state",
    y="pct_on_time",
    color="pct_on_time",
    color_continuous_scale=style.QUALITY,
    labels={"customer_state": "State", "pct_on_time": "% On Time"},
)
fig.update_layout(coloraxis_showscale=False)
fig.add_hline(
    y=by_state["pct_on_time"].mean(),
    line_dash="dash",
    line_color="#555",
    annotation_text="National avg",
)
st.plotly_chart(style.apply(fig, height=420), use_container_width=True)

st.divider()

col1, col2 = st.columns(2)

with col1:
    st.subheader("Delivery Delay Distribution")
    fig = px.bar(
        delay_dist,
        x="delay_bucket",
        y="num_orders",
        color="delay_bucket",
        color_discrete_sequence=style.PALETTE,
        labels={"delay_bucket": "Delay vs Estimate", "num_orders": "Orders"},
    )
    fig.update_layout(showlegend=False)
    st.plotly_chart(style.apply(fig, height=400), use_container_width=True)
    st.caption(
        "Most orders arrive well *before* the estimated date — Olist "
        "appears to pad delivery estimates generously."
    )

with col2:
    st.subheader("Freight Cost as % of Item Price")
    top_freight = freight.nlargest(10, "freight_pct_of_price").sort_values("freight_pct_of_price")
    fig = px.bar(
        top_freight,
        x="freight_pct_of_price",
        y="category_english",
        orientation="h",
        color="freight_pct_of_price",
        color_continuous_scale="Sunsetdark",
        labels={"freight_pct_of_price": "Freight as % of Price", "category_english": "Category"},
    )
    fig.update_layout(coloraxis_showscale=False)
    st.plotly_chart(style.apply(fig, height=400), use_container_width=True)
    st.caption("Categories where shipping cost eats the biggest share of the item's price.")

st.divider()

# ---------------------------------------------------------------------
# Slowest routes
# ---------------------------------------------------------------------
st.subheader("Slowest Seller → Customer State Routes")
st.caption("Routes with at least 20 orders, ranked by average delivery time.")
top_routes = routes.nlargest(15, "avg_delivery_days").sort_values("avg_delivery_days")
top_routes = top_routes.assign(
    route=top_routes.apply(lambda r: f"{r['seller_state']} → {r['customer_state']}", axis=1)
)
fig = px.bar(
    top_routes,
    x="avg_delivery_days",
    y="route",
    orientation="h",
    color="pct_on_time",
    color_continuous_scale=style.QUALITY,
    labels={"avg_delivery_days": "Avg Delivery Days", "route": "Route", "pct_on_time": "% On Time"},
)
st.plotly_chart(style.apply(fig, height=480), use_container_width=True)
