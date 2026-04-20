import os
import joblib
import numpy as np
import pandas as pd

from sklearn.calibration import CalibratedClassifierCV
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
from sklearn.model_selection import RandomizedSearchCV, train_test_split
from xgboost import XGBClassifier
from sklearn.metrics import roc_auc_score

from src.preprocessing import preprocess_features


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

    # Preprocess input features and save expected feature schema for inference
    X_train = preprocess_features(X_train)
    expected_columns = X_train.columns.tolist()

    X_test = preprocess_features(X_test, expected_columns=expected_columns)
    X_train = X_train.reindex(columns=expected_columns, fill_value=0)

    # Define the base XGBoost model
    xgb = XGBClassifier(
        n_estimators = 100,
        max_depth = 3,
        learning_rate = 0.1,
        subsample = 0.8,
        colsample_bytree = 0.8,
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

    # Run randomized hyperparameter search
    search = RandomizedSearchCV(
        xgb,
        param_distributions = param_dist,
        n_iter = 20,
        scoring = "roc_auc",
        cv = 5,
        n_jobs = 1,
        random_state = 42,
        )

    search.fit(X_train, y_train)
    best_xgb = search.best_estimator_
    print("Best hyperparameters:", search.best_params_)

    # Calibration of predicted probabilities
    best_calibrated_xgb = CalibratedClassifierCV(
        best_xgb,
        method = "sigmoid",
        cv = 5
    )

    best_calibrated_xgb.fit(X_train, y_train)
    y_proba = best_calibrated_xgb.predict_proba(X_test)[:, 1]

    # Threshold tuning
    thresholds = np.arange(0.2, 0.96, 0.01)
    results = []

    for t in thresholds:
        y_pred_t = (y_proba >= t).astype(int)
    
        results.append({
            "threshold": t,
            "accuracy": accuracy_score(y_test, y_pred_t),
            "precision": precision_score(y_test, y_pred_t, zero_division = 0),
            "recall": recall_score(y_test, y_pred_t),
            "f1": f1_score(y_test, y_pred_t),
     })
    
    threshold_df = pd.DataFrame(results)

    # Select the best threshold
    candidates = threshold_df[threshold_df["precision"] >= 0.50]
    if candidates.empty:
        best_row = threshold_df.loc[threshold_df["f1"].idxmax()]
    else:
        best_row = candidates.loc[candidates["recall"].idxmax()]

    threshold = best_row["threshold"]
    y_pred_opt = (y_proba >= threshold).astype(int)
    
    # Print final evaluation metrics
    print("Selected threshold:", threshold)
    print(best_row)
    print("Final accuracy:", accuracy_score(y_test, y_pred_opt))
    print("Final precision:", precision_score(y_test, y_pred_opt, zero_division = 0))
    print("Final recall:", recall_score(y_test, y_pred_opt))
    print("Final f1:", f1_score(y_test, y_pred_opt))
    print("ROC AUC:", roc_auc_score(y_test, y_proba))

    # Save training artifacts 
    models_dir = os.path.join(BASE_DIR, "models")
    os.makedirs(models_dir, exist_ok = True)

    joblib.dump(best_calibrated_xgb, os.path.join(models_dir, "model.pkl"))
    joblib.dump(expected_columns, os.path.join(models_dir, "columns.pkl"))
    joblib.dump(threshold, os.path.join(models_dir, "threshold.pkl"))

    print(f"Saved model to {os.path.join(models_dir, 'model.pkl')}")
    print(f"Saved columns to {os.path.join(models_dir, 'columns.pkl')}")
    print(f"Saved threshold to {os.path.join(models_dir, 'threshold.pkl')}")
    
    print("\n--- Training complete ---\n")

if __name__ == "__main__":
    train()