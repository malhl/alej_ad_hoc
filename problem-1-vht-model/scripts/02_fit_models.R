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
