raw <- load_matches(test_path("fixtures", "matches_synthetic.csv"))
m   <- prepare_matches(raw)

test_that("no rating is missing or infinite", {
  for (p in c("individual", "symmetric")) {
    f <- fit_elo(m, pairing = p)
    expect_false(anyNA(f$ratings$rating), label = p)
    expect_true(all(is.finite(f$ratings$rating)), label = p)
    expect_false(anyNA(f$history$rating_after), label = p)
  }
})

test_that("every player in the matches appears in the result", {
  f <- fit_elo(m)
  expect_setequal(f$ratings$player_id,
                  unique(c(as.character(m$winner_id), as.character(m$loser_id))))
  expect_identical(f$n_players, nrow(f$ratings))
})

test_that("the same input twice gives bit-identical results", {
  a <- fit_elo(m); b <- fit_elo(m)
  expect_identical(a$ratings$rating, b$ratings$rating)
  expect_identical(a$history$rating_after, b$history$rating_after)
})

test_that("shuffling the raw rows leaves the ratings unchanged", {
  # The engine is order-dependent by nature, so this only holds because
  # prepare_matches() imposes a total order. It is the single most important
  # invariant in the package.
  reference <- fit_elo(m)
  for (seed in 1:10) {
    set.seed(seed)
    shuffled <- fit_elo(prepare_matches(raw[sample(nrow(raw)), , drop = FALSE]))
    expect_identical(shuffled$ratings$rating, reference$ratings$rating)
  }
})

test_that("match counts add up to two per match", {
  f <- fit_elo(m)
  expect_identical(sum(f$ratings$matches), 2L * f$n_matches)
  expect_identical(nrow(f$history), 2L * f$n_matches)
})

test_that("a player who only ever wins ends above the initial rating", {
  wins <- prepare_matches(raw)
  f <- fit_elo(wins)
  h <- elo_history(f, "101")
  if (all(h$won)) expect_gt(f$ratings$rating[f$ratings$player_id == "101"], 1500)
  # And the general form, on a purpose-built streak:
  streak <- m[m$winner_id == "101", , drop = FALSE]
  fs <- fit_elo(streak)
  expect_gt(fs$ratings$rating[fs$ratings$player_id == "101"], 1500)
})

test_that("symmetric pairing conserves the pool, individual does not", {
  sy <- fit_elo(m, pairing = "symmetric")
  iv <- fit_elo(m, pairing = "individual")
  n  <- nrow(sy$ratings)

  expect_equal(sum(sy$ratings$rating), 1500 * n, tolerance = 1e-9)
  expect_equal(mean(sy$ratings$rating), 1500, tolerance = 1e-9)

  # Not an invariant under individual K -- the drift is expected, and is
  # watched through the snapshot instead of being asserted away.
  expect_false(isTRUE(all.equal(sum(iv$ratings$rating), 1500 * n,
                                tolerance = 1e-9)))
})

test_that("history is chronological and rating_before chains to rating_after", {
  f <- fit_elo(m)
  for (p in f$ratings$player_id) {
    h <- elo_history(f, p)
    expect_false(is.unsorted(h$match_index), label = p)
    if (nrow(h) > 1L) {
      # Each match starts where the previous one ended.
      expect_identical(h$rating_before[-1], h$rating_after[-nrow(h)], label = p)
    }
    expect_identical(h$rating_before[1], 1500)
    expect_identical(h$matches_played, seq_len(nrow(h)))
  }
})

test_that("the winner's rating rises and the loser's falls, every time", {
  f <- fit_elo(m)
  won  <- f$history[f$history$won, ]
  lost <- f$history[!f$history$won, ]
  expect_true(all(won$rating_after > won$rating_before))
  expect_true(all(lost$rating_after < lost$rating_before))
})

test_that("surface models are independent and exclude unknown surfaces", {
  hard <- fit_elo(m, surface = "Hard")
  expect_true(all(m$surface[m$surface == "Hard"] == "Hard"))
  expect_lt(hard$n_matches, fit_elo(m)$n_matches)
  # A surface counter counts only that surface.
  h <- elo_history(hard, hard$ratings$player_id[1])
  expect_identical(max(h$matches_played), nrow(h))
  expect_error(fit_elo(m, surface = "Ice"), class = "tennelo_error_value")
})

test_that("matches without a surface are in the overall model only", {
  overall <- fit_elo(m)
  clay    <- fit_elo(m, surface = "Clay")
  expect_true(any(m$surface == "" | is.na(m$surface)))
  expect_gt(overall$n_matches, clay$n_matches)
  expect_gt(unname(exclusion_report(clay)$dropped[["surface"]]), 0)
})

test_that("as_of rewinds the ratings", {
  f <- fit_elo(m)
  early <- elo_ratings(f, as_of = as.Date("2020-01-06"))
  late  <- elo_ratings(f)
  expect_lt(nrow(early), nrow(late) + 1L)
  expect_true(all(early$matches <= late$matches[match(early$player_id, late$player_id)]))
  expect_identical(elo_ratings(f, as_of = f$as_of)$rating, f$ratings$rating)
  expect_identical(nrow(elo_ratings(f, as_of = as.Date("1900-01-01"))), 0L)
})

test_that("the leaderboard filters by activity and by matches played", {
  f <- fit_elo(m)
  all_players <- elo_leaderboard(f, min_matches = 0, active_within = Inf)
  expect_identical(nrow(all_players), nrow(f$ratings))
  expect_identical(all_players$rank, seq_len(nrow(all_players)))
  expect_false(is.unsorted(rev(all_players$rating)))

  strict <- elo_leaderboard(f, min_matches = 6, active_within = Inf)
  expect_true(all(strict$matches >= 6))

  active <- elo_leaderboard(f, min_matches = 0, active_within = 30)
  expect_true(all(as.numeric(f$as_of - active$last_match) <= 30))

  flagged <- elo_leaderboard(f, min_matches = 6, active_within = Inf,
                             provisional = TRUE)
  expect_true("provisional" %in% names(flagged))
  expect_true(any(flagged$provisional))
})

test_that("peak reports a tournament date and respects min_matches", {
  f <- fit_elo(m)
  p <- elo_peak(f, "101", min_matches = 1)
  expect_identical(nrow(p), 1L)
  expect_s3_class(p$tourney_date, "Date")
  expect_identical(p$rating, max(elo_history(f, "101")$rating_after))
  # Nobody in the fixture has 50 matches, so the peak is undefined, not wrong.
  expect_identical(nrow(elo_peak(f, "101", min_matches = 50)), 0L)
})

test_that("the exclusion report still reconciles after fitting", {
  f <- fit_elo(m, surface = "Hard")
  r <- exclusion_report(f)
  expect_identical(r$n_kept + sum(r$dropped), r$n_input)
})

test_that("unknown players and bad input are errors", {
  f <- fit_elo(m)
  expect_error(elo_history(f, "does-not-exist"), class = "tennelo_error_value")
  expect_error(elo_ratings("not a fit"), class = "tennelo_error_type")
  expect_error(fit_elo(data.frame(a = 1)), class = "tennelo_error_schema")
})
