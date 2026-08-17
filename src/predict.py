"""
predict.py
==========
Batch inference on new subscribers using the trained churn model.

Consumes three artefacts written by train.py to disk:
  - models/model.pkl       : the calibrated XGBoost classifier
  - models/columns.pkl     : the feature schema seen at training
  - models/threshold.pkl   : dict {threshold, band, assumptions}

Takes a raw CSV with the same columns as the Telco training data minus the
Churn label, returns the same CSV with two columns appended:
  - churn_probability : calibrated p(churn) in [0, 1]
  - flag_for_retention: 1 if probability >= threshold, else 0

Fails loudly if the input is missing any required column. A silently wrong
prediction is worse than an explicit stop.

Usage
-----
CLI:
    python -m src.predict --input data/new_subscribers.csv --output preds.csv

Importable:
    from src.predict import predict_batch
    df_out = predict_batch(df_in)
"""

import argparse
import os
import sys

import joblib
import pandas as pd

from src.preprocessing import preprocess_features


BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS_DIR = os.path.join(BASE_DIR, "models")

DEFAULT_MODEL_PATH = os.path.join(MODELS_DIR, "model.pkl")
DEFAULT_COLUMNS_PATH = os.path.join(MODELS_DIR, "columns.pkl")
DEFAULT_THRESHOLD_PATH = os.path.join(MODELS_DIR, "threshold.pkl")


# ---------------------------------------------------------------------------
# 1. Loading artefacts
# ---------------------------------------------------------------------------

def load_artefacts(
    model_path: str = DEFAULT_MODEL_PATH,
    columns_path: str = DEFAULT_COLUMNS_PATH,
    threshold_path: str = DEFAULT_THRESHOLD_PATH,
) -> tuple:
    """Load the three artefacts produced by train.py.

    Returns (model, expected_columns, threshold_artifact) where
    threshold_artifact is the dict {threshold, band, assumptions}.
    """
    for path, name in [
        (model_path, "model"),
        (columns_path, "columns"),
        (threshold_path, "threshold"),
    ]:
        if not os.path.exists(path):
            raise FileNotFoundError(
                f"Missing {name} artefact at {path}. "
                f"Run `python -m src.train` first to generate it."
            )

    model = joblib.load(model_path)
    expected_columns = joblib.load(columns_path)
    threshold_artifact = joblib.load(threshold_path)

    # Guard against an old-style threshold artefact (bare float) so we fail
    # with a clear message rather than silently mis-indexing.
    if not isinstance(threshold_artifact, dict) or "bands" not in threshold_artifact:
        raise ValueError(
        f"Threshold artefact at {threshold_path} is not the expected dict "
        f"{{default_band, bands}}. Re-run train.py to regenerate."
    )

    return model, expected_columns, threshold_artifact


# ---------------------------------------------------------------------------
# 2. Column validation -- fail loudly on missing raw columns
# ---------------------------------------------------------------------------

# Raw columns required to reproduce the training-time preprocessing.
# Derived from the Telco schema minus the Churn label.
REQUIRED_RAW_COLUMNS = [
    "gender", "SeniorCitizen", "Partner", "Dependents",
    "tenure", "PhoneService", "MultipleLines", "InternetService",
    "OnlineSecurity", "OnlineBackup", "DeviceProtection", "TechSupport",
    "StreamingTV", "StreamingMovies", "Contract", "PaperlessBilling",
    "PaymentMethod", "MonthlyCharges", "TotalCharges",
]


def _validate_raw_columns(df: pd.DataFrame) -> None:
    """Raise ValueError with the list of missing columns, if any.

    Uses set logic so the message is deterministic regardless of column order.
    """
    missing = [c for c in REQUIRED_RAW_COLUMNS if c not in df.columns]
    if missing:
        raise ValueError(
            f"Input is missing {len(missing)} required column(s): {missing}. "
            f"Expected raw Telco schema (minus 'Churn'). Aborting to avoid "
            f"silently wrong predictions."
        )


# ---------------------------------------------------------------------------
# 3. The core function -- importable from a notebook or another script
# ---------------------------------------------------------------------------

def predict_batch(
    df: pd.DataFrame,
    model=None,
    expected_columns=None,
    threshold: float | None = None,
    band: str = "Central",
) -> pd.DataFrame:
    """Score a batch of raw subscribers and return the enriched DataFrame.

    Loads the three artefacts on first call if not supplied. Passing them in
    lets callers avoid disk reads when scoring many batches in a loop.

    Parameters
    ----------
    df : raw Telco-format DataFrame, without the 'Churn' column.
    model, expected_columns, threshold_artifact : optional pre-loaded artefacts.

    Returns
    -------
    DataFrame : df + two columns:
        - churn_probability  : calibrated p(churn) in [0, 1]
        - flag_for_retention : 1 if p >= threshold, else 0
    """
    if model is None or expected_columns is None or threshold is None:
        model_loaded, expected_columns_loaded, threshold_artifact = load_artefacts()
        if model is None:
            model = model_loaded
        if expected_columns is None:
            expected_columns = expected_columns_loaded
        if threshold is None:
            threshold = threshold_artifact["bands"][band]["threshold"]

    # Fail loudly if raw schema is incomplete.
    _validate_raw_columns(df)

    # Preprocess exactly as at training time (same one-hot rules, same column
    # order). columns.pkl guarantees categories unseen in this batch still map
    # to zero rather than get dropped, and unseen categories are ignored.
    X = preprocess_features(df, expected_columns=expected_columns)

    proba = model.predict_proba(X)[:, 1]
    flag = (proba >= threshold).astype(int)

    out = df.copy()
    out["churn_probability"] = proba
    out["flag_for_retention"] = flag
    return out


# ---------------------------------------------------------------------------
# 4. CLI entry point
# ---------------------------------------------------------------------------

def _parse_args(argv=None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Batch churn scoring on a raw Telco-format CSV.",
    )
    parser.add_argument(
        "--input", "-i", required=True,
        help="Path to the input CSV (raw Telco schema, no 'Churn' column).",
    )
    parser.add_argument(
        "--output", "-o", required=True,
        help="Path to write the enriched CSV.",
    )
    parser.add_argument(
        "--band", "-b",
        choices=["Conservative", "Central", "Optimistic"],
        default="Central",
        help="Business scenario for threshold selection (default: Central).",
    )
    return parser.parse_args(argv)


def main(argv=None) -> None:
    args = _parse_args(argv)

    if not os.path.exists(args.input):
        raise FileNotFoundError(f"Input file not found: {args.input}")

    model, expected_columns, threshold_artifact = load_artefacts()

    band_data = threshold_artifact["bands"][args.band]
    threshold = band_data["threshold"]

    # Traceability: log what we're actually applying, in case the user later
    # wonders why a specific subscriber was flagged.
    print("=== Churn scoring ===")
    print(f"Input             : {args.input}")
    print(f"Output            : {args.output}")
    print(f"Band              : {args.band}")
    print(f"Threshold         : {threshold:.3f}")
    print(f"Assumptions       : {band_data['assumptions']}")

    df_in = pd.read_csv(args.input)
    df_out = predict_batch(
        df_in,
        model=model,
        expected_columns=expected_columns,
        threshold=threshold,
    )

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    df_out.to_csv(args.output, index=False)

    n = len(df_out)
    n_flagged = int(df_out["flag_for_retention"].sum())
    print(
        f"\nScored {n} subscribers -> {n_flagged} flagged for retention "
        f"({100 * n_flagged / n:.1f}%). Written to {args.output}."
    )


if __name__ == "__main__":
    main()
