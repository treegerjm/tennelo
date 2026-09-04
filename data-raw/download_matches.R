# Downloads ATP singles match files into an ignored local directory.
#
#   Rscript data-raw/download_matches.R [from_year] [to_year] [--overwrite]
#
# Defaults to the full range, 1968 to the current year. Nothing here is
# redistributed: data-raw/csv/ is in .gitignore.

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))),
                 "source.R"))
suppressMessages(pkgload::load_all(".", quiet = TRUE))

args      <- commandArgs(trailingOnly = TRUE)
overwrite <- "--overwrite" %in% args
years     <- suppressWarnings(as.integer(args[!grepl("^--", args)]))
years     <- years[!is.na(years)]
from      <- if (length(years) >= 1L) years[1] else 1968L
to        <- if (length(years) >= 2L) years[2] else as.integer(format(Sys.Date(), "%Y"))

announce_source()
cat("  Matches ", from, "-", to, "\n\n", sep = "")

dir <- "data-raw/csv/matches"
dir.create(dir, recursive = TRUE, showWarnings = FALSE)

got <- character(0); n_new <- 0L
for (y in from:to) {
  local <- file.path(dir, sprintf("atp_matches_%d.csv", y))
  res <- tryCatch(download_one(sprintf("atp_matches_%d.csv", y), local, overwrite),
                  error = function(e) NULL)
  if (is.null(res)) next          # not every year exists upstream
  if (res$status == "downloaded") n_new <- n_new + 1L
  verify_columns(local, REQUIRED_MATCH_COLS, basename(local))
  got <- c(got, local)
}

cat("  files       : ", length(got), " (", n_new, " newly downloaded)\n", sep = "")
write_manifest(dir, got, source_commit(), "matches")
cat("  done\n\n")
