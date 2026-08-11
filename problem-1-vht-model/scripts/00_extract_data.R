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

# pdftotext emits ISO-8859 (not UTF-8) bytes for this PDF — confirmed via
# `file data/raw/vienna2020.txt` reporting "ISO-8859 text" — so read as
# latin1 to avoid corrupting/erroring on those bytes.
lines <- readLines(txt_path, warn = FALSE, encoding = "latin1")
lines <- gsub("\f", "", lines, fixed = TRUE)
stopifnot(
  any(grepl("^Table A\\.2\\. Normalized Compositions", lines)),
  any(grepl("^Table A\\.3\\. Properties of LAW Glasses", lines))
)
cat(sprintf("Extracted %d lines to %s\n", length(lines), txt_path))

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
  # A real Table A.3 row starts with an alphanumeric Glass ID (e.g. "LAWA49").
  # When a Glass ID is long enough to wrap, pdftotext emits the wrapped row's
  # numeric columns on their own unindented line, which still matches the
  # leading "<int>\s" glass_num check above but has a *numeric* first token
  # (a stray data value, not a Glass ID) -- reject those to avoid mistaking
  # them for a fresh, colliding glass_num row.
  if (length(toks) < 1 || !grepl("[A-Za-z]", toks[1])) return(NULL)
  # Column position of ra_gm2d/pass_fail is NOT fixed: interior blank cells
  # are sometimes rendered as "-" (a token) and sometimes dropped entirely
  # (no token at all) by pdftotext, so the token index of ra_gm2d/pass_fail
  # shifts row to row. What's reliable is the *shape*: pass_fail is always a
  # standalone P or F token immediately preceded by the ra_gm2d cell (the
  # BS/SR/Bub/MT/3TS columns after it are never single P/F letters), so
  # locate that pair positionally within the row instead of by token index.
  # The ra_gm2d cell itself is frequently "-" (the table caption states
  # "Blank cells represent no data") even when pass_fail is present -- e.g.
  # glass 12, LAWA46, has pass_fail "P" but no numeric VHT rate. Those rows
  # are still valid VHT rows (matching the paper's count of glasses "with
  # pass/fail VHT values"), so ra_gm2d becomes NA rather than dropping the
  # row.
  m <- regmatches(rest, regexpr("\\S+\\s{2,}[PF](\\s{2,}|$)", rest))
  if (length(m) == 0 || !nzchar(m)) return(NULL)
  parts <- strsplit(trimws(m), "\\s+")[[1]]
  ra_val <- suppressWarnings(as.numeric(sub("\\*$", "", parts[1])))
  pf_val <- parts[2]
  if (!(pf_val %in% c("P", "F"))) return(NULL)
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
