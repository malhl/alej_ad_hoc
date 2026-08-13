# problem-1-vht-model/scripts/03_validate_models.R
fit_continuous <- readRDS("models/continuous_model.rds")
glass <- read.csv("data/glass_data_clean.csv", stringsAsFactors = FALSE)

# LOO-CV must be computed against the exact rows the model was fit on
# (Task 5 dropped the ~129 rows with no recorded ra_gm2d before fitting) so
# hatvalues()/residuals() line up 1:1 with the response used in the sum of
# squares below.
glass_fit <- glass[!is.na(glass$ra_gm2d), ]
glass_fit$log_ra <- log(glass_fit$ra_gm2d)

h <- hatvalues(fit_continuous)
loo_resid <- residuals(fit_continuous) / (1 - h)
loo_rmse <- sqrt(mean(loo_resid^2))
loo_r2 <- 1 - sum(loo_resid^2) / sum((glass_fit$log_ra - mean(glass_fit$log_ra))^2)

cat(sprintf("LOO-CV: R2 = %.4f, RMSE (log scale) = %.4f (on %d rows with a recorded rate)\n",
            loo_r2, loo_rmse, nrow(glass_fit)))
stopifnot(loo_rmse > 0)

# Intervals use the full 701-row set (not just glass_fit): predict() only
# needs the oxide predictor columns, which are never NA, so this also
# yields model-based rate predictions for the ~129 glasses with a pass/fail
# result but no measured rate.
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
