# Prologue

We're trying to find descriptive models of the y = f(x) type.

A simple one: Can the LLM create a linear model expressing the relationship between x and y?

| X | Y |
|---|---|
| x1 | y1 |
| x2 | y2 |
| x3 | y3 |
| x4 | y4 |
| ... | ... |
| xn | yn |

Actual numeric values will be provided.

- Is it an equation like y = mx + b, or is it a black box like xi → [model] → yi?
- Can I ask for a nonlinear model?
- Can the model provide predictions along with uncertainty measures like confidence and prediction intervals?
- Can the output include justification for how predictions and uncertainties are estimated?

# Problem 1

Assuming it is possible to solve the problem in the prologue, can the LLM access "Glass Property-Composition Models for Support of Hanford WTP LAW Facility Operation" by Vienna et al. (2020) (available only on the web) and create:

1. A predictive model relating VHT to the composition of the glass using all glass components. The model may include significant interactions among glass components.
   - The model does not have to be linear, but it does have to include all glass components.
2. Can the LLM provide an equation as output?
3. The output shall include goodness-of-fit measures like R-squared, RMSE, and validation statistics like leave-one-out.
4. The LLM shall provide confidence and prediction intervals that are reasonable and meaningful.
5. Provide estimates of the effect of each glass component on VHT values.
6. Goodness-of-fit statistics for the model under (1) shall be equal to or better than those in the source material.

# Problem 2

Let's stick to the data in Problem 1. Request the LLM to design twenty additional glass formulations that will, if produced, maximize the predictive overall performance of the VHT model. The additional glass formulations:

1. Shall be realistic — the sum of all components for each glass shall equal 1 (one).
2. Shall improve model performance by optimally filling the space available (can probably phrase this better), minimize variance in the space spanned by the current set of glasses (there are actual mathematical criteria, if it helps).
3. The output must include reasoning explaining why and how the new design points (glasses) were selected.
4. Provide statistics such as G-efficiency, D-efficiency, and I-efficiency for the original set of glasses as well as for the combined set.
