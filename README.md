# alej_ad_hoc

Exploring whether an LLM can act as a working statistician: given a real dataset and a modeling brief, can it choose an appropriate model class, fit it, validate it honestly (including catching its own overfitting), and design follow-up experiments — not just produce a plausible-looking equation. See [initial-problem-statement.md](initial-problem-statement.md) for the original brief.

The test case is Vienna et al. (2020), "Glass Property-Composition Models for Support of Hanford WTP LAW Facility Operation" — predicting Vapor Hydration Test (VHT) alteration rate from the 20-component oxide composition of low-activity waste (LAW) glasses.

## Status

**Problem 1 is complete**, on branch `worktree-problem-1-vht-harness` (not yet merged to `master`) under `problem-1-vht-model/`. Scripts `00`–`03` run the pipeline end to end; `report.qmd`/`report.html` is the final write-up.

**Problem 2 is in design** — four methodological decisions are locked (below), the construction approach is proposed but not yet implemented.

## Problem 1 — VHT model

**Data.** Tables A.2/A.3 of the source PDF, parsed to 701 glasses × 20 oxide mass fractions (`Al2O3`…`Others`, summing to 1 by construction) plus VHT alteration rate (`ra`) and pass/fail (`ra ≥ 50 g/m²/d` fails, per WTP contract spec). 572 of the 701 have a measured `ra`; the remaining 129 have a recorded pass/fail but no numeric rate — the source table's own "blank cells represent no data" caption, i.e. these are interval-censored (known to fall above or below the 50 g/m²/d threshold, exact value unmeasured), not missing-at-random noise.

**Primary model.** Because the 20 components are compositional (sum-to-one), the response (`log(ra)`) is fit as a Scheffé canonical mixture polynomial — 20 no-intercept linear blending terms, on the 572 glasses with a measured rate. Candidate pairwise interaction terms (of ~190 possible) were screened one at a time via `add1()` F-tests at p < 0.05; 20 were admitted, giving a 41-term model.

- In-sample: R² = 0.7832, RMSE (log scale) = 1.3446
- LOO-CV (analytic leverage shortcut, `e_i/(1-h_ii)`): R² = 0.2124, RMSE = 1.4704

The in-sample/LOO gap is the expected signature of one-at-a-time p < 0.05 screening across ~190 correlated candidate terms with no multiplicity correction — at α = 0.05 alone, chance admits several spurious terms before considering the compositional correlation structure. This is documented as a caveat in the report rather than corrected, per an explicit decision to keep the deliverable honest about the gap instead of silently reworking the model.

