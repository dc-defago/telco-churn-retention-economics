import pandas as pd

def preprocess_features(df: pd.DataFrame, expected_columns=None) -> pd.DataFrame:
    df = df.copy()

    # Basic cleaning and preprocessing
    df = df.drop(columns=["customerID"], errors="ignore", axis=1)

    df.columns = [col[0].upper() + col[1:]
                  if isinstance(col, str) and col 
                  else col for col in df.columns]

    # Type and missing value handling
    df["TotalCharges"] = pd.to_numeric(df["TotalCharges"], errors="coerce")

    numeric_cols = df.select_dtypes(include=["number"]).columns
    categorical_cols = df.select_dtypes(include=["object"]).columns

    for col in numeric_cols:
        df[col] = df[col].fillna(0)

    for col in categorical_cols:
        df[col] = df[col].fillna("unknown")

    # One-hot encoding for categorical variables
    df = pd.get_dummies(df, drop_first=False)

    # Optional reordering of columns to match expected_columns
    if expected_columns is not None:
        df = df.reindex(columns=expected_columns, fill_value=0)

    return df
