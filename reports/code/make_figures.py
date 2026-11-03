import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt


# Paramètres de sortie

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA_PATH = os.path.join(BASE_DIR, "data", "WA_Fn-UseC_-Telco-Customer-Churn.csv")
FIG_DIR = os.path.join(BASE_DIR, "reports", "figures")
os.makedirs(FIG_DIR, exist_ok=True)


# Style global

plt.rcParams.update({
    "font.family": "DejaVu Sans",
    "font.size": 11,
    "axes.titlesize": 12,
    "axes.labelsize": 11,
    "axes.spines.top": False,
    "axes.spines.right": False,
    "axes.grid": True,
    "grid.alpha": 0.3,
    "grid.linestyle": "--",
    "grid.linewidth": 0.5,
    "figure.dpi": 100,
    "savefig.dpi": 150,
    "savefig.bbox": "tight",
})

C_PRIMARY = "#2b5f84"
C_LIGHT   = "#d0d8de"


# Labels par langue

LABELS = {
    "fr": {
        "fig1_title":     "Taux de résiliation par tranche d'ancienneté",
        "fig1_ylabel":    "Taux de résiliation (%)",
        "fig1_bins":      ["0-3 mois", "4-12 mois", "13-24 mois",
                           "25-48 mois", "49-72 mois"],
        "fig2_title":     "Fonction de survie par ancienneté (Kaplan-Meier)",
        "fig2_xlabel":    "Ancienneté (mois)",
        "fig2_ylabel":    "Probabilité de survie",
        "fig2_annot":     "Aire = durée moyenne\nrestreinte = {rmst:.1f} mois",
        "fig1_suffix":    "",
        "fig2_suffix":    "",
    },
    "en": {
        "fig1_title":     "Churn rate by tenure bracket",
        "fig1_ylabel":    "Churn rate (%)",
        "fig1_bins":      ["0-3 months", "4-12 months", "13-24 months",
                           "25-48 months", "49-72 months"],
        "fig2_title":     "Survival function by tenure (Kaplan-Meier)",
        "fig2_xlabel":    "Tenure (months)",
        "fig2_ylabel":    "Survival probability",
        "fig2_annot":     "Area = restricted mean\nsurvival time = {rmst:.1f} months",
        "fig1_suffix":    "_en",
        "fig2_suffix":    "_en",
    },
}


# Chargement des données

data = pd.read_csv(DATA_PATH)
data["Churn_num"] = data["Churn"].map({"Yes": 1, "No": 0})



# FIGURE 1 — Taux de résiliation par tranche d'ancienneté

def make_fig1(labels):
    bins = [0, 3, 12, 24, 48, 73]
    data["TenureBin"] = pd.cut(data["tenure"], bins=bins,
                               labels=labels["fig1_bins"],
                               right=True, include_lowest=True)
    churn_by_bin = data.groupby("TenureBin", observed=True)["Churn_num"].mean() * 100

    fig, ax = plt.subplots(figsize=(8, 4.5))
    bars = ax.bar(range(len(churn_by_bin)), churn_by_bin.values,
                  color=C_LIGHT, edgecolor=C_PRIMARY, linewidth=1.2, width=0.65)

    bars[0].set_color(C_PRIMARY)
    bars[0].set_edgecolor(C_PRIMARY)

    ax.set_xticks(range(len(churn_by_bin)))
    ax.set_xticklabels(churn_by_bin.index)
    ax.set_ylabel(labels["fig1_ylabel"])
    ax.set_ylim(0, max(churn_by_bin.values) * 1.18)

    for i, v in enumerate(churn_by_bin.values):
        ax.text(i, v + 1.2, f"{v:.0f}%", ha="center", va="bottom",
                fontsize=10, color=C_PRIMARY if i == 0 else "#333")

    ax.set_title(labels["fig1_title"], loc="left", pad=12, fontweight="bold")
    ax.spines["left"].set_color("#333")
    ax.spines["bottom"].set_color("#333")

    out_path = os.path.join(FIG_DIR,
                            f"fig1_churn_by_tenure{labels['fig1_suffix']}.png")
    plt.savefig(out_path)
    plt.close()
    return out_path



# FIGURE 2 — Fonction de survie Kaplan-Meier

def make_fig2(labels):
    tenure_arr = data["tenure"].values.astype(float)
    churned_arr = data["Churn_num"].values.astype(int)

    event_times = np.unique(tenure_arr[churned_arr == 1])
    event_times = event_times[(event_times > 0) & (event_times <= 72)]

    t_curve = [0.0]
    s_curve = [1.0]
    survival = 1.0
    prev_t = 0.0
    rmst = 0.0
    for t in event_times:
        n_at_risk = np.sum(tenure_arr >= t)
        d = np.sum((tenure_arr == t) & (churned_arr == 1))
        if n_at_risk == 0:
            break
        t_curve.append(t); s_curve.append(survival)
        rmst += survival * (t - prev_t)
        survival *= (1.0 - d / n_at_risk)
        prev_t = t
        t_curve.append(t); s_curve.append(survival)
    t_curve.append(72); s_curve.append(survival)
    rmst += survival * (72 - prev_t)

    fig, ax = plt.subplots(figsize=(8.5, 4.8))
    ax.plot(t_curve, s_curve, color=C_PRIMARY, linewidth=2, zorder=3)
    ax.fill_between(t_curve, 0, s_curve, color=C_PRIMARY, alpha=0.10, zorder=2)

    ax.text(36, 0.45, labels["fig2_annot"].format(rmst=rmst),
            ha="center", va="center", fontsize=11, color=C_PRIMARY, fontweight="bold",
            bbox=dict(facecolor="white", edgecolor=C_PRIMARY, alpha=0.9,
                      pad=6, linewidth=0.8))

    ax.set_xlabel(labels["fig2_xlabel"])
    ax.set_ylabel(labels["fig2_ylabel"])
    ax.set_xlim(0, 72)
    ax.set_ylim(0, 1.02)
    ax.set_title(labels["fig2_title"], loc="left", pad=12, fontweight="bold")
    ax.spines["left"].set_color("#333")
    ax.spines["bottom"].set_color("#333")

    out_path = os.path.join(FIG_DIR,
                            f"fig2_survival_km{labels['fig2_suffix']}.png")
    plt.savefig(out_path)
    plt.close()
    return out_path, rmst




for lang_code, labels in LABELS.items():
    p1 = make_fig1(labels)
    p2, rmst = make_fig2(labels)
    print(f"[{lang_code}] {os.path.basename(p1)}")
    print(f"[{lang_code}] {os.path.basename(p2)}")

print(f"\nRMST (données complètes) = {rmst:.2f} mois")
print(f"Figures écrites dans {FIG_DIR}")