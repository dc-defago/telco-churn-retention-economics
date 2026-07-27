import os
import joblib
import numpy as np
import pandas as pd

from sklearn.calibration import CalibratedClassifierCV
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.frozen import FrozenEstimator
from sklearn.model_selection import RandomizedSearchCV, train_test_split
from xgboost import XGBClassifier
from sklearn.metrics import roc_auc_score

from src.preprocessing import preprocess_features

from src.business_value import select_operating_threshold, sensitivity_analysis, build_telecom_scenarios, horizon_sensitivity


def train():
    """Train the churn prediction model and save inference artifacts."""

    # Load the dataset
    BASE_DIR = os.path.dirname(os.path.dirname(__file__))
    DATA_PATH = os.path.join(BASE_DIR, "data", "WA_Fn-UseC_-Telco-Customer-Churn.csv")
    df = pd.read_csv(DATA_PATH)

    # Encode target variable and separate target from features
    df["Churn"] = df["Churn"].map({"Yes": 1, "No": 0})
    X = df.drop(columns=["Churn"])
    y = df["Churn"]

    # Split data into training and testing sets
    X_train, X_test, y_train, y_test = train_test_split(
        X, 
        y,
        test_size=0.2,
        random_state=42,
        stratify=y
    )

    # Keep raw copies to feed business_value.py with the aligned MonthlyCharges and tenure
    X_train_raw, X_test_raw = X_train.copy(), X_test.copy()

    # Preprocess input features and save expected feature schema for inference
    X_train = preprocess_features(X_train)
    expected_columns = X_train.columns.tolist()

    X_test = preprocess_features(X_test, expected_columns=expected_columns)
    X_train = X_train.reindex(columns=expected_columns, fill_value=0)

    # Split X_train into a fit set (for search + best_xgb) and a calibration set
    # held out from both, so calibration probabilities come from a model that has
    # never seen the calibration data.
    X_fit, X_cal, y_fit, y_cal = train_test_split(
        X_train, y_train,
        test_size=0.2,
        random_state=42,
        stratify=y_train,
    )

    # Define the base XGBoost model
    xgb = XGBClassifier(
        random_state = 42,
        eval_metric = "logloss"
    )

    # Hyperparameter tuning with RandomizedSearchCV

    # Define the hyperparameter search space
    param_dist = {
        "max_depth": [3, 4, 5, 6],
        "learning_rate": [0.01, 0.05, 0.1],
        "n_estimators": [100, 200, 300],
        "subsample": [0.6, 0.8, 1.0],
        "colsample_bytree": [0.6, 0.8, 1.0],
    }

    # Run randomized hyperparameter search on the fit set only, so that nothing
    # used for calibration has influenced the hyperparameter choice.
    search = RandomizedSearchCV(
        xgb,
        param_distributions = param_dist,
        n_iter = 20,
        scoring = "roc_auc",
        cv = 5,
        n_jobs = 1,
        random_state = 42,
        )

    search.fit(X_fit, y_fit)
    best_xgb = search.best_estimator_  # already refit on X_fit by RandomizedSearchCV
    print("Best hyperparameters:", search.best_params_)

    # Calibration of predicted probabilities on the held-out calibration set,
    # which best_xgb has never seen.
    best_calibrated_xgb = CalibratedClassifierCV(
        FrozenEstimator(best_xgb),
        method = "sigmoid",
    )

    best_calibrated_xgb.fit(X_cal, y_cal)
    y_proba = best_calibrated_xgb.predict_proba(X_test)[:, 1]

    # Extract raw MonthlyCharges and tenure for the test set, aligned on y_test
    mc_test = X_test_raw.loc[y_test.index, "MonthlyCharges"]
    tn_test = X_test_raw.loc[y_test.index, "tenure"]

    # Business-value-based threshold selection (central scenario)
    threshold = select_operating_threshold(
        proba_cal=y_proba,
        y_true=y_test,
        monthly_charges=mc_test,
        tenure=tn_test,
        band="Central",
    )

    y_pred_opt = (y_proba >= threshold).astype(int)
    
    # Print final evaluation metrics
    print(f"Selected threshold (Central band, value-based): {threshold:.3f}")
    print(f"ROC AUC (threshold-free):    {roc_auc_score(y_test, y_proba):.3f}")
    print(f"At business threshold {threshold:.3f}:")
    print(f"  Precision: {precision_score(y_test, y_pred_opt, zero_division=0):.3f}   Recall: {recall_score(y_test, y_pred_opt):.3f}   F1: {f1_score(y_test, y_pred_opt):.3f}")

    scenarios = build_telecom_scenarios(tn_test, y_test)
    sens = sensitivity_analysis(y_proba, y_test, mc_test, scenarios)
    print("\n=== Business-value sensitivity ===")
    print(sens.to_string(index=False))

    reports_dir = os.path.join(BASE_DIR, "reports")
    os.makedirs(reports_dir, exist_ok=True)
    sens.to_csv(os.path.join(reports_dir, "sensitivity.csv"), index=False)

    # Save training artifacts
    models_dir = os.path.join(BASE_DIR, "models")
    os.makedirs(models_dir, exist_ok = True)

    central = [s for s in scenarios if s.name == "Central"][0]
    threshold_artifact = {
        "threshold": float(threshold),
        "band": "Central",
        "assumptions": {
            "c_offer_CHF": central.c_offer,
            "p_save": central.p_save,
            "margin": central.margin,
            "horizon_months": round(central.horizon_months, 2),
        },
    }
    hz = horizon_sensitivity(y_proba, y_test, mc_test, central)
    print("\n=== Horizon sensitivity (Central scenario, one-way) ===")
    print(hz.to_string(index=False))
    hz.to_csv(os.path.join(reports_dir, "horizon_sensitivity.csv"), index=False)

    joblib.dump(best_calibrated_xgb, os.path.join(models_dir, "model.pkl"))
    joblib.dump(expected_columns, os.path.join(models_dir, "columns.pkl"))
    joblib.dump(threshold_artifact, os.path.join(models_dir, "threshold.pkl"))

    print(f"Saved model to {os.path.join(models_dir, 'model.pkl')}")
    print(f"Saved columns to {os.path.join(models_dir, 'columns.pkl')}")
    print(f"Saved threshold to {os.path.join(models_dir, 'threshold.pkl')}")

    print("\n--- Training complete ---\n")

if __name__ == "__main__":
    train()
