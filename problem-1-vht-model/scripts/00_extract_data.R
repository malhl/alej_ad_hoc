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
