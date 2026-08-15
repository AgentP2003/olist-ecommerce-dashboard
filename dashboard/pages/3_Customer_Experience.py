"""
3_Customer_Experience.py
---------------------------
Dashboard Page 3: Customer Experience & Reviews.
Uses views: reviews_score_distribution, reviews_score_by_delay,
            reviews_score_by_category, reviews_score_by_payment
"""
import streamlit as st
import plotly.express as px
import sys
import os

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import style
from data_loader import load_view

st.set_page_config(page_title="Customer Experience | Olist Dashboard", page_icon="⭐", layout="wide")
st.title("⭐ Customer Experience")

score_dist = load_view("reviews_score_distribution")
score_by_delay = load_view("reviews_score_by_delay")
score_by_category = load_view("reviews_score_by_category")
score_by_payment = load_view("reviews_score_by_payment")

# ---------------------------------------------------------------------
# Headline metrics
# ---------------------------------------------------------------------
weighted_avg = (score_dist["review_score"] * score_dist["num_reviews"]).sum() / score_dist["num_reviews"].sum()
pct_5star = score_dist.loc[score_dist["review_score"] == 5, "pct_of_total"].values[0]

col1, col2, col3 = st.columns(3)
col1.metric("Avg Review Score", f"{weighted_avg:.2f} / 5")
col2.metric("5-Star Reviews", f"{pct_5star:.1f}%")
col3.metric("Total Reviews", f"{score_dist['num_reviews'].sum():,}")

st.divider()

col1, col2 = st.columns(2)

with col1:
    st.subheader("Review Score Distribution")
    fig = px.bar(
        score_dist,
        x="review_score",
        y="num_reviews",
        color="review_score",
        color_continuous_scale=style.QUALITY,
        labels={"review_score": "Stars", "num_reviews": "Number of Reviews"},
    )
    fig.update_layout(coloraxis_showscale=False)
    fig.update_xaxes(dtick=1)
    st.plotly_chart(style.apply(fig, height=400), use_container_width=True)

with col2:
    st.subheader("🔑 Delivery Delay vs Review Score")
    fig = px.bar(
        score_by_delay,
        x="delay_bucket",
        y="avg_review_score",
        color="avg_review_score",
        color_continuous_scale=style.QUALITY,
        range_color=[1, 5],
        labels={"delay_bucket": "Delivery Timing", "avg_review_score": "Avg Review Score"},
    )
    fig.update_layout(coloraxis_showscale=False)
    st.plotly_chart(style.apply(fig, height=400), use_container_width=True)
    st.caption(
        f"**Key finding:** avg score falls from "
        f"{score_by_delay.iloc[0]['avg_review_score']:.2f} (early) to "
        f"{score_by_delay.iloc[-1]['avg_review_score']:.2f} (8+ days late) — "
        f"delivery delay is the strongest visible driver of satisfaction in this data."
    )

st.divider()

col1, col2 = st.columns(2)

with col1:
    st.subheader("Lowest-Rated Categories")
    worst_cat = score_by_category.nsmallest(10, "avg_review_score").sort_values("avg_review_score", ascending=False)
    fig = px.bar(
        worst_cat,
        x="avg_review_score",
        y="category_english",
        orientation="h",
        color="avg_review_score",
        color_continuous_scale=style.QUALITY,
        range_color=[1, 5],
        labels={"avg_review_score": "Avg Review Score", "category_english": "Category"},
    )
    fig.update_layout(coloraxis_showscale=False)
    st.plotly_chart(style.apply(fig, height=420), use_container_width=True)

with col2:
    st.subheader("Review Score by Payment Type & Installments")
    fig = px.bar(
        score_by_payment,
        x="payment_type",
        y="avg_review_score",
        color="installments_bucket",
        barmode="group",
        color_discrete_sequence=style.PALETTE,
        labels={
            "payment_type": "Payment Type",
            "avg_review_score": "Avg Review Score",
            "installments_bucket": "Installments",
        },
    )
    fig.update_yaxes(range=[0, 5])
    st.plotly_chart(style.apply(fig, height=420), use_container_width=True)
