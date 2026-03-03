import pandas as pd
import sys

def filter_resistant_rows(input_csv, output_csv, n_non_resistant=1000, random_seed=42):
    # Columns to check
    resistance_cols = [
        "ETHAMBUTOL",
        "ISONIAZID",
        "PYRAZINAMIDE",
        "RIFAMPICIN"
    ]
    
     # Load CSV
    df = pd.read_csv(input_csv)

    # Ensure columns exist
    missing = [col for col in resistance_cols if col not in df.columns]
    if missing:
        raise ValueError(f"Missing expected columns: {missing}")

    # Normalize values
    df[resistance_cols] = (
        df[resistance_cols]
        .astype(str)
        .apply(lambda col: col.str.upper().str.strip())
    )

    # Resistance mask
    resistance_mask = df[resistance_cols].eq("R")

    # Rows with ≥1 R
    resistant_df = df[resistance_mask.any(axis=1)]

    # Rows with NO R in any column
    non_resistant_df = df[~resistance_mask.any(axis=1)]

    # Randomly sample up to n_non_resistant
    sampled_non_resistant = non_resistant_df.sample(
        n=min(n_non_resistant, len(non_resistant_df)),
        random_state=random_seed
    )

    # Combine
    final_df = pd.concat([resistant_df, sampled_non_resistant]).reset_index(drop=True)

    # Save
    final_df.to_csv(output_csv, index=False)

    # -------- SUMMARY REPORT --------
    total_rows = len(df)
    total_resistant_rows = len(resistant_df)
    total_non_resistant = len(non_resistant_df)

    print("\n===== RESISTANCE SUMMARY REPORT =====")
    print(f"Total rows in dataset: {total_rows}")
    print(f"Total resistant rows (≥1 R): {total_resistant_rows}")
    print(f"Total fully non-resistant rows: {total_non_resistant}")
    print(f"Sampled non-resistant rows added: {len(sampled_non_resistant)}")
    print(f"Final output row count: {len(final_df)}\n")

    print("Resistance breakdown by drug:")
    for drug in resistance_cols:
        count_R = resistance_mask[drug].sum()
        percent_R = count_R / total_rows
        print(f"{drug:15} : {count_R} ({percent_R:.2%})")

    print(f"\nFiltered dataset saved to {output_csv}")
    print("=====================================\n")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python filter_resistance.py input.csv output.csv")
        sys.exit(1)

    input_csv = sys.argv[1]
    output_csv = sys.argv[2]

    filter_resistant_rows(input_csv, output_csv)
