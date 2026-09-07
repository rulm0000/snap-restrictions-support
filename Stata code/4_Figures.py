"""Draw AJPH/supplement interaction figures and standardized-effects forest plot."""

from __future__ import annotations

import io
import shutil
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.transforms as mtransforms
import numpy as np
import pandas as pd
from matplotlib.lines import Line2D
from matplotlib.patches import Polygon
from PIL import Image

plt.rcParams["font.family"] = "sans-serif"
plt.rcParams["font.sans-serif"] = ["Arial", "Helvetica", "Liberation Sans", "DejaVu Sans"]

DATA = Path(sys.argv[1])
FIGS = Path(sys.argv[2]) / "Figures"
ARCHIVE = FIGS / "Archive"
FIGS.mkdir(parents=True, exist_ok=True)

NAVY = "#1A476F"
CRANBERRY = "#C10534"
KEEP_FIGURE_STEMS = {
    "fig_predictors_x_snap",       # 4-panel Figure 1 (primary, first submission)
    "fig_predictors_x_snap_AJPH",  # 2-panel fallback if AJPH rejects 4 panels
    "fig_standardized_effects_supplement",
    "fig_predictors_x_snap_slopeP",
}

SUPPORT_TICKS = {
    1: "Strongly oppose",
    2: "Somewhat oppose",
    3: "Neither oppose nor support",
    4: "Somewhat support",
    5: "Strongly support",
}

