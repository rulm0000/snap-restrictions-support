"""Draw the four-panel predictor x SNAP figures from Stata-exported plot data."""

from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.lines import Line2D

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "output" / "derived"
FIGS = ROOT / "output" / "figures"
FIGS.mkdir(parents=True, exist_ok=True)

NAVY = "#1A476F"
CRANBERRY = "#C10534"

SUPPORT_TICKS = {
    1: "Strongly oppose",
    2: "Somewhat oppose",
    3: "Neither oppose nor support",
    4: "Somewhat support",
    5: "Strongly support",
}

PANELS = [
    (
        "overconsume",
        "Self-reported soda overconsumption",
        [1, 2, 3, 4],
        ["Not at all", "Somewhat", "Mostly", "Definitely"],
    ),
    (
        "risk",
        "Perceived health risk of soda",
        [1, 2, 3, 4, 5],
        ["Not at all", "Very little", "Somewhat", "Quite a bit", "A great deal"],
    ),
    (
        "embarrass",
        "Embarrassment when paying with SNAP",
        [1, 2, 3, 4, 5],
        ["Never", "Rarely", "Sometimes", "Often", "Most or all\nof the time"],
    ),
    (
        "stigma",
        "Perceived stigma of SNAP policies",
        [1, 2, 3, 4, 5],
        [
            "Strongly\ndisagree",
            "Somewhat\ndisagree",
            "Neither\ndisagree\nnor agree",
            "Somewhat\nagree",
            "Strongly\nagree",
        ],
    ),
]

SERIES = [(0, "Non-SNAP", NAVY, "-"), (1, "SNAP", CRANBERRY, ":")]


def draw(df: pd.DataFrame, outstem: str, ylim: tuple[float, float] = (1, 5)) -> None:
    yticks = [t for t in SUPPORT_TICKS if ylim[0] <= t <= ylim[1]]
    ylabels = [SUPPORT_TICKS[t] for t in yticks]

    fig, axes = plt.subplots(2, 2, figsize=(10, 8.5), sharey=True)

    for ax, (key, xlabel, ticks, ticklabels) in zip(axes.flat, PANELS):
        panel = df[df["panel"] == key]
        for code, _, color, style in SERIES:
            grp = panel[panel["snapg"] == code].sort_values("x")
            ax.fill_between(grp["x"], grp["lo"], grp["hi"], color=color, alpha=0.18, linewidth=0)
            ax.plot(
                grp["x"],
                grp["est"],
                color=color,
                linestyle=style,
                linewidth=1.8,
                marker="o",
                markersize=4.5,
            )

        ax.set_ylim(*ylim)
        ax.set_yticks(yticks)
        ax.set_yticklabels(ylabels, fontsize=8)
        ax.set_xlim(min(ticks) - 0.4, max(ticks) + 0.4)
        ax.set_xticks(ticks)
        ax.set_xticklabels(ticklabels, fontsize=7.5)
        ax.set_xlabel(xlabel, fontsize=10, labelpad=8)
        ax.tick_params(axis="y", labelsize=8)
        ax.tick_params(axis="x", labelsize=7.5)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    fig.supylabel("How much do you oppose or support this policy?", fontsize=12)

    fig.tight_layout(rect=(0.04, 0.06, 1, 1))
    fig.subplots_adjust(hspace=0.55, wspace=0.12)

    handles = [
        Line2D([], [], color=color, linestyle=style, linewidth=1.8, marker="o", markersize=4.5, label=label)
        for _, label, color, style in SERIES
    ]
    # Center on the axes grid rather than the whole canvas, which is offset by the y-axis title
    left = axes[1, 0].get_position().x0
    right = axes[1, 1].get_position().x1
    fig.legend(
        handles=handles,
        loc="lower center",
        bbox_to_anchor=((left + right) / 2, 0.005),
        ncol=2,
        frameon=False,
        fontsize=10,
    )

    for ext in ("png", "pdf"):
        fig.savefig(FIGS / f"{outstem}.{ext}", dpi=300)
    plt.close(fig)
    print(f"wrote {outstem}.png / .pdf")


def main() -> None:
    adj = pd.read_csv(DATA / "plotdata_adjusted.csv")
    desc = pd.read_csv(DATA / "plotdata_descriptive.csv")
    draw(adj, "fig_predictors_x_snap")
    draw(desc, "fig_predictors_x_snap_descriptive")
    draw(adj, "fig_predictors_x_snap_zoom", ylim=(2, 4))
    draw(desc, "fig_predictors_x_snap_descriptive_zoom", ylim=(2, 4))


if __name__ == "__main__":
    main()
