# Problem 1 VHT Harness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the R pipeline (extract → clean → fit → validate → report) that produces a
continuous predictive model for glass VHT alteration rate from the Vienna et al. (2020)
dataset, per `docs/superpowers/specs/2026-08-10-problem-1-vht-harness-design.md`.

**Architecture:** Numbered R scripts under `problem-1-vht-model/scripts/` each read/write
files under `problem-1-vht-model/data/` and `problem-1-vht-model/models/`, so later stages
never need to re-touch the source PDF. A final `report.qmd` renders the write-up from the
saved model objects.

**Tech Stack:** R (base R only — no CRAN packages beyond `knitr`/`rmarkdown`, which Quarto's
R engine needs), `pdftotext` (Git for Windows' bundled `mingw64/bin/pdftotext.exe`), Quarto
CLI for rendering `report.qmd`.

## Global Constraints

- All scripts live under `problem-1-vht-model/` and are run with the repo root as the
  working directory (paths in scripts are relative to `problem-1-vht-model/`).
- `data/raw/` (the source PDF and the raw `pdftotext` dump) is gitignored — large and
  regenerable. `data/glass_data.csv`, `data/glass_data_clean.csv`, and
  `data/paper_benchmarks.md` ARE committed — they're the reusable, re-run-without-network
  artifacts the design calls for.
- Every validation check fails loudly (`stop()` with a message naming the offending
  `glass_num`s) — never silently drop or coerce bad rows.
- The 20 oxide component names, in this exact order, are used consistently across every
  script: `Al2O3, B2O3, CaO, Cl, Cr2O3, F, Fe2O3, K2O, Li2O, MgO, Na2O, P2O5, SO3, SiO2,
  SnO2, TiO2, V2O5, ZnO, ZrO2, Others` (verbatim from the paper, Section 9.2).
- Known paper benchmarks to validate extraction against (Section 9.2 of the source PDF):
  699 glasses have VHT data, 162 of those exceed the 50 g/m²/d fail threshold, `ra` ranges
  0.1–1529.1 g/m²/d, and 13 glasses were later excluded as compositional outliers leaving
  686 for modeling. The paper's own recommended classifier (19-term PQM) achieves 79.74%
  accuracy, 24.24% FPR, 6.96% FNR; its 20-term FLM alternative achieves 86.30% accuracy,
  13.26% FPR, 15.19% FNR. There is no continuous-model (R²/RMSE) baseline in the paper.

---

## Task 1: Environment check and repo scaffold

**Files:**
- Create: `problem-1-vht-model/.gitignore`
- Create: `problem-1-vht-model/data/raw/` (empty dir, via `.gitkeep`)
- Create: `problem-1-vht-model/scripts/` (empty dir, via `.gitkeep`)
- Create: `problem-1-vht-model/models/` (empty dir, via `.gitkeep`)

**Interfaces:**
- Produces: the directory layout every later task writes into.

- [x] **Step 1: Verify required tooling is on PATH**

Run:
```
where Rscript
where pdftotext
where quarto
```
Expected: all three print a path. `pdftotext` should already resolve to Git for Windows'
`mingw64\bin\pdftotext.exe`. If `Rscript` or `quarto` is missing, stop here and install them
before continuing (R: https://cran.r-project.org/bin/windows/base/ , or
`winget install --id RProject.R -e`; Quarto: https://quarto.org/docs/get-started/ , or
`winget install --id Posit.Quarto -e`). Re-open the shell afterward so PATH updates apply.

- [x] **Step 2: Install the R packages Quarto's R engine needs**

Run:
```
Rscript -e "install.packages(c('knitr', 'rmarkdown'), repos = 'https://cloud.r-project.org')"
```
Expected: both packages install without error. Verify with
`Rscript -e "library(knitr); library(rmarkdown); cat('OK\n')"` → prints `OK`.

- [x] **Step 3: Create the directory structure**

```bash
mkdir -p problem-1-vht-model/data/raw
mkdir -p problem-1-vht-model/scripts
mkdir -p problem-1-vht-model/models
touch problem-1-vht-model/data/raw/.gitkeep
touch problem-1-vht-model/scripts/.gitkeep
touch problem-1-vht-model/models/.gitkeep
```

- [x] **Step 4: Create `problem-1-vht-model/.gitignore`**

```
data/raw/*.pdf
data/raw/*.txt
```

- [x] **Step 5: Verify and commit**

Run: `git status` — expect the new directories/files as untracked.

```bash
git add problem-1-vht-model/.gitignore problem-1-vht-model/data/raw/.gitkeep problem-1-vht-model/scripts/.gitkeep problem-1-vht-model/models/.gitkeep
git commit -m "Scaffold problem-1-vht-model project structure"
```

---

## Task 2: Extract raw text from the source PDF

**Files:**
- Create: `problem-1-vht-model/scripts/00_extract_data.R`

**Interfaces:**
- Consumes: none (fetches its own input over the network).
- Produces: `problem-1-vht-model/data/raw/vienna2020.pdf`,
  `problem-1-vht-model/data/raw/vienna2020.txt` (consumed by Task 3).

- [ ] **Step 1: Write the extraction script**

```r
# problem-1-vht-model/scripts/00_extract_data.R
pdf_path <- "data/raw/vienna2020.pdf"
txt_path <- "data/raw/vienna2020.txt"

if (!file.exists(pdf_path)) {
  download.file(
    "https://www.osti.gov/servlets/purl/1986346",
    destfile = pdf_path, mode = "wb", method = "libcurl"
  )
}
stopifnot(file.exists(pdf_path))

status <- system2("pdftotext", args = c("-layout", pdf_path, txt_path))
stopifnot(status == 0, file.exists(txt_path))

lines <- readLines(txt_path, warn = FALSE)
stopifnot(
  any(grepl("^Table A\\.2\\. Normalized Compositions", lines)),
  any(grepl("^Table A\\.3\\. Properties of LAW Glasses", lines))
)
cat(sprintf("Extracted %d lines to %s\n", length(lines), txt_path))
```

- [ ] **Step 2: Run it and verify**

Run: `cd problem-1-vht-model && Rscript scripts/00_extract_data.R`

Expected: downloads the ~10MB PDF (first run only), then prints
`Extracted <N> lines to data/raw/vienna2020.txt` with N in the tens of thousands. Re-run it —
expected: skips the download (file already exists) and re-extracts text, same message.

- [ ] **Step 3: Commit**

```bash
git add problem-1-vht-model/scripts/00_extract_data.R
git commit -m "Add PDF-to-text extraction script for VHT source data"
```

---

## Task 3: Parse the composition and VHT tables into `glass_data.csv`

**Files:**
- Modify: `problem-1-vht-model/scripts/00_extract_data.R` (append parsing logic)

**Interfaces:**
- Consumes: `problem-1-vht-model/data/raw/vienna2020.txt` (from Task 2).
- Produces: `problem-1-vht-model/data/glass_data.csv` with columns `glass_num, glass_id,
  Al2O3, B2O3, CaO, Cl, Cr2O3, F, Fe2O3, K2O, Li2O, MgO, Na2O, P2O5, SO3, SiO2, SnO2, TiO2,
  V2O5, ZnO, ZrO2, Others, ra_gm2d, pass_fail` — consumed by Task 4.

The composition table (Table A.2) lists, per glass, an integer `glass_num`, a `glass_id`,
and 20 whitespace-separated oxide mass fractions. The properties table (Table A.3) lists,
per glass, several property columns; the 6th and 7th tokens after the glass ID are always
`ra_gm2d` (VHT alteration rate) and `pass_fail` (`P`/`F`) whenever a glass has VHT data —
trailing blank columns are dropped by `pdftotext`, but these two are never trailing since
`BS/SR/Bub/MT/3TS` columns follow them, so position-based extraction is reliable. Rows
without VHT data, or that are page-header/footer artifacts, naturally fail the "must be
exactly 20 numeric values" / "6th token must parse as numeric" checks and are dropped.

- [ ] **Step 1: Append the parsing logic to `00_extract_data.R`**

```r
oxide_cols <- c("Al2O3","B2O3","CaO","Cl","Cr2O3","F","Fe2O3","K2O","Li2O",
                 "MgO","Na2O","P2O5","SO3","SiO2","SnO2","TiO2","V2O5","ZnO",
                 "ZrO2","Others")

a2_start <- grep("^Table A\\.2\\. Normalized Compositions", lines)[1]
a3_start <- grep("^Table A\\.3\\. Properties of LAW Glasses", lines)[1]
a4_start <- grep("^Table A\\.4\\.", lines)[1]
a3_end <- if (is.na(a4_start)) length(lines) else a4_start - 1
stopifnot(!is.na(a2_start), !is.na(a3_start), a3_start > a2_start)

parse_a2_line <- function(x) {
  x <- trimws(x)
  if (!grepl("^[0-9]+\\s", x)) return(NULL)
  glass_num <- as.integer(regmatches(x, regexpr("^[0-9]+", x)))
  rest <- trimws(sub("^[0-9]+", "", x))
  toks <- strsplit(rest, "\\s{2,}")[[1]]
  toks <- toks[nzchar(toks)]
  if (length(toks) < 2) return(NULL)
  glass_id <- toks[1]
  values <- suppressWarnings(as.numeric(sub("\\*$", "", toks[-1])))
  if (length(values) != 20 || anyNA(values)) return(NULL)
  c(list(glass_num = glass_num, glass_id = glass_id),
    setNames(as.list(values), oxide_cols))
}

parse_a3_line <- function(x) {
  x <- trimws(x)
  if (!grepl("^[0-9]+\\s", x)) return(NULL)
  glass_num <- as.integer(regmatches(x, regexpr("^[0-9]+", x)))
  rest <- trimws(sub("^[0-9]+", "", x))
  toks <- strsplit(rest, "\\s{2,}")[[1]]
  toks <- toks[nzchar(toks)]
  if (length(toks) < 7) return(NULL)
  ra_val <- suppressWarnings(as.numeric(sub("\\*$", "", toks[6])))
  pf_val <- toks[7]
  if (is.na(ra_val) || !(pf_val %in% c("P", "F"))) return(NULL)
  list(glass_num = glass_num, ra_gm2d = ra_val, pass_fail = pf_val)
}

a2_rows <- Filter(Negate(is.null), lapply(lines[a2_start:(a3_start - 1)], parse_a2_line))
composition <- do.call(rbind, lapply(a2_rows, as.data.frame, stringsAsFactors = FALSE))
cat(sprintf("Parsed %d composition rows from Table A.2 (paper: ~1075)\n", nrow(composition)))
stopifnot(nrow(composition) >= 1000)

a3_rows <- Filter(Negate(is.null), lapply(lines[a3_start:a3_end], parse_a3_line))
vht <- do.call(rbind, lapply(a3_rows, as.data.frame, stringsAsFactors = FALSE))
n_fail <- sum(vht$pass_fail == "F")
cat(sprintf("Parsed %d rows with VHT data from Table A.3 (paper: 699, 162 fail); got %d fail\n",
            nrow(vht), n_fail))
stopifnot(abs(nrow(vht) - 699) <= 15, abs(n_fail - 162) <= 15)

glass_data <- merge(composition, vht, by = "glass_num")
cat(sprintf("Joined glass_data.csv has %d rows\n", nrow(glass_data)))
write.csv(glass_data, "data/glass_data.csv", row.names = FALSE)
```

- [ ] **Step 2: Run it**

Run: `cd problem-1-vht-model && Rscript scripts/00_extract_data.R`

Expected: prints composition row count (~1000+), VHT row count within 15 of 699, fail count
within 15 of 162, joined row count, and writes `data/glass_data.csv`. If either `stopifnot`
trips, the printed diagnostic tells you which count is off — inspect
`data/raw/vienna2020.txt` around the printed table boundaries and adjust the parsing
regexes (most likely cause: a page-break artifact line that isn't being filtered out).

- [ ] **Step 3: Spot-check the output**

Run:
```
Rscript -e "d <- read.csv('problem-1-vht-model/data/glass_data.csv'); print(head(d[, c('glass_num','glass_id','SiO2','Na2O','ra_gm2d','pass_fail')])); cat('rows:', nrow(d), '\n')"
```
Expected: sensible glass IDs (e.g. `LAWA49`, `LAWA50`), `SiO2`/`Na2O` values between 0 and 1,
`ra_gm2d` values in [0.1, 1529.1], `pass_fail` values of `P` or `F`.

- [ ] **Step 4: Commit**

```bash
git add problem-1-vht-model/scripts/00_extract_data.R problem-1-vht-model/data/glass_data.csv
git commit -m "Parse composition and VHT tables into glass_data.csv"
```

---

## Task 4: Validate and clean the dataset

**Files:**
- Create: `problem-1-vht-model/scripts/01_clean_data.R`
- Create (temporary, for Step 1 only, then delete): `problem-1-vht-model/data/test_fixtures/bad_composition.csv`

**Interfaces:**
- Consumes: `problem-1-vht-model/data/glass_data.csv` (from Task 3), same 23-column schema
  as documented in Task 3's Interfaces.
- Produces: `problem-1-vht-model/data/glass_data_clean.csv` (identical schema) — consumed by
  Task 5.

- [ ] **Step 1: Write a bad-data fixture and the failing-case check**

Create `problem-1-vht-model/data/test_fixtures/bad_composition.csv` with this exact content
(header plus one row whose oxide columns sum to 0.5, not 1.0):

```csv
glass_num,glass_id,Al2O3,B2O3,CaO,Cl,Cr2O3,F,Fe2O3,K2O,Li2O,MgO,Na2O,P2O5,SO3,SiO2,SnO2,TiO2,V2O5,ZnO,ZrO2,Others,ra_gm2d,pass_fail
1,TESTGLASS,0.05,0.1,0.05,0,0,0,0.05,0,0.05,0.05,0.15,0,0,0.5,0,0,0,0,0,0,10,P
```

- [ ] **Step 2: Write `01_clean_data.R`**

```r
# problem-1-vht-model/scripts/01_clean_data.R
args <- commandArgs(trailingOnly = TRUE)
input_path <- if (length(args) >= 1) args[1] else "data/glass_data.csv"

oxide_cols <- c("Al2O3","B2O3","CaO","Cl","Cr2O3","F","Fe2O3","K2O","Li2O",
                 "MgO","Na2O","P2O5","SO3","SiO2","SnO2","TiO2","V2O5","ZnO",
                 "ZrO2","Others")

glass <- read.csv(input_path, stringsAsFactors = FALSE)

row_sums <- rowSums(glass[oxide_cols])
bad_sum <- which(abs(row_sums - 1) > 0.01)
if (length(bad_sum) > 0) {
  stop(sprintf("Composition does not sum to ~1 for glass_num %s",
               paste(glass$glass_num[bad_sum], collapse = ", ")))
}

check_cols <- c(oxide_cols, "ra_gm2d", "pass_fail")
if (anyNA(glass[check_cols])) {
  stop("Missing values found in composition or VHT columns")
}

out_of_range <- glass$ra_gm2d < 0.1 | glass$ra_gm2d > 1529.1
if (any(out_of_range)) {
  stop(sprintf("ra_gm2d outside plausible range [0.1, 1529.1] for glass_num %s",
               paste(glass$glass_num[out_of_range], collapse = ", ")))
}

if (!all(glass$pass_fail %in% c("P", "F"))) {
  stop("pass_fail column contains values other than P/F")
}

if (nrow(glass) < 650 || nrow(glass) > 720) {
  stop(sprintf("Row count %d outside expected range [650, 720] (paper: 699 total, 686 modeled)",
               nrow(glass)))
}

write.csv(glass, "data/glass_data_clean.csv", row.names = FALSE)
cat(sprintf("Validated %d rows; wrote data/glass_data_clean.csv\n", nrow(glass)))
```

- [ ] **Step 3: Run against the bad fixture and verify it fails**

Run: `cd problem-1-vht-model && Rscript scripts/01_clean_data.R data/test_fixtures/bad_composition.csv`

Expected: FAILS with `Error: Composition does not sum to ~1 for glass_num 1`.

- [ ] **Step 4: Run against the real data and verify it passes**

Run: `cd problem-1-vht-model && Rscript scripts/01_clean_data.R`

Expected: prints `Validated <N> rows; wrote data/glass_data_clean.csv` with N between 650
and 720. If it fails instead, the error message names the offending `glass_num`(s) and the
specific check that tripped — go inspect those rows in `data/glass_data.csv` and fix the
Task 3 parsing regexes rather than patching around them here.

- [ ] **Step 5: Remove the fixture and commit**

```bash
rm -rf problem-1-vht-model/data/test_fixtures
git add problem-1-vht-model/scripts/01_clean_data.R problem-1-vht-model/data/glass_data_clean.csv
git commit -m "Add data validation script producing glass_data_clean.csv"
```

---

## Task 5: Fit the primary continuous VHT model

**Files:**
- Create: `problem-1-vht-model/scripts/02_fit_models.R`

**Interfaces:**
- Consumes: `problem-1-vht-model/data/glass_data_clean.csv` (from Task 4).
- Produces: `problem-1-vht-model/models/continuous_model.rds` (an `lm` object) — consumed by
  Task 7 and `report.qmd`.

The response is `log(ra_gm2d)` (the paper notes a log transform improves VHT modeling,
Section 9.2). Because the 20 oxide columns are mass fractions summing to 1, this is a
Scheffé mixture model fit without an intercept. Candidate pairwise interaction terms are
screened one at a time via `add1()` (cheap — it fits one augmented model per candidate
against the already-fit linear model, rather than a single enormous 210-parameter model),
and only those significant at p < 0.05 are added to the final model.

- [ ] **Step 1: Write the continuous-model section of `02_fit_models.R`**

```r
# problem-1-vht-model/scripts/02_fit_models.R
oxide_cols <- c("Al2O3","B2O3","CaO","Cl","Cr2O3","F","Fe2O3","K2O","Li2O",
                 "MgO","Na2O","P2O5","SO3","SiO2","SnO2","TiO2","V2O5","ZnO",
                 "ZrO2","Others")

glass <- read.csv("data/glass_data_clean.csv", stringsAsFactors = FALSE)
glass$log_ra <- log(glass$ra_gm2d)

linear_formula <- as.formula(paste("log_ra ~", paste(oxide_cols, collapse = " + "), "- 1"))
fit_linear <- lm(linear_formula, data = glass)

pair_terms <- combn(oxide_cols, 2, function(p) paste(p, collapse = ":"))
scope_formula <- as.formula(paste("~ . +", paste(pair_terms, collapse = " + ")))
add1_result <- add1(fit_linear, scope = scope_formula, test = "F")
sig_terms <- rownames(add1_result)[!is.na(add1_result[["Pr(>F)"]]) & add1_result[["Pr(>F)"]] < 0.05]
cat(sprintf("Significant interaction terms (p < 0.05): %s\n",
            if (length(sig_terms) == 0) "(none)" else paste(sig_terms, collapse = ", ")))

final_formula <- as.formula(paste("log_ra ~",
                                   paste(c(oxide_cols, sig_terms), collapse = " + "), "- 1"))
fit_continuous <- lm(final_formula, data = glass)

r2 <- summary(fit_continuous)$r.squared
rmse <- sqrt(mean(residuals(fit_continuous)^2))
cat(sprintf("Continuous model: R2 = %.4f, RMSE (log scale) = %.4f, %d terms\n",
            r2, rmse, length(coef(fit_continuous))))

stopifnot(r2 > 0, r2 < 1, rmse > 0, all(oxide_cols %in% names(coef(fit_continuous))))

dir.create("models", showWarnings = FALSE)
saveRDS(fit_continuous, "models/continuous_model.rds")
```

- [ ] **Step 2: Run it**

Run: `cd problem-1-vht-model && Rscript scripts/02_fit_models.R`

Expected: prints the list of significant interaction terms (or `(none)`), then
`Continuous model: R2 = 0.xxxx, RMSE (log scale) = x.xxxx, N terms`, with R² strictly
between 0 and 1. Writes `models/continuous_model.rds`.

- [ ] **Step 3: Verify all 20 components are represented**

Run:
```
Rscript -e "m <- readRDS('problem-1-vht-model/models/continuous_model.rds'); oxides <- c('Al2O3','B2O3','CaO','Cl','Cr2O3','F','Fe2O3','K2O','Li2O','MgO','Na2O','P2O5','SO3','SiO2','SnO2','TiO2','V2O5','ZnO','ZrO2','Others'); stopifnot(all(oxides %in% names(coef(m)))); cat('All 20 components present\n')"
```
Expected: `All 20 components present`.

- [ ] **Step 4: Commit**

```bash
git add problem-1-vht-model/scripts/02_fit_models.R
git commit -m "Fit primary continuous mixture model for VHT alteration rate"
```

---

## Task 6: Fit the secondary pass/fail logistic model

**Files:**
- Modify: `problem-1-vht-model/scripts/02_fit_models.R` (append logistic-model section)

**Interfaces:**
- Consumes: `glass` data frame already loaded earlier in the same script (Task 5); reuses
  `oxide_cols`.
- Produces: `problem-1-vht-model/models/logistic_model.rds` (a `glm` object) — consumed by
  Task 7 and `report.qmd`.

- [ ] **Step 1: Append the logistic-model section to `02_fit_models.R`**

```r
glass$pass_fail_bin <- ifelse(glass$pass_fail == "F", 1, 0)
logit_formula <- as.formula(paste("pass_fail_bin ~", paste(oxide_cols, collapse = " + "), "- 1"))
fit_logistic <- glm(logit_formula, data = glass, family = binomial(link = "logit"))

pred_prob <- predict(fit_logistic, type = "response")
pred_class <- ifelse(pred_prob >= 0.5, 1, 0)
accuracy <- mean(pred_class == glass$pass_fail_bin)
fpr <- mean(pred_class[glass$pass_fail_bin == 0] == 1)
fnr <- mean(pred_class[glass$pass_fail_bin == 1] == 0)

cat(sprintf("Logistic model: accuracy = %.2f%%, FPR = %.2f%%, FNR = %.2f%%\n",
            accuracy * 100, fpr * 100, fnr * 100))
cat("Paper's 20-term FLM: accuracy = 86.30%, FPR = 13.26%, FNR = 15.19%\n")
cat("Paper's 19-term PQM (recommended): accuracy = 79.74%, FPR = 24.24%, FNR = 6.96%\n")

stopifnot(accuracy > 0, accuracy <= 1, fpr >= 0, fpr <= 1, fnr >= 0, fnr <= 1)

saveRDS(fit_logistic, "models/logistic_model.rds")
```

- [ ] **Step 2: Run the full script**

Run: `cd problem-1-vht-model && Rscript scripts/02_fit_models.R`

Expected: continuous-model output from Task 5, followed by
`Logistic model: accuracy = xx.xx%, FPR = xx.xx%, FNR = xx.xx%` and the two paper-benchmark
reference lines. Writes `models/logistic_model.rds`.

- [ ] **Step 3: Commit**

```bash
git add problem-1-vht-model/scripts/02_fit_models.R
git commit -m "Fit secondary pass/fail logistic model benchmarked against paper"
```

---

## Task 7: Compute LOO-CV and prediction/confidence intervals

**Files:**
- Create: `problem-1-vht-model/scripts/03_validate_models.R`

**Interfaces:**
- Consumes: `problem-1-vht-model/models/continuous_model.rds` (from Task 5),
  `problem-1-vht-model/data/glass_data_clean.csv` (from Task 4).
- Produces: `problem-1-vht-model/models/continuous_model_validation.rds` — a list with
  elements `loo_r2` (numeric), `loo_rmse` (numeric), `intervals` (data frame with columns
  `glass_num, fit, ci_lwr, ci_upr, pi_lwr, pi_upr`, on the log scale) — consumed by
  `report.qmd`.

LOO-CV for an OLS fit is computed via the standard leverage-based shortcut
(`e_loo_i = residual_i / (1 - h_ii)`) rather than literally refitting the model 686 times.

- [ ] **Step 1: Write `03_validate_models.R`**

```r
# problem-1-vht-model/scripts/03_validate_models.R
fit_continuous <- readRDS("models/continuous_model.rds")
glass <- read.csv("data/glass_data_clean.csv", stringsAsFactors = FALSE)
glass$log_ra <- log(glass$ra_gm2d)

h <- hatvalues(fit_continuous)
loo_resid <- residuals(fit_continuous) / (1 - h)
loo_rmse <- sqrt(mean(loo_resid^2))
loo_r2 <- 1 - sum(loo_resid^2) / sum((glass$log_ra - mean(glass$log_ra))^2)

cat(sprintf("LOO-CV: R2 = %.4f, RMSE (log scale) = %.4f\n", loo_r2, loo_rmse))
stopifnot(loo_rmse > 0)

ci <- predict(fit_continuous, newdata = glass, interval = "confidence")
pi <- predict(fit_continuous, newdata = glass, interval = "prediction")
intervals <- data.frame(
  glass_num = glass$glass_num,
  fit = ci[, "fit"],
  ci_lwr = ci[, "lwr"], ci_upr = ci[, "upr"],
  pi_lwr = pi[, "lwr"], pi_upr = pi[, "upr"]
)
stopifnot(all(intervals$ci_lwr <= intervals$ci_upr),
          all(intervals$pi_lwr <= intervals$pi_upr),
          all(intervals$pi_lwr <= intervals$ci_lwr),
          all(intervals$pi_upr >= intervals$ci_upr))

saveRDS(list(loo_r2 = loo_r2, loo_rmse = loo_rmse, intervals = intervals),
        "models/continuous_model_validation.rds")
cat("Wrote models/continuous_model_validation.rds\n")
```

- [ ] **Step 2: Run it**

Run: `cd problem-1-vht-model && Rscript scripts/03_validate_models.R`

Expected: prints `LOO-CV: R2 = 0.xxxx, RMSE (log scale) = x.xxxx` (LOO R² should be close to
but slightly lower than the in-sample R² from Task 5 — if LOO R² is dramatically lower or
negative, the model is overfit and Task 5's interaction-term selection should be revisited).
The prediction-interval-contains-confidence-interval assertion passing confirms the
intervals aren't swapped.

- [ ] **Step 3: Commit**

```bash
git add problem-1-vht-model/scripts/03_validate_models.R
git commit -m "Add LOO-CV and confidence/prediction interval validation"
```

---

## Task 8: Record the paper's benchmark statistics

**Files:**
- Create: `problem-1-vht-model/data/paper_benchmarks.md`

**Interfaces:**
- Consumes: none.
- Produces: `problem-1-vht-model/data/paper_benchmarks.md` — read (as prose reference, not
  parsed) by whoever writes `report.qmd` in Task 9.

- [ ] **Step 1: Write the benchmarks file**

```markdown
# Paper Benchmarks — Vienna et al. (2020), Section 9.2

Source: "Glass Property-Composition Models for Support of Hanford WTP LAW Facility
Operation" (PNNL-30932, Rev. 1 / EWG-RPT-029, Rev. 1), Section 9.2 "Summary of LAW VHT
Modeling".

## Dataset

- 699 simulated and actual quenched LAW glasses have measured VHT alteration rate (`ra`).
- `ra` ranges 0.1 to 1529.1 g/m²/d across the dataset.
- Fail threshold: `ra` >= 50 g/m²/d (WTP contract Specification 2.2.2.17.3); 162 of the 699
  glasses exceed it.
- 13 glasses were excluded as compositional outliers, leaving 686 glasses used for the
  paper's own pass/fail modeling.

## Why the paper models pass/fail, not a continuous response

The paper states continuous `ra` (or `ln(ra)`) could not be predicted from composition with
low uncertainty and insignificant bias near the 50 g/m²/d threshold, across every model form
it tried (FLM, RLM, PQM, partial cubic, k-NN, SVM, local linear regression, Gaussian process
regression, ANN). It therefore adopted logistic regression on the binary pass/fail response
instead. **There is no continuous-model R²/RMSE reported anywhere in the paper** — this
harness's primary continuous model (Task 5) has no direct paper baseline to be judged
against for goodness-of-fit; only the secondary logistic model (Task 6) does.

## Reported pass/fail model performance

| Model | Terms | Accuracy | FPR | FNR |
|---|---|---|---|---|
| FLM | 20 | 86.30% | 13.26% | 15.19% |
| PQM (recommended) | 19 | 79.74% | 24.24% | 6.96% |

The recommended 19-term PQM combines Cl, Cr2O3, Fe2O3, and SO3 into the `Others` component
and adds three nonlinear terms (TiO2×ZrO2, Li2O², Li2O×Na2O), with a logit link and a
classification threshold of 0.19 (chosen to keep FNR under 10% while maximizing accuracy).
```

- [ ] **Step 2: Commit**

```bash
git add problem-1-vht-model/data/paper_benchmarks.md
git commit -m "Record paper's VHT modeling benchmarks for comparison"
```

---

## Task 9: Render the final report

**Files:**
- Create: `problem-1-vht-model/report.qmd`

**Interfaces:**
- Consumes: `models/continuous_model.rds`, `models/logistic_model.rds`,
  `models/continuous_model_validation.rds` (Tasks 5–7), `data/glass_data_clean.csv`
  (Task 4), `data/paper_benchmarks.md` (Task 8, read as reference while writing the prose
  sections below — not loaded programmatically).
- Produces: `problem-1-vht-model/report.html` (gitignored — regenerated by rendering, not
  committed) — the final deliverable a human reads.

- [ ] **Step 1: Write `report.qmd`**

```markdown
---
title: "Problem 1: VHT Predictive Model for LAW Glass Composition"
format: html
---

```{r setup}
#| include: false
oxide_cols <- c("Al2O3","B2O3","CaO","Cl","Cr2O3","F","Fe2O3","K2O","Li2O",
                 "MgO","Na2O","P2O5","SO3","SiO2","SnO2","TiO2","V2O5","ZnO",
                 "ZrO2","Others")
fit_continuous <- readRDS("models/continuous_model.rds")
fit_logistic <- readRDS("models/logistic_model.rds")
validation <- readRDS("models/continuous_model_validation.rds")
glass <- read.csv("data/glass_data_clean.csv", stringsAsFactors = FALSE)
```

## 1–2. Predictive equation

The primary model predicts `ln(VHT alteration rate, g/m²/d)` as a mixture-experiment
(Scheffé) polynomial over all 20 glass oxide components, with mass fractions summing to 1:

```{r equation}
#| echo: false
coefs <- coef(fit_continuous)
terms <- paste(sprintf("%.4f * %s", coefs, names(coefs)), collapse = " + ")
cat("ln(ra) =", terms)
```

## 3. Goodness-of-fit and validation statistics

```{r gof}
#| echo: false
r2 <- summary(fit_continuous)$r.squared
rmse <- sqrt(mean(residuals(fit_continuous)^2))
cat(sprintf("In-sample: R2 = %.4f, RMSE (log scale) = %.4f\n", r2, rmse))
cat(sprintf("Leave-one-out CV: R2 = %.4f, RMSE (log scale) = %.4f\n",
            validation$loo_r2, validation$loo_rmse))
```

## 4. Confidence and prediction intervals

```{r intervals}
#| echo: false
head(validation$intervals)
```

Confidence intervals bound the uncertainty in the mean predicted `ln(ra)` for a given
composition; prediction intervals (necessarily wider — verified in Task 7) bound where a
single new glass's measured `ln(ra)` is expected to fall, accounting for residual
model error as well as parameter uncertainty. Both are computed analytically from the
fitted linear model's standard errors (R's `predict.lm(..., interval=)`).

## 5. Per-component effects

```{r effects}
#| echo: false
summary(fit_continuous)$coefficients
```

Each oxide's coefficient is its estimated effect on `ln(ra)` per unit increase in that
component's mass fraction (holding the mixture constraint implicit, per standard Scheffé
mixture-model interpretation) — a negative coefficient means increasing that oxide's share
of the glass tends to lower (improve) the alteration rate.

## 6. Comparison to the source material

The source paper (Vienna et al. 2020, Section 9.2) does not report goodness-of-fit
statistics for a continuous VHT model — it found continuous prediction near the pass/fail
threshold too uncertain and modeled pass/fail via logistic regression instead. This
primary model's R²/RMSE above therefore has no direct "beat the source" baseline;
see `data/paper_benchmarks.md` for the full explanation.

What **is** directly comparable is the secondary pass/fail classifier fit in Task 6:

```{r logistic}
#| echo: false
pred_prob <- predict(fit_logistic, type = "response")
pred_class <- ifelse(pred_prob >= 0.5, 1, 0)
actual <- ifelse(glass$pass_fail == "F", 1, 0)
accuracy <- mean(pred_class == actual)
fpr <- mean(pred_class[actual == 0] == 1)
fnr <- mean(pred_class[actual == 1] == 0)
cat(sprintf("This harness's logistic model: accuracy = %.2f%%, FPR = %.2f%%, FNR = %.2f%%\n",
            accuracy * 100, fpr * 100, fnr * 100))
cat("Paper's 20-term FLM:              accuracy = 86.30%, FPR = 13.26%, FNR = 15.19%\n")
cat("Paper's 19-term PQM (recommended): accuracy = 79.74%, FPR = 24.24%, FNR = 6.96%\n")
```
```

- [ ] **Step 2: Render it**

Run: `cd problem-1-vht-model && quarto render report.qmd`

Expected: produces `report.html` with no errors. Open it and confirm all six numbered
sections have real numbers (not `NA` or errors) and the equation section lists all 20 oxide
components.

- [ ] **Step 3: Gitignore the rendered output and commit the source**

Add to `problem-1-vht-model/.gitignore`:
```
report.html
report_files/
```

```bash
git add problem-1-vht-model/report.qmd problem-1-vht-model/.gitignore
git commit -m "Add final VHT model report"
```
