# alej_ad_hoc

Exploring whether an LLM can act as a statistical modeling tool — building descriptive/predictive models from data, and evaluating how well it explains and validates them.

## Overview

The core question: given a set of `x` (inputs) and `y` (outputs), can an LLM produce a model of the form `y = f(x)`, whether that's a simple linear equation or a more complex black-box model? Beyond just producing a model, can it:

- Explain whether the relationship is linear or nonlinear
- Provide uncertainty estimates (confidence and prediction intervals)
- Justify how those predictions and uncertainties were derived

See [initial-problem-statement.md](initial-problem-statement.md) for the full prologue and problem definitions.

## Problem 1 — Glass VHT Model

Using the glass composition data from "Glass Property-Composition Models for Support of Hanford WTP LAW Facility Operation" (Vienna et al., 2020), can the LLM build a predictive model relating VHT (Vapor Hydration Test result) to glass composition?

Requirements:
- Must include all glass components, and may include significant interactions among them
- Doesn't need to be linear, but must use every component
- Should output an explicit equation
- Must report goodness-of-fit (R-squared, RMSE) and validation statistics (e.g. leave-one-out)
- Must provide meaningful confidence and prediction intervals
- Must estimate the effect of each glass component on VHT
- Goodness-of-fit should match or beat the statistics reported in the source paper

## Problem 2 — Optimal Glass Formulation Design

Using the same dataset, can the LLM design twenty additional glass formulations that improve the VHT model's predictive performance?

Requirements:
- Each formulation must be realistic — component fractions must sum to 1
- New points should optimally fill the design space and minimize variance (per standard design-of-experiments criteria)
- The LLM must explain the reasoning behind each selected design point
- Must report G-efficiency, D-efficiency, and I-efficiency for both the original and combined (original + new) sets of glasses
