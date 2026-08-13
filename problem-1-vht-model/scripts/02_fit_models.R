# problem-1-vht-model/scripts/02_fit_models.R
oxide_cols <- c("Al2O3","B2O3","CaO","Cl","Cr2O3","F","Fe2O3","K2O","Li2O",
                 "MgO","Na2O","P2O5","SO3","SiO2","SnO2","TiO2","V2O5","ZnO",
                 "ZrO2","Others")

glass <- read.csv("data/glass_data_clean.csv", stringsAsFactors = FALSE)

# ~129 of 701 rows have a recorded pass/fail result but no numeric VHT rate
# (real data, not a defect — see Task 4's Interfaces note). The continuous
# model needs a numeric response, so it fits on the subset that has one, kept
# as a separate `glass_fit` frame — `glass` itself stays the full 701 rows
# for Task 6's logistic model (appended below), which only needs pass_fail.
glass_fit <- glass[!is.na(glass$ra_gm2d), ]
glass_fit$log_ra <- log(glass_fit$ra_gm2d)
cat(sprintf("Fitting continuous model on %d of %d rows (have a recorded ra_gm2d)\n",
            nrow(glass_fit), nrow(glass)))

linear_formula <- as.formula(paste("log_ra ~", paste(oxide_cols, collapse = " + "), "- 1"))
fit_linear <- lm(linear_formula, data = glass_fit)

pair_terms <- combn(oxide_cols, 2, function(p) paste(p, collapse = ":"))
scope_formula <- as.formula(paste("~ . +", paste(pair_terms, collapse = " + ")))
add1_result <- add1(fit_linear, scope = scope_formula, test = "F")
sig_terms <- rownames(add1_result)[!is.na(add1_result[["Pr(>F)"]]) & add1_result[["Pr(>F)"]] < 0.05]
cat(sprintf("Significant interaction terms (p < 0.05): %s\n",
            if (length(sig_terms) == 0) "(none)" else paste(sig_terms, collapse = ", ")))

final_formula <- as.formula(paste("log_ra ~",
                                   paste(c(oxide_cols, sig_terms), collapse = " + "), "- 1"))
fit_continuous <- lm(final_formula, data = glass_fit)

r2 <- summary(fit_continuous)$r.squared
rmse <- sqrt(mean(residuals(fit_continuous)^2))
cat(sprintf("Continuous model: R2 = %.4f, RMSE (log scale) = %.4f, %d terms\n",
            r2, rmse, length(coef(fit_continuous))))

stopifnot(r2 > 0, r2 < 1, rmse > 0, all(oxide_cols %in% names(coef(fit_continuous))))

dir.create("models", showWarnings = FALSE)
saveRDS(fit_continuous, "models/continuous_model.rds")

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
