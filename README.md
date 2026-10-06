# Credit Risk Probability-of-Default Model

> Work in progress. Problem, approach, results and screenshots will be filled in as phases complete.

## Data
Lending Club accepted loans, 2007-2018 (public, Kaggle: `wordsforthewise/lending-club`).
Modeling scope: 36-month loans issued 2013-2015, so every loan has a final outcome.

## How to run
```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python src/download_data.py
```
