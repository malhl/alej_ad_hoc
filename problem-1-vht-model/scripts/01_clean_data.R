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

check_cols <- c(oxide_cols, "pass_fail")
if (anyNA(glass[check_cols])) {
  stop("Missing values found in composition or pass_fail columns")
}
cat(sprintf("%d of %d rows have NA ra_gm2d (pass/fail recorded, rate not) — expected, kept\n",
            sum(is.na(glass$ra_gm2d)), nrow(glass)))

has_rate <- !is.na(glass$ra_gm2d)
out_of_range <- has_rate & (glass$ra_gm2d < 0.1 | glass$ra_gm2d > 1529.1)
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
