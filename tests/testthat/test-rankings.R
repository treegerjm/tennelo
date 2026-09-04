m  <- prepare_matches(load_matches(test_path("fixtures", "matches_synthetic.csv")))
rk <- prepare_rankings(load_rankings(test_path("fixtures", "rankings_synthetic.csv")))
f  <- fit_elo(m)

test_that("ranking files are validated on load", {
  expect_true(all(REQUIRED_RANKING_COLS %in% names(rk)))
  expect_error(load_rankings("nope.csv"), class = "tennelo_error_value")
  tmp <- tempfile(fileext = ".csv"); on.exit(unlink(tmp))
  write.csv(data.frame(x = 1), tmp, row.names = FALSE)
  expect_error(load_rankings(tmp), class = "tennelo_error_schema")
})

test_that("preparation parses types and reconciles its exclusions", {
  expect_s3_class(rk$ranking_date, "Date")
  expect_type(rk$rank, "integer")
  expect_type(rk$player, "character")
  r <- exclusion_report(rk)
  expect_identical(r$n_kept + sum(r$dropped), r$n_input)
})

test_that("unusable ranking rows are dropped and counted", {
  bad <- data.frame(
    ranking_date = c("20201102", "notadate", "20201102", "20201102"),
    rank         = c("1", "2", "zero", "4"),
    player       = c("101", "102", "103", ""),
    stringsAsFactors = FALSE
  )
  r <- exclusion_report(prepare_rankings(bad))
  expect_identical(unname(r$dropped[["missing_date"]]), 1L)
  expect_identical(unname(r$dropped[["bad_rank"]]), 1L)
  expect_identical(unname(r$dropped[["missing_player"]]), 1L)
  expect_identical(r$n_kept, 1L)
})

test_that("the join uses player ids and never names", {
  # The whole comparison rests on the two sources sharing an id space, which
  # was verified against the real files before this was written.
  cmp <- compare_rankings(f, rk, as_of = as.Date("2020-12-07"),
                          min_matches = 1, active_within = Inf, n = 5)
  expect_true(all(cmp$comparison$player_id %in% rk$player))
  expect_identical(cmp$n_matched, nrow(cmp$comparison))
})

test_that("the most recent ranking on or before the cut-off is chosen", {
  cmp <- compare_rankings(f, rk, as_of = as.Date("2020-11-20"),
                          min_matches = 1, active_within = Inf)
  expect_true(cmp$atp_date <= as.Date("2020-11-20"))
  expect_identical(cmp$atp_date, max(rk$ranking_date[rk$ranking_date <= as.Date("2020-11-20")]))
  expect_false(cmp$same_day)
  expect_gt(cmp$gap_days, 0)
})

test_that("same_day is only claimed when the dates really match", {
  same <- compare_rankings(f, rk, as_of = as.Date("2020-12-07"),
                           min_matches = 1, active_within = Inf)
  expect_true(same$same_day)
  expect_identical(same$gap_days, 0)
})

test_that("a cut-off before any ranking is an error, not a silent fallback", {
  expect_error(
    compare_rankings(f, rk, as_of = as.Date("2019-01-01"), min_matches = 1),
    class = "tennelo_error_value"
  )
})

test_that("players on only one side are reported, not quietly dropped", {
  cmp <- compare_rankings(f, rk, as_of = as.Date("2020-12-07"),
                          min_matches = 1, active_within = Inf)
  # Player 999 is ranked but never plays a match in the fixture.
  expect_true("999" %in% cmp$unmatched_atp)
  expect_identical(cmp$n_matched + length(cmp$unmatched_elo), cmp$n_elo)
})

test_that("rank differences are signed and consistent", {
  cmp <- compare_rankings(f, rk, as_of = as.Date("2020-12-07"),
                          min_matches = 1, active_within = Inf)
  expect_identical(cmp$comparison$rank_diff,
                   cmp$comparison$atp_rank - cmp$comparison$elo_rank)
  expect_identical(cmp$comparison$elo_rank, seq_len(nrow(cmp$comparison)))
})

test_that("the correlation is computed, not assumed", {
  cmp <- compare_rankings(f, rk, as_of = as.Date("2020-12-07"),
                          min_matches = 1, active_within = Inf, n = 5)
  expect_true(is.numeric(cmp$spearman))
  expect_true(cmp$spearman >= -1 && cmp$spearman <= 1)
  expect_lte(cmp$top_n_overlap, cmp$top_n)
})

test_that("thresholds that exclude everyone are an error", {
  expect_error(
    compare_rankings(f, rk, as_of = as.Date("2020-12-07"), min_matches = 500),
    class = "tennelo_error_value"
  )
})

test_that("bad arguments are rejected", {
  expect_error(compare_rankings("not a fit", rk), class = "tennelo_error_type")
  expect_error(compare_rankings(f, data.frame(a = 1)), class = "tennelo_error_schema")
})

test_that("the comparison has no duplicated column names", {
  # A duplicate `elo_rank` survived data frame printing unnoticed and only
  # surfaced when ggplot2 evaluated the column by name.
  cmp <- compare_rankings(f, rk, as_of = as.Date("2020-12-07"),
                          min_matches = 1, active_within = Inf)
  expect_false(anyDuplicated(names(cmp$comparison)) > 0)
  expect_true(all(c("elo_rank", "atp_rank", "rank_diff") %in% names(cmp$comparison)))
})
