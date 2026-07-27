"""
business_value.py
=================
Value-based selection of a churn-intervention decision threshold.

Instead of picking a threshold from a metric (e.g. "precision >= 0.50,
then maximise recall"), this module selects it from the CHF at stake. Each
confusion-matrix cell carries a real cost:

    True positive  (TP): churner correctly flagged -> retention offer sent, chance to save
    False positive (FP): loyal subscriber flagged   -> offer wasted
    False negative (FN): churner missed             -> subscriber value lost (baseline)
    True negative  (TN): nothing to do              -> zero cost

Net value of a campaign at threshold t, versus doing nothing:

    NetValue(t) = sum_{i in TP} p_save * V_sub_i  -  (|TP| + |FP|) * C_offer

Sweep t, take the argmax. The optimum sits neither at the left edge nor the right
edge of the grid: it lands where one more wasted offer starts to cost more than one
more saved subscriber returns.

REQUIREMENT: CALIBRATED probabilities. A p(churn)=0.30 must genuinely mean "30% of
these subscribers leave", otherwise the whole monetary argument is void. This is why a
CalibratedClassifierCV sits upstream.


===============================================================================
ASSUMPTIONS & JUSTIFICATION
===============================================================================
Of the four business inputs, ONE is estimated from the data (the horizon), and three
must be assumed. The discipline: estimate what can be estimated, anchor each assumed
input on a sourced 2026 TELECOM benchmark, express the recommendation as a RANGE over
the assumed inputs, and show every choice in the code and report.

Monthly service revenue (`MonthlyCharges`) is read directly from the data. Value:

    V_sub = MonthlyCharges * margin * horizon

-------------------------------------------------------------------------------
1. Contribution margin  (default central = 0.60)  [ASSUMED]
-------------------------------------------------------------------------------
A churned subscriber costs the operator the MARGIN on their revenue, not the full
revenue. The right figure is the GROSS / CONTRIBUTION margin on service revenue, NOT
EBITDA: once the network is built, the marginal cost of serving one more subscriber is
very low, so losing one forgoes a high-margin stream while fixed network cost is
unchanged. 2026 wireless-service gross-margin benchmarks cluster at 55-70% (Verizon
~57%, AT&T ~59%, T-Mobile ~56%; Damodaran / SEC-filing trackers); private operators
run 5-15pp below listed carriers. Centre 0.60, bracket 0.55-0.70.

-------------------------------------------------------------------------------
2. Retained-lifetime horizon  [ESTIMATED FROM DATA]
-------------------------------------------------------------------------------
Value at risk is a stream: monthly margin times the months a subscriber would stay if
retained:

  (a) The dataset is CROSS-SECTIONAL (a churn label + tenure), not a monthly event
      series. There is no monthly churn rate to read off.
  (b) 1/rate assumes a CONSTANT hazard. The data contradicts this:
      SHAP shows churn is heavily front-loaded (very high in the first months, then
      collapses and stabilises). A single 1/rate lifetime is wrong for BOTH
      populations at once: too short for tenured survivors, too long for new at-risk
      subscribers.

Instead the horizon is the RESTRICTED MEAN SURVIVAL TIME (RMST): a Kaplan-Meier
estimate on `tenure` (churn = event, active subscribers = right-censored), integrated
up to a cap. RMST is the survival-weighted count of future months, so V_sub becomes
correct rather than approximate. See `expected_lifetime_from_tenure`.

Which survival curve: a flagged subscriber is disproportionately low-tenure / high-
hazard. The point of retention is to push them past the hazard hump into the tenured,
low-churn pool. The value saved by a successful offer is therefore the life of a
subscriber who now behaves like the general base for which the base-rate RMST is
the correct proxy, not the unconditional remaining life of an about-to-churn
subscriber.

-------------------------------------------------------------------------------
3. Offer cost, C_offer  (default range 25-60 CHF)  [ASSUMED]
-------------------------------------------------------------------------------
The cost of one targeted retention action: a bill credit, a plan discount over a
contract period, a device/loyalty credit, or a retention-desk contact. This is the
softest input, telecom offers vary widely and are not cleanly benchmarked per
subscriber in public data, so it is swept across a plausible band, not fixed.

-------------------------------------------------------------------------------
4. Offer success rate, p_save  (default range 0.20-0.35)  [ASSUMED] 
-------------------------------------------------------------------------------
Probability of retaining a subscriber who would have left, conditional on targeting
them PROACTIVELY. Beware a seductive wrong anchor: telecom "save-desk" success rates
of 40-50%. Those describe inbound callers who already phoned to cancel, a self-
selected, high-intent population, not the proactively flagged base this model targets.
Using inbound save rates for outbound targeting inflates the benefit of flagging. 
The defensible anchor is a CAUSAL effect: actively acting on churn cuts attrition 
by ~26% over 12 months (Totango-type 2026 benchmarks), landing p_save near 0.20-0.35
for proactive targeting.

===============================================================================
"""

