# Required columns. tourney_id is not optional: tourney_date is identical for
# every match of a tournament and match_num only runs within one, so without it
# the order of concurrently running tournaments is ambiguous.
REQUIRED_MATCH_COLS <- c(
  "tourney_id", "tourney_date", "tourney_name", "tourney_level",
  "match_num", "surface", "round", "best_of", "score",
  "winner_id", "winner_name", "loser_id", "loser_name"
)

# Round order within a tournament. Measured against the whole source, 1968-2026:
# exactly these ten codes occur at tour level, and no others.
#
# BR (the third-place play-off) sits level with F. Qualifying rounds do not
# appear -- they live in the qual_chall files, which this package does not read.
#
# ER is the "early round" of the round-robin format the ATP trialled in 2007 at
# four 250-level events (Adelaide, Buenos Aires, Delray Beach, Las Vegas). It is
# played BEFORE the group stage: in all four events every one of the eight ER
# winners went on to appear in RR. 32 rows in total, and the only reason the
# rank list is not simply the familiar knockout ladder.
ROUND_RANK <- c(
  R128 = 1L, R64 = 2L, R32 = 3L, R16 = 4L, ER = 5L,
  RR   = 6L, QF  = 7L, SF  = 8L, F = 9L, BR = 9L
)

# Tour level. No Davis Cup (D): dead rubbers, home choice of surface and
# substitute line-ups distort ratings. O is the Olympics, which is included --
# a full field of tour players, and the Davis Cup objection does not apply.
TOUR_LEVELS <- c("G", "M", "A", "F", "O")

#' Read a match file
#'
#' Reads one ATP match CSV and checks that it has the columns the rating engine
#' needs. No filtering, no reordering, no type coercion beyond what is required
#' to validate: use [prepare_matches()] for that.
#'
#' @param path Path to a CSV file, or a character vector of paths, which are
#'   read and stacked.
#'
#' @return A data frame with at least the required columns.
#' @export
load_matches <- function(path) {
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
    missing_cols <- setdiff(REQUIRED_MATCH_COLS, names(raw))
    if (length(missing_cols) > 0L) {
      abort_input(
        paste0("`", p, "` is missing required column(s): ",
               paste(missing_cols, collapse = ", "), "."),
        "tennelo_error_schema", "path"
      )
    }
    raw[, REQUIRED_MATCH_COLS, drop = FALSE]
  })

  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

# Walkovers are not played matches. Retirements are: the match happened and a
# winner is on record. Normalise before matching so that spacing and case do
# not decide the outcome.
is_walkover <- function(score) {
  s <- toupper(trimws(ifelse(is.na(score), "", score)))
  s <- gsub("[[:space:]]+", " ", s)
  s == "" | grepl("W/O|WO$|^WO |WALKOVER|DEF\\.?$|^DEF\\.? ", s)
}

is_retirement <- function(score) {
  s <- toupper(trimws(ifelse(is.na(score), "", score)))
  grepl("RET", s)
}

