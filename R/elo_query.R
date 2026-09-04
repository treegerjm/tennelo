# Every function here reads a fitted object. None of them re-runs the engine.

fit_or_stop <- function(fit) {
  if (!inherits(fit, "tennelo_fit")) {
    abort_input("`fit` must be an object from fit_elo().", "tennelo_error_type", "fit")
  }
  invisible(fit)
}

resolve_as_of <- function(fit, as_of) {
  if (is.null(as_of)) return(fit$as_of)
  d <- try(as.Date(as_of), silent = TRUE)
  if (inherits(d, "try-error") || is.na(d)) {
    abort_input("`as_of` must be a date, or NULL for the last date processed.",
                "tennelo_error_value", "as_of")
  }
  d
}

#' Ratings at a point in time
#'
#' @param fit An object from [fit_elo()].
#' @param as_of A date. `NULL` (default) means the last date processed.
#'
#' @return A data frame of `player_id`, `rating`, `matches` and `last_match`,
#'   ordered by rating, for every player who had played by `as_of`.
#' @export
elo_ratings <- function(fit, as_of = NULL) {
  fit_or_stop(fit)
  when <- resolve_as_of(fit, as_of)
  if (when >= fit$as_of) return(fit$ratings)

  h <- fit$history[fit$history$tourney_date <= when, , drop = FALSE]
  if (nrow(h) == 0L) {
    return(fit$ratings[0, , drop = FALSE])
  }
  # The last row per player is that player's state on that date.
  last <- !duplicated(h$player_id, fromLast = TRUE)
  out <- data.frame(
    player_id  = h$player_id[last],
    rating     = h$rating_after[last],
    matches    = h$matches_played[last],
    last_match = h$tourney_date[last],
    stringsAsFactors = FALSE
  )
  out <- out[order(-out$rating), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' One player's rating history
#'
#' @param fit An object from [fit_elo()].
#' @param player_id The player's id.
#' @return A data frame, one row per match, in chronological order.
#' @export
elo_history <- function(fit, player_id) {
  fit_or_stop(fit)
  if (length(player_id) != 1L) {
    abort_input("`player_id` must be a single id.", "tennelo_error_length", "player_id")
  }
  h <- fit$history[fit$history$player_id == as.character(player_id), , drop = FALSE]
  if (nrow(h) == 0L) {
    abort_input(paste0("Player '", player_id, "' does not appear in this fit."),
                "tennelo_error_value", "player_id")
  }
  h <- h[order(h$match_index), , drop = FALSE]
  rownames(h) <- NULL
  h
}

#' Leaderboard
#'
#' @param fit An object from [fit_elo()].
#' @param n How many players to return.
#' @param as_of A date, or `NULL` for the last date processed.
#' @param active_within Days since a player's last match for them to count as
#'   active. `Inf` includes everyone.
#' @param min_matches Minimum matches before a player is ranked.
#' @param provisional If `FALSE` (default), players below `min_matches` are
#'   excluded. If `TRUE` they are kept and flagged in a `provisional` column.
#'
#' @return A data frame of the top `n`.
#'
#' @details
#' `min_matches` is not a detail. With `k_start = 250` a player can gain over
#' 300 points from three upsets and would otherwise sit in the top 20 on a
#' weekend's work.
#' @export
elo_leaderboard <- function(fit, n = 20, as_of = NULL,
                            active_within = 365, min_matches = 20,
                            provisional = FALSE) {
  fit_or_stop(fit)
  when <- resolve_as_of(fit, as_of)
  r <- elo_ratings(fit, when)
  if (nrow(r) == 0L) return(r)

  if (is.finite(active_within)) {
    r <- r[as.numeric(when - r$last_match) <= active_within, , drop = FALSE]
  }
  r$provisional <- r$matches < min_matches
  if (!provisional) {
    r <- r[!r$provisional, , drop = FALSE]
    r$provisional <- NULL
  }
  r <- r[order(-r$rating), , drop = FALSE]
  r <- utils::head(r, n)
  if (nrow(r) > 0L) r$rank <- seq_len(nrow(r))
  rownames(r) <- NULL
  r
}

#' Peak rating
#'
#' @param fit An object from [fit_elo()].
#' @param player_id The player's id.
#' @param min_matches Ignore peaks reached before this many matches, where a
#'   rating is still finding its level.
#'
#' @return A one-row data frame, or zero rows if the player never reached
#'   `min_matches`.
#'
#' @details
#' The date returned is a *tournament* start date, not the date of the match:
#' that is the finest resolution the source provides.
#' @export
elo_peak <- function(fit, player_id, min_matches = 20) {
  h <- elo_history(fit, player_id)
  h <- h[h$matches_played >= min_matches, , drop = FALSE]
  if (nrow(h) == 0L) {
    return(data.frame(player_id = character(0), rating = numeric(0),
                      tourney_date = as.Date(character(0)),
                      tourney_id = character(0), matches_played = integer(0),
                      stringsAsFactors = FALSE))
  }
  best <- which.max(h$rating_after)
  data.frame(
    player_id      = h$player_id[best],
    rating         = h$rating_after[best],
    tourney_date   = h$tourney_date[best],
    tourney_id     = h$tourney_id[best],
    matches_played = h$matches_played[best],
    stringsAsFactors = FALSE
  )
}
