REQUIRED_RANKING_COLS <- c("ranking_date", "rank", "player")

#' Read an ATP ranking file
#'
#' @param path One or more CSV paths, which are read and stacked.
#' @return A data frame with at least `ranking_date`, `rank` and `player`.
#' @export
load_rankings <- function(path) {
  if (!is.character(path) || length(path) == 0L) {
    abort_input("`path` must be one or more file paths.", "tennelo_error_type", "path")
  }
  missing_files <- path[!file.exists(path)]
  if (length(missing_files) > 0L) {
    abort_input(paste0("File(s) not found: ", paste(missing_files, collapse = ", "), "."),
                "tennelo_error_value", "path")
  }
  parts <- lapply(path, function(p) {
    raw <- utils::read.csv(p, stringsAsFactors = FALSE, colClasses = "character")
    missing_cols <- setdiff(REQUIRED_RANKING_COLS, names(raw))
    if (length(missing_cols) > 0L) {
      abort_input(paste0("`", p, "` is missing required column(s): ",
                         paste(missing_cols, collapse = ", "), "."),
                  "tennelo_error_schema", "path")
    }
    raw
  })
  out <- do.call(rbind, lapply(parts, function(x) {
    keep <- intersect(c(REQUIRED_RANKING_COLS, "points"), names(x))
    x[, keep, drop = FALSE]
  }))
  rownames(out) <- NULL
  out
}

#' Validate and tidy a ranking table
#'
#' @param raw A data frame from [load_rankings()].
#' @return A data frame with a parsed `ranking_date`, integer `rank` and
#'   character `player`, carrying an exclusion report.
#' @export
prepare_rankings <- function(raw) {
  if (!is.data.frame(raw)) {
    abort_input("`raw` must be a data frame.", "tennelo_error_type", "raw")
  }
  missing_cols <- setdiff(REQUIRED_RANKING_COLS, names(raw))
  if (length(missing_cols) > 0L) {
    abort_input(paste0("`raw` is missing required column(s): ",
                       paste(missing_cols, collapse = ", "), "."),
                "tennelo_error_schema", "raw")
  }
  n_input <- nrow(raw)
  dropped <- c(missing_date = 0L, bad_rank = 0L, missing_player = 0L, duplicate = 0L)

  d <- raw
  parsed <- as.Date(as.character(d$ranking_date), format = "%Y%m%d")
  dropped[["missing_date"]] <- sum(is.na(parsed))
  d <- d[!is.na(parsed), , drop = FALSE]; d$ranking_date <- parsed[!is.na(parsed)]

  rk <- suppressWarnings(as.integer(d$rank))
  dropped[["bad_rank"]] <- sum(is.na(rk) | rk < 1L)
  ok <- !is.na(rk) & rk >= 1L
  d <- d[ok, , drop = FALSE]; d$rank <- rk[ok]

  # Player ids are the identity key. A ranking row without one cannot be joined
  # to a match record, and joining on names is not an option.
  pl <- trimws(as.character(d$player))
  bad <- is.na(pl) | pl == ""
  dropped[["missing_player"]] <- sum(bad)
  d <- d[!bad, , drop = FALSE]; d$player <- pl[!bad]

  key <- paste(d$ranking_date, d$player, sep = "\r")
  dup <- duplicated(key)
  dropped[["duplicate"]] <- sum(dup)
  d <- d[!dup, , drop = FALSE]

  if ("points" %in% names(d)) d$points <- suppressWarnings(as.numeric(d$points))
  d <- d[order(d$ranking_date, d$rank), , drop = FALSE]
  rownames(d) <- NULL

  attr(d, "tennelo_report") <- structure(
    list(n_input = n_input, n_kept = nrow(d), dropped = dropped,
         levels = NA_character_, retirements = NA_character_),
    class = "tennelo_report"
  )
  class(d) <- c("tennelo_rankings", "data.frame")
  d
}

