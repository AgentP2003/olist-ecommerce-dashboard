"""
style.py
---------
Shared color palette and Plotly styling helpers so every dashboard page
looks consistent. Bold, saturated palette by design (per project brief).

Usage:
    import style
    fig = px.bar(df, x=..., y=..., color_discrete_sequence=style.PALETTE)
    st.plotly_chart(style.apply(fig), use_container_width=True)
"""
import plotly.graph_objects as go

# Bold, high-contrast qualitative palette - used for categorical charts
PALETTE = [
    "#FF4B4B",  # red
    "#1F77B4",  # blue
    "#FFA600",  # amber
    "#2CA02C",  # green
    "#9D4EDD",  # purple
    "#F72585",  # pink
    "#00B4D8",  # cyan
    "#FB8500",  # orange
    "#4CC9F0",  # sky
    "#7209B7",  # violet
]

# Sequential palette for continuous values (revenue, counts)
SEQUENTIAL = "Plasma"

# Diverging/quality palette for scores or on-time % (red=bad, green=good)
QUALITY = "RdYlGn"

DEFAULT_HEIGHT = 420


def apply(fig: go.Figure, height: int = DEFAULT_HEIGHT) -> go.Figure:
    """Apply consistent layout styling to a Plotly figure."""
    fig.update_layout(
        height=height,
        title=dict(text=""),  # avoid stray "undefined" title some Plotly/Streamlit versions inject
        font=dict(family="sans serif", size=13, color="#262730"),
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
        margin=dict(t=20, l=10, r=10, b=10),
        legend=dict(bgcolor="rgba(0,0,0,0)"),
    )
    fig.update_xaxes(gridcolor="#E8E8E8", zeroline=False)
    fig.update_yaxes(gridcolor="#E8E8E8", zeroline=False)
    return fig