from dataclasses import dataclass
from typing import Sequence

import numpy as np
import pandas as pd


# ---------------------------------------------------------------------------
# 1. Subscriber value
# ---------------------------------------------------------------------------

def compute_customer_value(
    monthly_charges: pd.Series,
    margin: float,
    horizon_months: float,
) -> pd.Series:
    """Value (LTV) at risk per subscriber = monthly margin x retained horizon.

    monthly_charges : per-subscriber monthly revenue (a dataset column).
    margin          : contribution margin as a fraction (0.60 = 60%) (ASSUMED)
    horizon_months  : retained-lifetime horizon. Prefer the data-derived RMST from
                      `expected_lifetime_from_tenure` over any hand-set value.

    Per-subscriber (via monthly_charges): a subscriber at 20 CHF/month and one at
    110 CHF/month do not carry the same value, hence not the same optimal threshold.
    """
    return monthly_charges.astype(float) * margin * horizon_months


def expected_lifetime_from_tenure(
    tenure: pd.Series,
    churned: pd.Series,
    cap_months: int = 72,
) -> float:
    """Data-derived retained-lifetime horizon = restricted mean survival time (RMST).

    Kaplan-Meier estimate on subscriber tenure (churn = event, active = right-
    censored). RMST up to `cap_months` = area under the survival curve = survival-
    weighted count of future months. Dependency-free.

    Respects the non-constant (front-loaded) hazard, unlike 1/monthly_churn_rate.

    tenure     : months each subscriber has been active (dataset column).
    churned    : 1 if churned, 0 if still active (censored).
    cap_months : horizon cap (~ dataset max tenure).
    """
    tenure = np.asarray(tenure, dtype=float)
    churned = np.asarray(churned, dtype=int)

    event_times = np.unique(tenure[churned == 1])
    event_times = event_times[(event_times > 0) & (event_times <= cap_months)]

    survival = 1.0
    prev_t = 0.0
    rmst = 0.0
    for t in event_times:
        n_at_risk = np.sum(tenure >= t)
        d = np.sum((tenure == t) & (churned == 1))
        if n_at_risk == 0:
            break
        rmst += survival * (t - prev_t)        # flat segment [prev_t, t) at current level
        survival *= (1.0 - d / n_at_risk)      # KM step
        prev_t = t

    rmst += survival * (cap_months - prev_t)   # tail to the cap
    return float(rmst)


# ---------------------------------------------------------------------------
# 2. Net value of a campaign at a given threshold
# ---------------------------------------------------------------------------

def net_value_at_threshold(
    proba: np.ndarray,
    y_true: np.ndarray,
    v_sub: np.ndarray,
    threshold: float,
    c_offer: float,
    p_save: float,
) -> float:
    """Net value (CHF) of a campaign at `threshold`, vs doing nothing."""
    proba = np.asarray(proba)
    y_true = np.asarray(y_true)
    v_sub = np.asarray(v_sub, dtype=float)

    flagged = proba >= threshold
    tp = flagged & (y_true == 1)          # churners correctly targeted
    fp = flagged & (y_true == 0)          # loyal subscribers wasted

    benefit = p_save * v_sub[tp].sum()             # value saved (per-subscriber)
    cost = c_offer * (tp.sum() + fp.sum())         # every offer sent costs
    return float(benefit - cost)


def sweep_thresholds(
    proba: np.ndarray,
    y_true: np.ndarray,
    v_sub: np.ndarray,
    c_offer: float,
    p_save: float,
    grid: Sequence[float] | None = None,
) -> pd.DataFrame:
    """Sweep the threshold; return [threshold, net_value, n_targeted, tp, fp]."""
    if grid is None:
        grid = np.arange(0.01, 1.00, 0.01)

    proba = np.asarray(proba)
    y_true = np.asarray(y_true)
    v_sub = np.asarray(v_sub, dtype=float)

    rows = []
    for t in grid:
        flagged = proba >= t
        tp = int((flagged & (y_true == 1)).sum())
        fp = int((flagged & (y_true == 0)).sum())
        benefit = p_save * v_sub[flagged & (y_true == 1)].sum()
        cost = c_offer * (tp + fp)
        rows.append(
            {
                "threshold": float(t),
                "net_value": float(benefit - cost),
                "n_targeted": tp + fp,
                "tp": tp,
                "fp": fp,
            }
        )
    return pd.DataFrame(rows)


