#' Fit an Elo model to a prepared match table
#'
#' Runs the rating engine once over the matches and returns everything needed
#' to answer questions afterwards: current ratings, match counts, the full
#' rating history and the exclusion report. Downstream functions read this
#' object instead of replaying the data, so a chart of five players costs one
#' pass, not five.
#'
#' @param matches A data frame from [prepare_matches()].
#' @param surface `NULL` (default) rates every match. A surface name --
#'   `"Hard"`, `"Clay"`, `"Grass"`, `"Carpet"` -- fits an independent model
#'   from that surface alone, with its own experience counter.
#' @param initial Starting rating for a player's first match.
#' @param pairing How the two K-factors combine. See Details.
#' @param k_start,offset,shape K-factor parameters, passed to [elo_k()].
#'
#' @return An object of class `tennelo_fit`.
#'
#' @details
#' ## Pairing
#'
#' `"individual"` (the default) moves each player by their own K-factor. This
#' is the convention of published tennis Elo lists and lets an established
#' rating resist a single result. The rating pool then drifts, by exactly
#' `(k_a - k_b) * delta` per match.
#'
#' `"symmetric"` gives both players `elo_match_k(k_a, k_b)`, so transfers are
#' equal and opposite and the pool keeps its total. The cost is that a
#' veteran's K is pulled upward merely because the opponent is inexperienced --
#' which happens most often to exactly the top players a leaderboard is about.
#'
#' ## Surfaces
#'
#' Surface models are independent, not adjustments to the overall model, and
#' they are not blended. Matches with no recorded surface are rated in the
#' overall model and excluded from surface models.
#'
#' @export
fit_elo <- function(matches,
                    surface = NULL,
                    initial = 1500,
                    pairing = c("individual", "symmetric"),
                    k_start = 250, offset = 5, shape = 0.4) {
  if (!is.data.frame(matches)) {
    abort_input("`matches` must be a data frame from prepare_matches().",
                "tennelo_error_type", "matches")
  }
  needed <- c("tourney_id", "tourney_date", "round_rank", "match_num",
              "surface", "winner_id", "loser_id")
  missing_cols <- setdiff(needed, names(matches))
  if (length(missing_cols) > 0L) {
    abort_input(
      paste0("`matches` is missing ", paste(missing_cols, collapse = ", "),
             ". Run prepare_matches() first."),
      "tennelo_error_schema", "matches"
    )
  }
  pairing <- match.arg(pairing)
  check_scalar(initial, "initial")
  check_scalar(k_start, "k_start", min = 0, exclusive = TRUE)
  check_scalar(offset, "offset", min = 0, exclusive = TRUE)
  check_scalar(shape, "shape", min = 0)

  base_report <- attr(matches, "tennelo_report")
  n_before_surface <- nrow(matches)
  dropped_surface <- 0L

  if (!is.null(surface)) {
    if (!is.character(surface) || length(surface) != 1L) {
      abort_input("`surface` must be a single surface name or NULL.",
                  "tennelo_error_type", "surface")
    }
    keep <- !is.na(matches$surface) & matches$surface == surface
    dropped_surface <- sum(!keep)
    matches <- matches[keep, , drop = FALSE]
    if (nrow(matches) == 0L) {
      abort_input(paste0("No matches on surface '", surface, "'."),
                  "tennelo_error_value", "surface")
    }
  }

  n <- nrow(matches)
  w_id <- as.character(matches$winner_id)
  l_id <- as.character(matches$loser_id)
  players <- sort(unique(c(w_id, l_id)))
  wi <- match(w_id, players)
  li <- match(l_id, players)

  rating <- rep(initial, length(players))
  played <- rep(0L, length(players))

  # History: one row per player per match, so filtering by player is a subset
  # rather than a re-run.
  h_n <- 2L * n
  h_match  <- integer(h_n); h_player <- integer(h_n)
  h_before <- numeric(h_n); h_after  <- numeric(h_n)
  h_played <- integer(h_n); h_won    <- logical(h_n)
  h_opp    <- integer(h_n)

  for (i in seq_len(n)) {
    a <- wi[i]; b <- li[i]
    ra <- rating[a]; rb <- rating[b]
    ka <- k_start / (played[a] + offset)^shape
    kb <- k_start / (played[b] + offset)^shape
    if (pairing == "symmetric") {
      km <- if (ka == kb) ka else sqrt(ka * kb)
      ka <- kb <- km
    }
    d <- 1 - 1 / (1 + 10^((rb - ra) / 400))
    na_ <- ra + ka * d
    nb_ <- rb - kb * d

    j <- 2L * i - 1L
    h_match[j]  <- i;  h_player[j] <- a; h_before[j] <- ra
    h_after[j]  <- na_; h_won[j]   <- TRUE;  h_opp[j] <- b
    h_match[j + 1L] <- i; h_player[j + 1L] <- b; h_before[j + 1L] <- rb
    h_after[j + 1L] <- nb_; h_won[j + 1L] <- FALSE; h_opp[j + 1L] <- a

    rating[a] <- na_; rating[b] <- nb_
    # Counters advance only after the update, so both players are rated on the
    # experience they had going into the match.
    played[a] <- played[a] + 1L; played[b] <- played[b] + 1L
    h_played[j] <- played[a]; h_played[j + 1L] <- played[b]
  }

  history <- data.frame(
    match_index  = h_match,
    tourney_date = matches$tourney_date[h_match],
    tourney_id   = matches$tourney_id[h_match],
    player_id    = players[h_player],
    opponent_id  = players[h_opp],
    won          = h_won,
    rating_before = h_before,
    rating_after  = h_after,
    matches_played = h_played,
    stringsAsFactors = FALSE
  )

  ratings <- data.frame(
    player_id = players,
    rating    = rating,
    matches   = played,
    stringsAsFactors = FALSE
  )
  last_seen <- tapply(history$tourney_date, history$player_id, max)
  ratings$last_match <- as.Date(unname(last_seen[ratings$player_id]),
                                origin = "1970-01-01")
  ratings <- ratings[order(-ratings$rating), , drop = FALSE]
  rownames(ratings) <- NULL

  report <- base_report
  if (!is.null(report)) {
    report$dropped <- c(report$dropped, surface = dropped_surface)
    report$n_kept <- nrow(matches)
  } else {
    report <- structure(
      list(n_input = n_before_surface, n_kept = nrow(matches),
           dropped = c(surface = dropped_surface),
           levels = NA_character_, retirements = NA_character_),
      class = "tennelo_report"
    )
  }

  structure(
    list(
      config = list(surface = surface, initial = initial, pairing = pairing,
                    k_start = k_start, offset = offset, shape = shape),
      ratings = ratings,
      history = history,
      report  = report,
      as_of   = max(matches$tourney_date),
      first_date = min(matches$tourney_date),
      n_matches = n,
      n_players = length(players)
    ),
    class = "tennelo_fit"
  )
}

#' @export
print.tennelo_fit <- function(x, ...) {
  cat("<tennelo_fit>\n")
  cat(sprintf("  surface   : %s\n",
              if (is.null(x$config$surface)) "all" else x$config$surface))
  cat(sprintf("  pairing   : %s\n", x$config$pairing))
  cat(sprintf("  K         : k_start=%g offset=%g shape=%g\n",
              x$config$k_start, x$config$offset, x$config$shape))
  cat(sprintf("  matches   : %d\n", x$n_matches))
  cat(sprintf("  players   : %d\n", x$n_players))
  cat(sprintf("  covering  : %s to %s\n", x$first_date, x$as_of))
  cat(sprintf("  mean      : %.4f\n", mean(x$ratings$rating)))
  invisible(x)
}
