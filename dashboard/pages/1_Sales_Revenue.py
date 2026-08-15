"""
1_Sales_Revenue.py
--------------------
Dashboard Page 1: Sales & Revenue.
Uses views: sales_monthly_trend, sales_by_category, sales_by_state,
            sales_payment_breakdown
"""
import streamlit as st
import plotly.express as px
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import style
from data_loader import load_view

st.set_page_config(page_title="Sales & Revenue | Olist Dashboard", page_icon="📈", layout="wide")
st.title("📈 Sales & Revenue")

# ---------------------------------------------------------------------
# Monthly trend
# ---------------------------------------------------------------------
df_trend = load_view("sales_monthly_trend")
# Sep 2016 (2 orders) and Sep 2018 (1 order) are partial months in the
# source data - excluded so they don't read as real dips.
df_trend_plot = df_trend[~df_trend["year_month"].isin(["2016-09", "2018-09"])]

st.subheader("Monthly Revenue Trend")
fig = px.bar(
    df_trend_plot,
    x="year_month",
    y="total_revenue",
    labels={"year_month": "Month", "total_revenue": "Revenue (R$)"},
    color_discrete_sequence=[style.PALETTE[0]],
)
st.plotly_chart(style.apply(fig, height=420), use_container_width=True)
st.caption(
    "Note: Sep 2016 and Sep 2018 excluded — partial months in the source "
    "data (1-2 orders each), not real dips."
)

st.divider()

# ---------------------------------------------------------------------
# Category + State side by side
# ---------------------------------------------------------------------
col1, col2 = st.columns(2)

with col1:
    st.subheader("Top 10 Categories by Revenue")
    df_cat = load_view("sales_by_category").head(10).sort_values("total_revenue")
    fig_cat = px.bar(
        df_cat,
        x="total_revenue",
        y="category_english",
        orientation="h",
        labels={"total_revenue": "Revenue (R$)", "category_english": ""},
        color="total_revenue",
        color_continuous_scale=style.SEQUENTIAL,
    )
    fig_cat.update_layout(coloraxis_showscale=False)
    st.plotly_chart(style.apply(fig_cat, height=420), use_container_width=True)

with col2:
    st.subheader("Revenue by State (Top 10)")
    df_state = load_view("sales_by_state").head(10).sort_values("total_revenue")
    fig_state = px.bar(
        df_state,
        x="total_revenue",
        y="customer_state",
        orientation="h",
        labels={"total_revenue": "Revenue (R$)", "customer_state": ""},
        color="total_revenue",
        color_continuous_scale=style.SEQUENTIAL,
    )
    fig_state.update_layout(coloraxis_showscale=False)
    st.plotly_chart(style.apply(fig_state, height=420), use_container_width=True)

st.divider()

# ---------------------------------------------------------------------
# Payment breakdown
# ---------------------------------------------------------------------
st.subheader("Payment Method Breakdown")
df_pay = load_view("sales_payment_breakdown")

col3, col4 = st.columns([1, 1])
with col3:
    fig_pay = px.pie(
        df_pay,
        names="payment_type",
        values="total_paid",
        hole=0.45,
        color_discrete_sequence=style.PALETTE,
    )
    fig_pay.update_traces(textinfo="percent+label")
    st.plotly_chart(style.apply(fig_pay, height=380), use_container_width=True)
with col4:
    st.dataframe(
        df_pay.rename(columns={
            "payment_type": "Payment Type",
            "num_orders": "Orders",
            "total_paid": "Total Paid (R$)",
            "avg_installments": "Avg Installments",
        }),
        use_container_width=True,
        hide_index=True,
    )