def optimal_threshold(
    proba: np.ndarray,
    y_true: np.ndarray,
    v_sub: np.ndarray,
    c_offer: float,
    p_save: float,
    grid: Sequence[float] | None = None,
) -> tuple[float, float]:
    """Return (optimal threshold, net value at that threshold)."""
    df = sweep_thresholds(proba, y_true, v_sub, c_offer, p_save, grid)
    best = df.loc[df["net_value"].idxmax()]
    return float(best["threshold"]), float(best["net_value"])


def closed_form_threshold(c_offer: float, p_save: float, v_sub_mean: float) -> float:
    """Analytic threshold for a mean subscriber value (a sanity check).

    Sending an offer pays off while p(churn) * p_save * V_sub > C_offer, hence
    threshold* = C_offer / (p_save * V_sub). Shows the threshold is a ratio of
    business quantities, not a statistical artefact. A large gap vs the swept optimum
    is diagnostic (imperfect calibration or high value dispersion).
    """
    denom = p_save * v_sub_mean
    if denom <= 0:
        raise ValueError("p_save and v_sub_mean must be > 0")
    return min(1.0, c_offer / denom)


# ---------------------------------------------------------------------------
# 3. Scenarios & sensitivity
# ---------------------------------------------------------------------------

@dataclass
class Scenario:
    """One set of business assumptions.

    `horizon_months` is normally the data-derived RMST, shared across scenarios
    (an estimated quantity). Build with
    `build_telecom_scenarios(...)` to stamp the RMST automatically.
    """

    name: str
    c_offer: float           # cost of one targeted offer (CHF)      [ASSUMED]
    p_save: float            # offer efficacy on a true churner       [ASSUMED]
    margin: float            # contribution margin (fraction)         [ASSUMED]
    horizon_months: float    # retained lifetime (months)             [ESTIMATED: RMST]


# Only the three ASSUMED inputs vary across scenarios. The horizon is estimated
# from the data and shared (see build_telecom_scenarios).
#   margin  : 0.55 (private/low) -> 0.60 (listed-carrier pack) -> 0.70 (best gross)
#   c_offer : marginal targeted-offer cost (bill credit / subsidy), 25-60 CHF
#   p_save  : proactive causal effect (0.20-0.35), NOT inbound save-desk (40-50%)
_ASSUMPTION_BANDS = [
    ("Conservative", 60, 0.20, 0.55),
    ("Central",      40, 0.27, 0.60),
    ("Optimistic",   25, 0.35, 0.70),
]


def build_telecom_scenarios(
    tenure: pd.Series,
    churned: pd.Series,
    cap_months: int = 72,
) -> list[Scenario]:
    """Build the 3 scenarios with a data-derived horizon (RMST) shared across all.

    Pass the test-set `tenure` and churn label. Margin/offer/save-rate vary per the
    benchmark bands. The horizon is estimated once and held fixed.
    """
    horizon = expected_lifetime_from_tenure(tenure, churned, cap_months)
    return [
        Scenario(name, c_offer=c, p_save=p, margin=m, horizon_months=horizon)
        for (name, c, p, m) in _ASSUMPTION_BANDS
    ]


# Fallback fixed-horizon scenarios (used only when tenure is unavailable).
DEFAULT_SCENARIOS = [
    Scenario(name, c_offer=c, p_save=p, margin=m, horizon_months=36)
    for (name, c, p, m) in _ASSUMPTION_BANDS
]


def sensitivity_analysis(
    proba: np.ndarray,
    y_true: np.ndarray,
    monthly_charges: pd.Series,
    scenarios: Sequence[Scenario],
    grid: Sequence[float] | None = None,
) -> pd.DataFrame:

    proba = np.asarray(proba)
    y_true = np.asarray(y_true)

    rows = []
    for s in scenarios:
        v_sub = compute_customer_value(
            monthly_charges, margin=s.margin, horizon_months=s.horizon_months
        ).to_numpy()
        t_star, net = optimal_threshold(proba, y_true, v_sub, s.c_offer, s.p_save, grid)
        cf = closed_form_threshold(s.c_offer, s.p_save, float(np.mean(v_sub)))
        flagged = proba >= t_star
        rows.append(
            {
                "scenario": s.name,
                "c_offer": s.c_offer,
                "p_save": s.p_save,
                "margin": s.margin,
                "horizon_m": round(s.horizon_months, 1),
                "v_sub_mean": round(float(np.mean(v_sub)), 0),
                "optimal_threshold": round(t_star, 3),
                "formula_threshold": round(cf, 3),
                "n_targeted": int(flagged.sum()),
                "net_value_CHF": round(net, 0),
            }
        )
    return pd.DataFrame(rows)


