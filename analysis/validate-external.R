# Optional validation against an external Elo list.
#
#   Rscript analysis/validate-external.R path/to/reference.csv
#
# Deliberately outside the package tests and outside CI:
#
#  * it needs the licensed source data, downloaded locally by the user;
#  * the reference list is supplied by the user and never committed --
#    reference/ is in .gitignore, which keeps third-party rating data out of
#    this repository entirely;
#  * as a test it would fail CI whenever someone else's list was updated,
#    which is data maintenance, not a code defect.
#
# The reference file needs a player id column and a rating or rank column.
#
# Orientation, not a threshold: with pairing = "individual", a Spearman
# correlation above 0.90 and at least 15 shared players in the top 20 are
# consistent with a correct implementation. Published lists use their own K
# factors, their own inclusion rules and sometimes qualifying matches, so exact
# agreement is neither reachable nor the goal. A gap prompts an investigation;
# it does not by itself prove a bug -- and the usual causes, in order, are the
# sort order, the K factor, and which matches are in or out.

suppressMessages(pkgload::load_all(".", quiet = TRUE))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("Usage: Rscript analysis/validate-external.R <reference.csv>",
                            call. = FALSE)
ref_path <- args[1]
if (!file.exists(ref_path)) stop("Reference file not found: ", ref_path, call. = FALSE)

match_dir <- "data-raw/csv/matches"
files <- list.files(match_dir, pattern = "^atp_matches_[0-9]{4}\\.csv$", full.names = TRUE)
if (length(files) == 0L) {
  stop("No local match data. Run data-raw/download_matches.R first.", call. = FALSE)
}

manifest <- utils::read.csv(file.path(match_dir, "MANIFEST.csv"))
cat("\nData provenance\n")
cat("  source      : ", as.character(manifest$source[1]), "\n", sep = "")
cat("  commit      : ", as.character(manifest$source_commit[1]), "\n", sep = "")
cat("  retrieved   : ", as.character(manifest$retrieved[1]), "\n", sep = "")
cat("  files       : ", nrow(manifest), "\n\n", sep = "")

fit <- fit_elo(prepare_matches(load_matches(files)), pairing = "individual")
cat("Fitted through ", format(fit$as_of), ": ", fit$n_matches, " matches, ",
    fit$n_players, " players.\n\n", sep = "")

ref <- utils::read.csv(ref_path, stringsAsFactors = FALSE)
id_col <- intersect(c("player_id", "player", "id"), names(ref))[1]
va_col <- intersect(c("rating", "elo", "rank"), names(ref))[1]
if (is.na(id_col) || is.na(va_col)) {
  stop("Reference needs a player id column and a rating or rank column. Found: ",
       paste(names(ref), collapse = ", "), call. = FALSE)
}
ref$player_id <- as.character(ref[[id_col]])
ref$ref_rank  <- if (va_col == "rank") ref[[va_col]] else rank(-ref[[va_col]])

ours <- elo_leaderboard(fit, n = Inf, active_within = 365, min_matches = 20)
ours$our_rank <- seq_len(nrow(ours))
both <- merge(ours, ref[, c("player_id", "ref_rank")], by = "player_id")

if (nrow(both) < 3L) {
  cat("Only ", nrow(both), " shared players. Are the ids from the same space?\n", sep = "")
  quit(status = 0)
}

rho <- suppressWarnings(stats::cor(both$our_rank, both$ref_rank, method = "spearman"))
top20 <- length(intersect(utils::head(ours$player_id, 20),
                          ref$player_id[order(ref$ref_rank)][1:20]))

cat("Agreement\n")
cat(sprintf("  shared players : %d\n", nrow(both)))
cat(sprintf("  Spearman rho   : %.3f   %s\n", rho,
            if (rho > 0.90) "(consistent with the orientation value)"
            else "(below 0.90 -- worth investigating, not proof of a bug)"))
cat(sprintf("  top-20 overlap : %d of 20 %s\n", top20,
            if (top20 >= 15) "(consistent)" else "(below 15 -- worth investigating)"))

both$diff <- both$ref_rank - both$our_rank
cat("\nLargest disagreements\n")
worst <- both[order(-abs(both$diff)), ][seq_len(min(15, nrow(both))), ]
print(worst[, c("player_id", "our_rank", "ref_rank", "diff", "rating")],
      row.names = FALSE)

cat("\nThis is a plausibility and method check, not an oracle for correctness.\n\n")
