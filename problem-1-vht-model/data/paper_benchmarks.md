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