def horizon_sensitivity(
    proba: np.ndarray,
    y_true: np.ndarray,
    monthly_charges: pd.Series,
    base_scenario: Scenario,
    factors: Sequence[float] = (0.6, 0.8, 1.0, 1.2, 1.4),
    grid: Sequence[float] | None = None,
) -> pd.DataFrame:
    """One-way sensitivity on the horizon alone, holding the assumed inputs fixed.

    Confirms the horizon estimate does not, by itself, carry the recommendation:
    scales the RMST by each factor (covers discounting / cap uncertainty) and reports
    how the optimal threshold moves. If the threshold is stable across factors, the
    recommendation is robust to the horizon choice.
    """
    proba = np.asarray(proba)
    y_true = np.asarray(y_true)

    rows = []
    for f in factors:
        h = base_scenario.horizon_months * f
        v_sub = compute_customer_value(monthly_charges, base_scenario.margin, h).to_numpy()
        t_star, net = optimal_threshold(
            proba, y_true, v_sub, base_scenario.c_offer, base_scenario.p_save, grid
        )
        rows.append(
            {
                "horizon_factor": f,
                "horizon_m": round(h, 1),
                "optimal_threshold": round(t_star, 3),
                "net_value_CHF": round(net, 0),
            }
        )
    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# 4. Figure: the profit curve
# ---------------------------------------------------------------------------

def plot_profit_curve(
    proba: np.ndarray,
    y_true: np.ndarray,
    monthly_charges: pd.Series,
    scenario: Scenario,
    grid: Sequence[float] | None = None,
    ax=None,
):
    """Plot net value (CHF) vs threshold for one scenario, marking the optimum.

    Replaces the precision/recall curve: it speaks in CHF.
    """
    import matplotlib.pyplot as plt

    v_sub = compute_customer_value(
        monthly_charges, margin=scenario.margin, horizon_months=scenario.horizon_months
    ).to_numpy()
    df = sweep_thresholds(proba, y_true, v_sub, scenario.c_offer, scenario.p_save, grid)
    t_star = float(df.loc[df["net_value"].idxmax(), "threshold"])
    net_star = float(df["net_value"].max())

    if ax is None:
        _, ax = plt.subplots(figsize=(9, 5.5))

    ax.plot(df["threshold"], df["net_value"], linewidth=2, label="Campaign net value")
    ax.axhline(0, color="grey", linestyle="--", linewidth=1)
    ax.axvline(t_star, color="crimson", linestyle=":", linewidth=1.5)
    ax.scatter([t_star], [net_star], color="crimson", zorder=5,
               label=f"Optimum: threshold={t_star:.2f}  ({net_star:,.0f} CHF)")
    ax.set_xlabel("Decision threshold (churn probability)")
    ax.set_ylabel("Net value vs doing nothing (CHF)")
    ax.set_title(f"Profit curve — {scenario.name} scenario")
    ax.legend()
    ax.grid(True, alpha=0.3)
    return ax


# ---------------------------------------------------------------------------
# 5. Public entry point: pick the operating threshold from CHF
# ---------------------------------------------------------------------------
 
def select_operating_threshold(
    proba_cal: np.ndarray,
    y_true: np.ndarray,
    monthly_charges: pd.Series,
    tenure: pd.Series,
    churned: pd.Series | None = None,
    band: str = "Central",
    cap_months: int = 72,
    grid: Sequence[float] | None = None,
) -> float:
    """Return the operating threshold selected by argmax of net CHF.
 
    Replaces the statistical-metric block currently in train.py:
 
        candidates = threshold_df[threshold_df["precision"] >= 0.50]
        best_row = candidates.loc[candidates["recall"].idxmax()]
        threshold = best_row["threshold"]
 
    with a business-value selection: the horizon is estimated from subscriber
    tenure (RMST), and margin / offer cost / save-rate come from the chosen
    benchmark band.
 
    Parameters
    ----------
    proba_cal       : calibrated churn probabilities on the test set.
    y_true          : churn labels (0/1) on the test set.
    monthly_charges : test-set MonthlyCharges, aligned on y_true's index.
    tenure          : test-set tenure in months, aligned on y_true's index.
    churned         : test-set churn label for the RMST fit. Defaults to y_true.
    band            : "Conservative" | "Central" | "Optimistic".
    cap_months      : RMST horizon cap (~ dataset max tenure).
    grid            : threshold grid, defaults to np.arange(0.01, 1.00, 0.01).
"""
    if churned is None:
        churned = y_true
    scenarios = {s.name: s for s in build_telecom_scenarios(tenure, churned, cap_months)}
    s = scenarios[band]
    v_sub = compute_customer_value(monthly_charges, s.margin, s.horizon_months).to_numpy()
    t_star, _ = optimal_threshold(proba_cal, y_true, v_sub, s.c_offer, s.p_save, grid)
    return t_star
 