# 2-panel fallback figure (only if AJPH rejects the 4-panel): risk then paternalism
PANELS_AJPH = [
    (
        "risk",
        "Perceived health risk of soda",
        [1, 2, 3, 4, 5],
        ["Not at all", "Very little", "Somewhat", "Quite a bit", "A great deal"],
    ),
    (
        "stigma",
        "Perceived paternalism of SNAP policies",
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

# Panels for the two factors omitted from the 2-panel fallback; also reused in
# the full 4-panel Figure 1. Factor order per 8/17 decision:
# overconsumption, risk, embarrassment, paternalism.
PANELS_OTHER = [
    (
        "overconsume",
        "Self-reported soda overconsumption",
        [1, 2, 3, 4],
        ["Not at all", "Somewhat", "Mostly", "Definitely"],
    ),
    (
        "embarrass",
        "Felt judged when paying with SNAP",
        [1, 2, 3, 4, 5],
        ["Never", "Rarely", "Sometimes", "Often", "Most or all\nof the time"],
    ),
]

# Full 4-panel Figure 1 (A=overconsumption, B=risk, C=embarrassment, D=paternalism)
PANELS_ALL = [PANELS_OTHER[0], PANELS_AJPH[0], PANELS_OTHER[1], PANELS_AJPH[1]]

# Wald tests of each predictor x SNAP interaction (2_Main_Analysis.log / Table 3)
# Interaction Wald tests, copied from Table 3 of the weighted run.
# NOTE: these are literals. If the model or data change, update them to match
# the p for interaction column of Table3_Predictors_by_SNAP.xlsx.
# Within-group simple slopes (Table 3, WEIGHTED run), AMA style.
# Set SHOW_SLOPE_P=True to render the 3-line corner block.
SLOPE_P = {
    "overconsume": ("$P$ = .04", "$P$ = .29"),
    "risk":        ("$P$ < .001", "$P$ < .001"),
    "embarrass":   ("$P$ < .001", "$P$ = .95"),
    "stigma":      ("$P$ < .001", "$P$ = .24"),
}
SHOW_SLOPE_P = False

INTERACTION_P = {
    "overconsume": "Interaction $P$ = .02",
    "risk": "Interaction $P$ = .27",
    "embarrass": "Interaction $P$ < .001",
    "stigma": "Interaction $P$ < .001",
}

TIFF_DPI = 600
SERIES = [(0, "Non-recipients", NAVY, "-"), (1, "SNAP recipients", CRANBERRY, ":")]


def save_tiff(fig, path: Path, dpi: int = TIFF_DPI) -> None:
    """Write a print-production TIFF: flattened to RGB on white, LZW-compressed."""
    buf = io.BytesIO()
    fig.savefig(buf, format="png", dpi=dpi)
    buf.seek(0)
    with Image.open(buf) as im:
        flat = Image.new("RGB", im.size, "white")
        flat.paste(im, mask=im.split()[-1] if im.mode == "RGBA" else None)
        flat.save(path, format="TIFF", dpi=(dpi, dpi), compression="tiff_lzw")


def draw(
    df: pd.DataFrame,
    outstem: str,
    panels: list,
    nrows: int,
    ncols: int,
    figsize: tuple[float, float],
    ylim: tuple[float, float] = (1, 5),
    pvals: dict[str, str] | None = None,
) -> None:
    yticks = [t for t in SUPPORT_TICKS if ylim[0] <= t <= ylim[1]]
    ylabels = [SUPPORT_TICKS[t] for t in yticks]
    letters = list("ABCDEFGHIJ")[: len(panels)]

    fig, axes = plt.subplots(nrows, ncols, figsize=figsize, sharey=True)
    ax_list = list(axes.flat) if hasattr(axes, "flat") else [axes]

    for ax, letter, (key, xlabel, ticks, ticklabels) in zip(ax_list, letters, panels):
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

        ax.set_title(
            letter,
            loc="left",
            fontweight="bold",
            fontsize=12,
            pad=18,
            x=-0.06,
            bbox=dict(boxstyle="square,pad=0.35", facecolor="white", edgecolor="black", linewidth=0.8),
        )
        if pvals is not None and key in pvals:
            block = [(pvals[key], "#3D3D3D")]
            if SHOW_SLOPE_P and key in SLOPE_P:
                p_non, p_snap = SLOPE_P[key]
                block += [
                    (f"SNAP recipients {p_snap}", CRANBERRY),
                    (f"Non-recipients {p_non}", NAVY),
                ]
            for i, (txt, col) in enumerate(block):
                ax.text(
                    0.97,
                    (0.035 + i * 0.058) if len(block) > 1 else 0.04,
                    txt,
                    transform=ax.transAxes,
                    ha="right",
                    va="bottom",
                    fontsize=8.0 if len(block) > 1 else 8.5,
                    color=col,
                )

        ax.set_ylim(*ylim)
        ax.set_yticks(yticks)
        ax.set_yticklabels(ylabels, fontsize=8)
        ax.set_xlim(min(ticks) - 0.4, max(ticks) + 0.4)
        ax.set_xticks(ticks)
        ax.set_xticklabels(ticklabels, fontsize=8)
        ax.set_xlabel(xlabel, fontsize=10, labelpad=8)
        ax.tick_params(axis="y", labelsize=8)
        ax.tick_params(axis="x", labelsize=8)
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)

    # Hide unused axes if any
    for ax in ax_list[len(panels) :]:
        ax.set_visible(False)

    fig.supylabel("How much do you oppose or support this policy?", fontsize=14, x=0.035)

    if nrows == 1:
        fig.tight_layout(rect=(0.015, 0.14, 1, 1))
        fig.subplots_adjust(wspace=0.18)
        leg_y = 0.02
        left = ax_list[0].get_position().x0
        right = ax_list[len(panels) - 1].get_position().x1
    else:
        fig.tight_layout(rect=(0.015, 0.10, 1, 1))
        fig.subplots_adjust(hspace=0.55, wspace=0.12)
        leg_y = 0.005
        left = ax_list[2].get_position().x0 if len(panels) > 2 else ax_list[0].get_position().x0
        right = ax_list[min(3, len(panels) - 1)].get_position().x1

    handles = [
        Line2D([], [], color=color, linestyle=style, linewidth=1.8, marker="o", markersize=4.5, label=label)
        for _, label, color, style in SERIES
    ]
    leg = fig.legend(
        handles=handles,
        loc="lower center",
        bbox_to_anchor=((left + right) / 2, leg_y),
        ncol=2,
        frameon=True,
        fancybox=False,
        edgecolor="black",
        framealpha=1,
        borderpad=0.7,
        title="SNAP status",
        fontsize=10,
        title_fontsize=10,
    )
    leg.get_frame().set_linewidth(0.8)

    for ext in ("png", "pdf"):
        fig.savefig(FIGS / f"{outstem}.{ext}", dpi=300)
    save_tiff(fig, FIGS / f"{outstem}.tif")
    plt.close(fig)
    print(f"wrote {outstem}.png / .pdf / .tif")


def archive_other_figures(keep_stems: set[str] | None = None) -> None:
    """Move figure files not matching keep_stems into figures/Archive/."""
    if keep_stems is None:
        keep_stems = KEEP_FIGURE_STEMS
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    for path in FIGS.iterdir():
        if not path.is_file():
            continue
        if path.stem in keep_stems:
            continue
        dest = ARCHIVE / path.name
        if dest.exists():
            dest.unlink()
        shutil.move(str(path), str(dest))
        print(f"archived {path.name}")


def _fmt_num(x: float) -> str:
    """Format with two decimals; keep minus for negatives, no plus sign."""
    return f"{x:.2f}"


def _fmt_d(d: float, lo: float, hi: float, is_ref: bool) -> str:
    if is_ref:
        return "reference"
    return f"{_fmt_num(d)} ({_fmt_num(lo)}, {_fmt_num(hi)})"


def draw_standardized_effects_forest(
    csv_path: Path | None = None,
    outstem: str = "fig_standardized_effects_supplement",
) -> None:
    """Forest plot of Table 2 standardized estimates (supplement).

    Continuous psychological factors: standardized regression coefficients (β).
    SNAP participation and covariate categories: standardized mean differences (SMD).
    """
    path = csv_path or (DATA / "plotdata_standardized_effects.csv")
    if not path.exists():
        raise FileNotFoundError(
            f"Missing {path.name}; run 4_Tables.do first to export forest-plot data."
        )

    df = pd.read_csv(path)
    df["is_ref"] = df["is_ref"].astype(int)
    if len(df) == 0:
        raise ValueError("No rows in standardized-effects plot data.")

    # Fixed plotting window; arrows mark CIs that extend past the bounds
    # (-0.3 floor per Clayton 8/17: paternalism CI lo ≈ -0.29 just fits;
    # wide age-group CIs overflow to arrows)
    XMIN, XMAX = -0.30, 0.20

    # Build display rows: bold group header, then indented modalities
    items: list[dict] = []
    prev = None
    for _, row in df.iterrows():
        g = str(row["group"])
        if g != prev:
            items.append({"kind": "group", "label": g})
            prev = g
        items.append(
            {
                "kind": "effect",
                "label": str(row["modality"]),
                "is_ref": bool(row["is_ref"]),
                "d": float(row["d"]),
                "d_lo": float(row["d_lo"]),
                "d_hi": float(row["d_hi"]),
            }
        )

    n_items = len(items)
    # Wide enough to read, with enough vertical space so rows aren't squished
    fig_h = max(6.8, 0.95 + n_items * 0.230)
    fig = plt.figure(figsize=(11.8, fig_h))

    # Variable | standardized estimate | forest (far right); no horizontal gap between panels
    gs = fig.add_gridspec(
        1,
        3,
        width_ratios=[3.0, 2.3, 3.6],
        left=0.02,
        right=0.99,
        top=0.98,
        bottom=max(0.07, 1.05 / fig_h),
        wspace=0.0,
    )
    ax_v = fig.add_subplot(gs[0, 0])
    ax_n = fig.add_subplot(gs[0, 1], sharey=ax_v)
    ax_f = fig.add_subplot(gs[0, 2], sharey=ax_v)

    y = np.arange(n_items)[::-1]
    y_top = n_items - 0.5 + 0.85
    y_lim = (-0.5, y_top)
    for ax in (ax_v, ax_n, ax_f):
        ax.set_ylim(*y_lim)

    for ax in (ax_v, ax_n, ax_f):
        ax.patch.set_visible(False)
    for ax in (ax_v, ax_n):
        ax.set_xlim(0, 1)
        ax.axis("off")

    group_line_ys: list[float] = []
    row_line_ys: list[float] = []
    for i, item in enumerate(items):
        if item["kind"] == "group":
            group_line_ys.append(y[i] + 0.5)
        if i < n_items - 1 and items[i + 1]["kind"] != "group":
            # Soft separators between levels (skip domain boundaries)
            row_line_ys.append(y[i] - 0.5)

    header_y = n_items - 0.5 + 0.42
    header_rule_y = header_y - 0.35

    label_fs = 11.5
    group_fs = 12.0
    for i, item in enumerate(items):
        yi = y[i]
        if item["kind"] == "group":
            ax_v.text(
                0.0,
                yi,
                item["label"],
                ha="left",
                va="center",
                fontsize=group_fs,
                fontweight="bold",
                color="#1A1A1A",
                clip_on=False,
            )
            continue

        ax_v.text(
            0.06,
            yi,
            item["label"],
            ha="left",
            va="center",
            fontsize=label_fs,
            color="#1A1A1A",
            clip_on=False,
        )
        ax_n.text(
            0.0,
            yi,
            _fmt_d(item["d"], item["d_lo"], item["d_hi"], item["is_ref"]),
            ha="left",
            va="center",
            fontsize=label_fs,
            color="#1A1A1A",
            clip_on=False,
        )

        if item["is_ref"]:
            ax_f.plot(0, yi, "o", color="#666666", markersize=6.0, zorder=3, clip_on=False)
            continue

        lo, hi, d = item["d_lo"], item["d_hi"], item["d"]
        # Compare at axis label precision so values sitting on the bound
        # are not treated as beyond it
        left_overflow = round(lo, 2) < round(XMIN, 2)
        right_overflow = round(hi, 2) > round(XMAX, 2)

        # Overflow: filled triangle tip at the bound; CI stops at the triangle base
        head_dx = 0.018
        head_dy = 0.17
        lo_c = max(lo, XMIN)
        hi_c = min(hi, XMAX)
        if left_overflow:
            tip, base = XMIN, XMIN + head_dx
            ax_f.add_patch(
                Polygon(
                    [(tip, yi), (base, yi + head_dy), (base, yi - head_dy)],
                    closed=True,
                    facecolor=NAVY,
                    edgecolor="none",
                    zorder=5,
                    clip_on=False,
                )
            )
            lo_c = max(lo_c, base)
        if right_overflow:
            tip, base = XMAX, XMAX - head_dx
            ax_f.add_patch(
                Polygon(
                    [(tip, yi), (base, yi + head_dy), (base, yi - head_dy)],
                    closed=True,
                    facecolor=NAVY,
                    edgecolor="none",
                    zorder=5,
                    clip_on=False,
                )
            )
            hi_c = min(hi_c, base)
        if lo_c < hi_c:
            ax_f.plot(
                [lo_c, hi_c],
                [yi, yi],
                color=NAVY,
                linewidth=1.5,
                solid_capstyle="butt",
                zorder=2,
                clip_on=True,
            )
        if XMIN <= d <= XMAX:
            ax_f.plot(d, yi, "o", color=NAVY, markersize=5.2, zorder=3, clip_on=False)

    ax_f.set_xlim(XMIN, XMAX)
    ax_f.axvline(
        0, color="#E31A1C", linewidth=1.25, linestyle=(0, (0.8, 1.2)), zorder=1
    )
    ax_f.set_xlabel("")
    # Reading aids: which side of zero means more vs. less support.
    # Offsets are in points so they hold at any figure height.
    for x_at, cue in (
        ((XMIN + 0.0) / 2, "\u2190 Associated with lower support"),
        ((0.0 + XMAX) / 2, "Associated with higher support \u2192"),
    ):
        ax_f.annotate(
            cue,
            xy=(x_at, 0),
            xycoords=ax_f.get_xaxis_transform(),
            xytext=(0, -26),
            textcoords="offset points",
            ha="center",
            va="top",
            fontsize=9,
            color="#3D3D3D",
            annotation_clip=False,
        )
    # Center the axis title on zero (not the geometric midpoint of the range)
    ax_f.annotate(
        "Standardized effect",
        xy=(0.0, 0),
        xycoords=ax_f.get_xaxis_transform(),
        xytext=(0, -46),
        textcoords="offset points",
        ha="center",
        va="top",
        fontsize=12.5,
        annotation_clip=False,
    )
    ax_f.set_xticks([-0.3, -0.2, -0.1, 0.0, 0.1, 0.2])
    ax_f.tick_params(axis="x", labelsize=11)
    ax_f.tick_params(axis="y", left=False, labelleft=False)
    ax_f.spines["top"].set_visible(False)
    ax_f.spines["right"].set_visible(False)
    ax_f.spines["left"].set_visible(False)

    # Column headers (no "Standardized effect" at top — that is the x-axis label)
    ax_v.text(0.0, header_y, "Variables", fontsize=12.5, fontweight="bold", va="center")
    ax_n.text(
        0.0,
        header_y,
        "Standardized effect (95% CI)",
        fontsize=12.5,
        fontweight="bold",
        va="center",
    )

    # Continuous rules across columns: soft row lines, stronger domain lines
    fig.canvas.draw()
    x0 = ax_v.get_position().x0
    x1 = ax_f.get_position().x1
    trans = mtransforms.blended_transform_factory(fig.transFigure, ax_v.transData)
    hlines = (
        [(header_rule_y, "#333333", 1.0)]
        + [(yy, "#E6E6E6", 0.55) for yy in row_line_ys]
        + [(yy, "#B0B0B0", 0.85) for yy in group_line_ys]
    )
    for ly, color, lw in hlines:
        fig.add_artist(
            Line2D(
                [x0, x1],
                [ly, ly],
                transform=trans,
                color=color,
                linewidth=lw,
                solid_capstyle="butt",
                clip_on=False,
                zorder=0,
            )
        )

    for ext in ("png", "pdf"):
        fig.savefig(FIGS / f"{outstem}.{ext}", dpi=300)
    save_tiff(fig, FIGS / f"{outstem}.tif")
    plt.close(fig)
    print(f"wrote {outstem}.png / .pdf / .tif")
    archive_other_figures()


def main_interaction_figures() -> None:
    adj = pd.read_csv(DATA / "plotdata_adjusted.csv")

    # Primary Figure 1: full 4-panel (first submission)
    draw(
        adj,
        "fig_predictors_x_snap",
        panels=PANELS_ALL,
        nrows=2,
        ncols=2,
        figsize=(10, 8.5),
        pvals=INTERACTION_P,
    )
    # 2-panel fallback, kept current in case AJPH enforces its panel limit
    draw(
        adj,
        "fig_predictors_x_snap_AJPH",
        panels=PANELS_AJPH,
        nrows=1,
        ncols=2,
        figsize=(10, 5.0),
        pvals=INTERACTION_P,
    )
    global SHOW_SLOPE_P
    SHOW_SLOPE_P = True
    draw(
        adj,
        "fig_predictors_x_snap_slopeP",
        panels=PANELS_ALL,
        nrows=2,
        ncols=2,
        figsize=(10, 8.5),
        pvals=INTERACTION_P,
    )
    SHOW_SLOPE_P = False
    archive_other_figures()


def main() -> None:
    args = [a.lower() for a in sys.argv[3:]]
    if args and args[0] in {"forest", "--forest", "--forest-only"}:
        draw_standardized_effects_forest()
        return
    main_interaction_figures()
    # Refresh forest if CSV already exists (e.g., full pipeline after tables once)
    forest_csv = DATA / "plotdata_standardized_effects.csv"
    if forest_csv.exists():
        draw_standardized_effects_forest()


if __name__ == "__main__":
    main()