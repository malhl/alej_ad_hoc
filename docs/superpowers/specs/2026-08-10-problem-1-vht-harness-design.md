# Problem 1 Harness Design: VHT Predictive Model

## Purpose

`initial-problem-statement.md` poses a question: given the glass composition and Vapor
Hydration Test (VHT) data from Vienna et al. (2020), "Glass Property-Composition Models
for Support of Hanford WTP LAW Facility Operation" (PNNL-30932 Rev. 1), can an LLM — acting
agentically, writing and executing its own analysis code — build a predictive statistical
model that meets the requirements laid out in Problem 1?

This document designs the **harness**: the repeatable project structure and procedure used
to run that experiment, not the statistical result itself. It covers Problem 1 only. The
prologue (toy linear-model warm-up) and Problem 2 (design of 20 additional glass
formulations) are out of scope for this design and may reuse this structure later.

## Mode of operation

The "LLM" under test is a Claude Code session working agentically: given the data and the
paper, it writes and runs real analysis code (R) to fit models, compute statistics, and
produce output — the same way this session works. This is not a raw-prompt-only test, and
not a multi-model comparison harness.

## Source material and a key finding

The reference document (https://www.osti.gov/servlets/purl/1986346) is a 9.8MB PDF. Initial
inspection found:

- `pdftotext -layout` (available via Git for Windows' bundled `mingw64/bin`) extracts clean,
  readable text, including the data tables. `pdftoppm`/visual page rendering is not
  installed and is not needed for this project — text extraction is sufficient.
- The dataset covers **699 simulated and actual LAW glasses**, with oxide composition given
  as mass fractions (summing to 1 per glass) and a measured VHT alteration rate (`ra`, in
  g/m²/d, ranging 0.1–1529.1 across the dataset).
- **The paper does not build a continuous regression model for VHT.** It explicitly states
  that predicting the continuous alteration rate from composition was too difficult, so the
  "recommended model" it reports goodness-of-fit statistics for is a **logistic pass/fail
  classifier** (pass if `ra` < 50 g/m²/d, matching WTP contract Specification 2.2.2.17.3).
  The raw continuous `ra` values do exist in the underlying table; they're just not what the
  paper's benchmark stats were computed against.

This matters because Problem 1, item 6 requires goodness-of-fit "equal to or better than
those in the source material" — but the source material has no continuous-model baseline to
compare against. See "Modeling approach" below for how this is resolved.

## Repo layout

```
alej_ad_hoc/
├── initial-problem-statement.md
├── README.md
├── docs/superpowers/specs/            this design doc
└── problem-1-vht-model/
    ├── data/
    │   ├── raw/                       source.pdf, pdftotext dump (cached)
    │   ├── glass_data.csv             cleaned composition + VHT dataset (the reusable artifact)
    │   └── paper_benchmarks.md        stats from the paper to compare against
    ├── scripts/
    │   ├── 00_extract_data.R
    │   ├── 01_clean_data.R
    │   ├── 02_fit_models.R
    │   └── 03_validate_models.R
    ├── models/                        saved fitted model objects (.rds)
    └── report.qmd                     renders to report.html — the final deliverable
```

`problem-1-vht-model/` is scoped to its own subfolder so Problem 2, or a re-run with a
different model configuration, can sit alongside it later without restructuring.
`glass_data.csv` is the key reusable artifact: once it exists, every later script or re-run
starts from it instead of re-touching the PDF.

## Pipeline

### 00_extract_data.R — extraction

Shells out to `pdftotext -layout` on `data/raw/vienna2020.pdf`, writing the raw text dump to
`data/raw/vienna2020.txt`. Because a fixed-width text table isn't generically
machine-parseable, locating the composition/VHT table within the dump and transcribing it
into `data/glass_data.csv` (one row per glass, one column per oxide component, plus
`ra_gm2d` and `pass_fail`) is Claude's judgment-driven work, not a generic parser. This is a
one-time step per data revision — later pipeline runs do not need to repeat it unless
`glass_data.csv` is deleted or the source data changes.

### 01_clean_data.R — validation

Deterministic and re-runnable: loads `glass_data.csv` and validates it before anything else
touches it. Checks, and **fails loudly rather than silently correcting**:

- Composition columns sum to ~1 per row, within tolerance.
- No missing VHT values.
- Row count is close to the expected ~699.
- No glass is missing a component that appears as a column for other glasses (asymmetric
  column sets).
- `ra_gm2d` values fall within the plausible range noted in the paper (0.1–1529.1).

Writes a cleaned, validated CSV consumed by every later step.

### 02_fit_models.R — modeling

Because composition columns are mass fractions summing to 1, these are mixture-experiment
models (matching the paper's own modeling framework), not ordinary regression with an
intercept. Two models are fit:

1. **Primary — continuous regression on `ra_gm2d`** (log-transformed, consistent with how
   the paper reasons about alteration rate near its threshold). A Scheffé-type mixture
   polynomial using all oxide components, starting from a linear-mixture form and adding
   pairwise interaction terms where significant — mirroring the paper's own
   first-order-linear-mixture → partial-quadratic-mixture progression. Produces the fitted
   equation, per-component effect estimates, R², and RMSE.
2. **Secondary — pass/fail logistic model**, replicating the paper's own approach on the
   same components, so its accuracy/AUC can be benchmarked directly against the paper's
   reported logistic model performance. This is the one comparison the source material
   actually supports.

Fitted model objects are saved to `models/*.rds`.

### 03_validate_models.R — validation stats

Computes leave-one-out cross-validation R²/RMSE for the continuous model, and confidence and
prediction intervals with an explanation of how they were derived (e.g., delta method or
bootstrap, appropriate to the nonlinear mixture form).

### report.qmd — final deliverable

Loads the saved model objects and `paper_benchmarks.md`, and renders `report.html` covering,
per the problem statement's checklist: the fitted equation, R²/RMSE/LOO-CV, confidence and
prediction intervals with justification, per-component effect estimates, and the
pass/fail-vs-paper comparison. This one document is both the final write-up and the
reproducible record of what was run.

**Point 6 handling**: the report states plainly that "equal to or better than the source"
applies cleanly only to the secondary pass/fail comparison, since the paper has no
continuous-model baseline. The primary model's R²/RMSE stands on its own merits, not as a
"beat the paper" claim.

## Error handling

- A script whose required input file is missing (e.g., `02_fit_models.R` run before
  `glass_data.csv` exists) fails loudly, naming the missing file and which script produces
  it. No silent fallback to stale data.
- If the mixture model fails to converge with interaction terms, the pipeline falls back to
  reporting the linear-mixture-only fit and notes the failure in the report rather than
  hiding it.
- Validation failures in `01_clean_data.R` (rows not summing to ~1, missing values, etc.)
  halt the pipeline rather than letting malformed rows reach modeling.

## Testing

This is an ad hoc analysis project, not a library — there is no separate unit-test suite.
"Testing" means: re-running `01` → `03` from the checked-in `glass_data.csv` reproduces the
same model and report output, and the validation checks in `01_clean_data.R` catch malformed
rows before they reach modeling.

## Out of scope for this design

- The prologue (toy linear-model warm-up).
- Problem 2 (designing 20 additional glass formulations / D-, G-, I-efficiency).
- Any multi-model or multi-provider comparison — this harness tests one agentic Claude Code
  session's output, not a comparison across LLMs.