#' Compare Elo with the official ATP ranking
#'
#' Takes the most recent ATP ranking that is not *after* `as_of`, joins it to
#' the Elo ratings on player id, and reports where the two disagree.
#'
#' @param fit An object from [fit_elo()].
#' @param rankings A data frame from [prepare_rankings()].
#' @param as_of The Elo cut-off date. `NULL` uses the fit's last date.
#' @param active_within,min_matches Passed to [elo_leaderboard()] to decide who
#'   is eligible for comparison.
#' @param n Size of the top-n overlap statistic.
#'
#' @return An object of class `tennelo_comparison`.
#'
#' @details
#' The comparison is only called same-day when the two dates actually match;
#' otherwise the ranking date used is reported alongside the gap in days.
#' Nothing about the expected result is hard-wired: no particular player is
#' assumed to lead, and no top-n overlap is treated as proof of correctness.
#' @export
compare_rankings <- function(fit, rankings, as_of = NULL,
                             active_within = 365, min_matches = 20, n = 20) {
  fit_or_stop(fit)
  if (!is.data.frame(rankings) || !all(REQUIRED_RANKING_COLS %in% names(rankings))) {
    abort_input("`rankings` must come from prepare_rankings().",
                "tennelo_error_schema", "rankings")
  }
  when <- resolve_as_of(fit, as_of)

  candidates <- rankings$ranking_date[rankings$ranking_date <= when]
  if (length(candidates) == 0L) {
    abort_input(paste0("No ATP ranking on or before ", when, "."),
                "tennelo_error_value", "rankings")
  }
  atp_date <- max(candidates)
  atp <- rankings[rankings$ranking_date == atp_date, , drop = FALSE]

  elo <- elo_leaderboard(fit, n = Inf, as_of = when,
                         active_within = active_within,
                         min_matches = min_matches)
  if (nrow(elo) == 0L) {
    abort_input("No player meets the activity and match thresholds.",
                "tennelo_error_value", "min_matches")
  }
  elo$elo_rank <- seq_len(nrow(elo))
  # Drop the leaderboard's own `rank` before merging. Keeping it would collide
  # with the ATP `rank` column, and renaming the resulting rank.x back to
  # elo_rank would produce two columns of that name -- which data frame
  # printing hides but tidy evaluation does not.
  elo$rank <- NULL

  joined <- merge(elo, atp[, c("player", "rank")],
                  by.x = "player_id", by.y = "player", all = FALSE)
  names(joined)[names(joined) == "rank"] <- "atp_rank"
  joined$rank_diff <- joined$atp_rank - joined$elo_rank
  joined <- joined[order(joined$elo_rank), , drop = FALSE]
  rownames(joined) <- NULL

  rho <- if (nrow(joined) > 2L) {
    suppressWarnings(stats::cor(joined$elo_rank, joined$atp_rank, method = "spearman"))
  } else NA_real_

  top_elo <- utils::head(elo$player_id, n)
  top_atp <- atp$player[order(atp$rank)][seq_len(min(n, nrow(atp)))]

  structure(list(
    elo_date   = when,
    atp_date   = atp_date,
    same_day   = identical(when, atp_date),
    gap_days   = as.numeric(when - atp_date),
    n_elo      = nrow(elo),
    n_atp      = nrow(atp),
    n_matched  = nrow(joined),
    pct_matched = if (nrow(elo) > 0) nrow(joined) / nrow(elo) else NA_real_,
    spearman   = rho,
    top_n      = n,
    top_n_overlap = length(intersect(top_elo, top_atp)),
    comparison = joined,
    unmatched_elo = setdiff(elo$player_id, joined$player_id),
    unmatched_atp = setdiff(atp$player, joined$player_id),
    config = list(active_within = active_within, min_matches = min_matches)
  ), class = "tennelo_comparison")
}

#' @export
print.tennelo_comparison <- function(x, ...) {
  cat("<tennelo_comparison>\n")
  cat(sprintf("  Elo as of      : %s\n", x$elo_date))
  cat(sprintf("  ATP ranking    : %s%s\n", x$atp_date,
              if (x$same_day) " (same day)" else sprintf(" (%.0f days earlier)", x$gap_days)))
  cat(sprintf("  eligible / matched : %d / %d (%.1f%%)\n",
              x$n_elo, x$n_matched, 100 * x$pct_matched))
  cat(sprintf("  Spearman rho   : %s\n",
              if (is.na(x$spearman)) "n/a" else sprintf("%.3f", x$spearman)))
  cat(sprintf("  top-%d overlap  : %d of %d\n", x$top_n, x$top_n_overlap, x$top_n))
  if (length(x$unmatched_elo) > 0L) {
    cat(sprintf("  unmatched Elo players : %d\n", length(x$unmatched_elo)))
  }
  invisible(x)
}
