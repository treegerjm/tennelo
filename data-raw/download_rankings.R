# Downloads ATP ranking files into an ignored local directory.
#
#   Rscript data-raw/download_rankings.R [--overwrite]

source(file.path(dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE))),
                 "source.R"))
suppressMessages(pkgload::load_all(".", quiet = TRUE))

overwrite <- "--overwrite" %in% commandArgs(trailingOnly = TRUE)
announce_source()
cat("  Rankings and player table\n\n")

dir <- "data-raw/csv/rankings"
dir.create(dir, recursive = TRUE, showWarnings = FALSE)

wanted <- c(sprintf("atp_rankings_%s.csv", c("70s","80s","90s","00s","10s","20s","current")),
            "atp_players.csv")
got <- character(0); n_new <- 0L
for (f in wanted) {
  local <- file.path(dir, f)
  res <- tryCatch(download_one(f, local, overwrite), error = function(e) NULL)
  if (is.null(res)) { cat("  missing     : ", f, "\n", sep = ""); next }
  if (res$status == "downloaded") n_new <- n_new + 1L
  if (grepl("rankings", f)) verify_columns(local, REQUIRED_RANKING_COLS, f)
  got <- c(got, local)
}

cat("  files       : ", length(got), " (", n_new, " newly downloaded)\n", sep = "")
write_manifest(dir, got, source_commit(), "rankings")
cat("  done\n\n")