#' Validate, filter and order a match table
#'
#' Turns a raw match table into the deterministic, fully ordered input the
#' rating engine consumes. Every row removed is counted and reported; nothing
#' is dropped silently.
#'
#' @param raw A data frame from [load_matches()].
#' @param levels Tournament levels to keep. Defaults to tour level including
#'   the Olympics, excluding Davis Cup.
#' @param retirements `"include"` (default) counts retirements as played
#'   matches; `"exclude"` drops them, for sensitivity analysis.
#'
#' @return A data frame ordered by the full sort key, carrying an exclusion
#'   report in the `"tennelo_report"` attribute. Retrieve it with
#'   [exclusion_report()].
#'
#' @details
#' ## Order, and its limit
#'
#' `tourney_date` is the start date of the *tournament*, not of the match. The
#' chronology is therefore correct tournament by tournament, not day by day:
#' within one week a match played earlier can sort after one played later. That
#' is a property of the source and is documented rather than defined away.
#'
#' Rows are ordered by `tourney_date`, `tourney_id`, round, `match_num`,
#' `winner_id`, `loser_id`. The trailing player ids are deterministic
#' tie-breakers, not a claim about the true order of play; without them the
#' guarantee that re-ordering the input leaves the result unchanged does not
#' hold when `match_num` repeats.
#'
#' @export
prepare_matches <- function(raw,
                            levels = TOUR_LEVELS,
                            retirements = c("include", "exclude")) {
  if (!is.data.frame(raw)) {
    abort_input("`raw` must be a data frame.", "tennelo_error_type", "raw")
  }
  missing_cols <- setdiff(REQUIRED_MATCH_COLS, names(raw))
  if (length(missing_cols) > 0L) {
    abort_input(paste0("`raw` is missing required column(s): ",
                       paste(missing_cols, collapse = ", "), "."),
                "tennelo_error_schema", "raw")
  }
  retirements <- match.arg(retirements)
  if (!is.character(levels) || length(levels) == 0L) {
    abort_input("`levels` must be a non-empty character vector.",
                "tennelo_error_type", "levels")
  }

  d <- raw[, REQUIRED_MATCH_COLS, drop = FALSE]
  n_input <- nrow(d)
  drop_counts <- c(
    level = 0L, walkover = 0L, retirement = 0L,
    missing_player = 0L, missing_date = 0L,
    bad_match_num = 0L, duplicate = 0L
  )

  keep_and_count <- function(d, keep, reason) {
    drop_counts[[reason]] <<- drop_counts[[reason]] + sum(!keep)
    d[keep, , drop = FALSE]
  }

  # Tournament level.
  d <- keep_and_count(d, d$tourney_level %in% levels, "level")

  # Walkovers, then retirements if excluded.
  d <- keep_and_count(d, !is_walkover(d$score), "walkover")
  if (retirements == "exclude") {
    d <- keep_and_count(d, !is_retirement(d$score), "retirement")
  }

  # Player identity. Names are display only and never used to join, so a row
  # without two resolvable ids cannot be rated.
  ok_ids <- !is.na(d$winner_id) & !is.na(d$loser_id) &
    trimws(d$winner_id) != "" & trimws(d$loser_id) != "" &
    trimws(d$winner_id) != trimws(d$loser_id)
  d <- keep_and_count(d, ok_ids, "missing_player")

  # Dates: source format is YYYYMMDD.
  parsed_date <- as.Date(as.character(d$tourney_date), format = "%Y%m%d")
  d <- keep_and_count(d, !is.na(parsed_date), "missing_date")
  d$tourney_date <- parsed_date[!is.na(parsed_date)]

  # match_num must be numeric to act as a tie-breaker.
  mn <- suppressWarnings(as.numeric(d$match_num))
  d <- keep_and_count(d, !is.na(mn), "bad_match_num")
  d$match_num <- mn[!is.na(mn)]

  # Round codes. An unknown code is an error: sorting it alphabetically would
  # silently put a final before a quarter-final.
  unknown <- setdiff(unique(d$round), names(ROUND_RANK))
  if (length(unknown) > 0L) {
    abort_input(
      paste0("Unknown round code(s): ", paste(sort(unknown), collapse = ", "),
             ". Add them to ROUND_RANK before rating these matches."),
      "tennelo_error_round", "raw"
    )
  }
  d$round_rank <- unname(ROUND_RANK[d$round])

  # Duplicates. A key repeated with an identical row is a mirroring artefact
  # and is dropped; a key repeated with a different result is a data conflict
  # this package will not silently pick a side in.
  key <- paste(d$tourney_id, d$match_num, sep = "\r")
  if (anyDuplicated(key)) {
    dup_keys <- unique(key[duplicated(key)])
    for (k in dup_keys) {
      rows <- d[key == k, , drop = FALSE]
      if (nrow(unique(rows)) > 1L) {
        abort_input(
          paste0("Conflicting duplicate for tourney_id/match_num '",
                 sub("\r", "/", k), "': same match, different data."),
          "tennelo_error_duplicate", "raw"
        )
      }
    }
    keep <- !duplicated(d)
    d <- keep_and_count(d, keep, "duplicate")
    key <- key[keep]
  }

  # The full sort key. Player ids at the end make the order total, so that
  # re-ordering the input rows cannot change the result.
  d <- d[order(d$tourney_date, d$tourney_id, d$round_rank,
               d$match_num, d$winner_id, d$loser_id), , drop = FALSE]
  rownames(d) <- NULL

  attr(d, "tennelo_report") <- structure(
    list(
      n_input   = n_input,
      n_kept    = nrow(d),
      dropped   = drop_counts,
      levels    = levels,
      retirements = retirements
    ),
    class = "tennelo_report"
  )
  class(d) <- c("tennelo_matches", "data.frame")
  d
}

#' Exclusion report
#'
#' Every row removed during preparation, counted by reason. The counts and the
#' kept rows always add up to the input row count.
#'
#' @param x A prepared object carrying a report.
#' @return An object of class `tennelo_report`.
#' @export
exclusion_report <- function(x) {
  r <- attr(x, "tennelo_report")
  if (is.null(r) && inherits(x, "tennelo_fit")) r <- x$report
  if (is.null(r)) {
    abort_input("No exclusion report found on this object.",
                "tennelo_error_type", "x")
  }
  r
}

#' @export
print.tennelo_report <- function(x, ...) {
  cat("Exclusion report\n")
  cat(sprintf("  input rows : %d\n", x$n_input))
  cat(sprintf("  kept       : %d\n", x$n_kept))
  dropped <- x$dropped[x$dropped > 0]
  if (length(dropped) == 0L) {
    cat("  dropped    : none\n")
  } else {
    cat("  dropped    :\n")
    for (nm in names(dropped)) cat(sprintf("    %-15s %d\n", nm, dropped[[nm]]))
  }
  stopifnot(x$n_kept + sum(x$dropped) == x$n_input)
  cat(sprintf("  reconciles : %d + %d = %d\n",
              x$n_kept, sum(x$dropped), x$n_input))
  invisible(x)
}
