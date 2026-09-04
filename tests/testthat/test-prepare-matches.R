fixture_path <- function(x) test_path("fixtures", x)
raw <- load_matches(fixture_path("matches_synthetic.csv"))

test_that("loading validates the schema", {
  expect_true(all(REQUIRED_MATCH_COLS %in% names(raw)))
  expect_error(load_matches("no-such-file.csv"), class = "tennelo_error_value")

  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  write.csv(data.frame(a = 1, b = 2), tmp, row.names = FALSE)
  expect_error(load_matches(tmp), class = "tennelo_error_schema")
})

test_that("every exclusion is counted and reconciles with the input", {
  p <- prepare_matches(raw)
  r <- exclusion_report(p)
  # The whole point of the report: nothing vanishes unaccounted for.
  expect_identical(r$n_kept + sum(r$dropped), r$n_input)
  expect_identical(r$n_kept, nrow(p))
})

test_that("the documented exclusion reasons each fire exactly once", {
  r <- exclusion_report(prepare_matches(raw))
  expect_identical(unname(r$dropped[["level"]]), 2L)          # Davis Cup, Challenger
  expect_identical(unname(r$dropped[["walkover"]]), 2L)       # "W/O" and ""
  expect_identical(unname(r$dropped[["missing_player"]]), 2L) # NA id, empty id
  expect_identical(unname(r$dropped[["duplicate"]]), 1L)
})

test_that("retirements are kept by default and dropped on request", {
  kept    <- prepare_matches(raw, retirements = "include")
  dropped <- prepare_matches(raw, retirements = "exclude")
  expect_identical(nrow(kept) - nrow(dropped), 1L)
  expect_identical(unname(exclusion_report(dropped)$dropped[["retirement"]]), 1L)
  expect_true(any(grepl("RET", kept$score)))
  expect_false(any(grepl("RET", dropped$score)))
})

test_that("walkovers go and retirements stay", {
  p <- prepare_matches(raw)
  expect_false(any(is_walkover(p$score)))
  expect_true(any(is_retirement(p$score)))
})

test_that("walkover detection is not fooled by spacing or case", {
  expect_true(all(is_walkover(c("W/O", "w/o", " W/O ", "walkover", "DEF.", "", NA))))
  expect_false(any(is_walkover(c("6-4 6-4", "6-1 RET", "7-6(4) 6-3"))))
})

test_that("Davis Cup is out and the Olympics are in", {
  expect_false("D" %in% prepare_matches(raw)$tourney_level)
  expect_true("O" %in% TOUR_LEVELS)
})

test_that("an unknown round code is an error, not a guess", {
  # Sorting it alphabetically would put a final before a quarter-final and
  # nobody would ever see it happen. This is not hypothetical: the full source
  # turned out to contain "ER", a code the first pass over sample years missed,
  # and this behaviour is what surfaced it instead of silently misordering 32
  # matches.
  bad <- load_matches(fixture_path("matches_bad_round.csv"))
  expect_error(prepare_matches(bad), class = "tennelo_error_round")
})

test_that("a conflicting duplicate is an error, an exact one is dropped", {
  conflict <- load_matches(fixture_path("matches_conflict.csv"))
  expect_error(prepare_matches(conflict), class = "tennelo_error_duplicate")
  expect_identical(unname(exclusion_report(prepare_matches(raw))$dropped[["duplicate"]]), 1L)
})

test_that("rounds sort in playing order, not alphabetically", {
  p <- prepare_matches(raw)
  slam <- p[p$tourney_id == "2020-G01", ]
  expect_identical(slam$round, c("QF", "QF", "SF"))
  # Alphabetically F < QF < R128 < RR < SF, which is nothing like the truth.
  expect_lt(ROUND_RANK[["QF"]], ROUND_RANK[["SF"]])
  expect_lt(ROUND_RANK[["SF"]], ROUND_RANK[["F"]])
  expect_identical(ROUND_RANK[["BR"]], ROUND_RANK[["F"]])
  # ER is the 2007 round-robin experiment's early round, played before the
  # group stage; every ER winner in those four events went on to play RR.
  expect_lt(ROUND_RANK[["R16"]], ROUND_RANK[["ER"]])
  expect_lt(ROUND_RANK[["ER"]], ROUND_RANK[["RR"]])
})

test_that("shuffling the input rows does not change the output", {
  # This is what the full sort key buys, and the fixture is built to stress it:
  # two tournaments in the same week with overlapping match_num.
  reference <- prepare_matches(raw)
  for (seed in 1:20) {
    set.seed(seed)
    shuffled <- prepare_matches(raw[sample(nrow(raw)), , drop = FALSE])
    expect_equal(shuffled, reference, ignore_attr = TRUE)
  }
})

test_that("concurrent tournaments stay separated", {
  p <- prepare_matches(raw)
  week <- p[p$tourney_date == as.Date("2020-01-06"), ]
  # Same date, overlapping match_num: only tourney_id keeps them apart.
  expect_identical(sort(unique(week$tourney_id)), c("2020-A01", "2020-B01"))
  expect_true(any(duplicated(week$match_num)))
  expect_false(is.unsorted(match(week$tourney_id, unique(week$tourney_id))))
})

test_that("dates parse and the table is ordered by the full key", {
  p <- prepare_matches(raw)
  expect_s3_class(p$tourney_date, "Date")
  expect_false(is.unsorted(p$tourney_date))
  key <- paste(p$tourney_date, p$tourney_id, sprintf("%03d", p$round_rank),
               sprintf("%05.0f", p$match_num), p$winner_id, p$loser_id)
  expect_false(is.unsorted(key))
})

test_that("matches with no surface survive preparation", {
  # They belong in the overall model; only surface models exclude them.
  p <- prepare_matches(raw)
  expect_true(any(p$surface == "" | is.na(p$surface)))
})

test_that("a player never plays themselves", {
  p <- prepare_matches(raw)
  expect_false(any(p$winner_id == p$loser_id))
})
