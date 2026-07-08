import pandas as pd
import os
import glob

# 1. Define the path to your target NASS directory folder
nass_folder = os.path.join("data", "outcome", "National-Agricultural-Statistics-Service")

# 2. Grab a list of every single CSV file inside that specific directory
csv_files = glob.glob(os.path.join(nass_folder, "*.csv"))

print(f"Found {len(csv_files)} CSV files to process inside the directory.")

# 3. Loop through each discovered CSV file one by one
for file_path in csv_files:
    try:
        # Load the current dataset, forcing the code columns to read as strings
        df = pd.read_csv(file_path, dtype={"state_fips_code": str, "county_code": str})
        
        # Verify if BOTH required column headers are actually present in this file
        if "state_fips_code" in df.columns and "county_code" in df.columns:
            
            # Clean and pad the codes (e.g., turning state '51' and county '43' into standard text sizes)
            state_clean = df["state_fips_code"].str.strip().str.zfill(2)
            county_clean = df["county_code"].str.strip().str.zfill(3)
            
            # Mash the two strings together to append your uniform 5-digit FIPS column
            df["fips_code"] = state_clean + county_clean
            
            # Overwrite the original file on disk with the new column included
            df.to_csv(file_path, index=False)
            print(f" -> Successfully added 'fips_code' to: {os.path.basename(file_path)}")
        else:
            # Safely skip files that don't need this specific column adjustment
            print(f" -> Skipped (Columns not found): {os.path.basename(file_path)}")
            
    except Exception as e:
        # Alert if a file is still locked by Excel or corrupt
        print(f" [!] Error processing {os.path.basename(file_path)}: {str(e)}")

print("\nAll NASS folder datasets have been successfully processed!")