**Secondary model.** Logistic regression on pass/fail using all 701 glasses (doesn't require a numeric rate): 79.32% accuracy, 4.36% FPR, 80.67% FNR at the default 0.5 cutoff. The source paper's own models score 86.30/13.26/15.19 (20-term FLM) and 79.74/24.24/6.96 (19-term PQM, recommended, at a deliberately tuned 0.19 cutoff chosen to hold FNR down). Comparable accuracy, much worse FNR — most likely a threshold-calibration gap rather than a model-quality one, since no cutoff tuning was done here.

**No continuous baseline exists in the source.** Section 9.2 reports the paper tried FLM, RLM, PQM, partial cubic, k-NN, SVM, local linear regression, Gaussian process regression, and an ANN for continuous `ra`, and found none reliable enough near the pass/fail threshold — it adopted logistic regression on pass/fail instead. So the primary model's R²/RMSE above has no source figure to be judged against; only the secondary classifier does.

## Problem 2 — optimal glass formulations (in design)

Goal: augment the 572-glass design with 20 new realistic formulations that improve the VHT model's predictive performance, reporting D-, G-, and I-efficiency for the original and combined designs.

Locked decisions:

| Question | Decision |
|---|---|
| Base R only, or an existing package for the exchange algorithm? | `AlgDesign::optFederov` (Fedorov/coordinate exchange) — confirmed on CRAN |
| Optimize around Problem 1's 41-term model, or something simpler? | A plain 20-term linear mixture model — optimizing a design around an already-overfit model would compound the problem |
| Full simplex, or bounded to realistic compositions? | Bounded to each oxide's observed [min, max] over the 572-glass set |
| Which glasses are "the original set" for the efficiency baseline? | The same 572 with a measured `ra` — the population the continuous model was fit on |

Proposed construction (not yet implemented): generate a large candidate pool of realistic compositions within those bounds, use `optFederov(..., augment = TRUE)` to select the 20 points maximizing the combined design's D-efficiency under the linear model, then compute G- and I-efficiency directly from the design's prediction-variance function over the candidate pool for both the original-alone and combined sets.

## Next steps

The concrete sequence, in order:

1. **Sign off on the Problem 2 construction approach** (D-optimal augmentation via `optFederov`, above).
2. Write it up as a design spec (`docs/superpowers/specs/`) and an implementation plan (`docs/superpowers/plans/`), mirroring how Problem 1 was scoped.
3. Build the candidate-generation and augmentation script, producing the 20 new formulations, the D/G/I-efficiency comparison (original vs. combined), and the per-point rationale (which high-variance regions each new glass fills).
4. Fold the Problem 1 branch (`worktree-problem-1-vht-harness`) back into `master` — including syncing `master`'s copy of the Problem 1 plan doc, which still predates the interval-censoring bugfix — so both problems live on one branch.
5. Revisit the "Open questions" below as time allows; none of them block Problem 2 from starting, but the term-selection and threshold-calibration items would change Problem 1's reported numbers if acted on.

## Open questions

- **Term selection.** Replace one-at-a-time `add1()` screening with something that controls the multiple-comparisons problem: Bonferroni/FDR-adjusted screening, a LASSO/elastic-net fit on a constrained (e.g. ilr-transformed) basis that respects the sum-to-one constraint, or LOO/nested-CV-driven stepwise selection that optimizes predictive fit directly instead of in-sample F-tests.
- **Is a continuous `ra` model the right target at all?** The source paper explicitly rejected continuous prediction near the threshold across nine model families. Worth considering whether the headline deliverable should be the threshold classifier (matching the paper's own conclusion), with the continuous model repositioned as secondary/exploratory.
- **Classification threshold.** Select the operating point from the ROC or precision-recall curve — mirroring the paper's deliberate 0.19 cutoff — instead of the default 0.5, and report AUC alongside accuracy/FPR/FNR at the chosen threshold.
- **The 129 rate-censored glasses.** Currently dropped entirely from the continuous model. Since "pass" vs. "fail" is exactly interval censoring around the 50 g/m²/d threshold, a censored-regression (Tobit-style) or interval-censored likelihood could recover information from ~18% of the labeled data that's presently discarded.
- **Compositional geometry.** The no-intercept Scheffé parameterization sidesteps the estimability problem from sum-to-one collinearity but not the interpretability/correlation issues inherent to compositional data. An isometric or additive log-ratio (ilr/alr) transform is worth comparing as an alternative basis — relevant to both the term-selection question above and to Problem 2's design criteria, which currently assume the raw Scheffé basis.
- **Model-dependence of the Problem 2 design.** D-optimality is defined relative to a specific model; if term selection is revisited per the point above, today's "optimal" 20 points may stop being optimal. Worth deciding whether to hedge with a model-independent space-filling criterion (e.g. maximin coverage) alongside the D/G/I-optimal picks, or accept the model-dependence as a documented limitation.
- **Interval honesty.** The confidence/prediction intervals in the Problem 1 report are the classical analytic OLS intervals (`predict.lm(interval=)`), which assume correct model specification. Given the demonstrated overfitting, they understate true uncertainty — LOO- or bootstrap-based intervals are the more defensible choice once term selection is revisited.
