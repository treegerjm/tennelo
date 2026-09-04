# A generated synthetic season, used two ways.
#
# 1. As a REGRESSION snapshot: the stored ratings must not change unnoticed.
#    A snapshot cannot establish correctness -- it was produced by the very
#    code it guards. That job belongs to test-hand-computed.R, whose expected
#    values come from an independent implementation.
#
# 2. As a CORRECTNESS check: the results were drawn from known latent
#    strengths, so a working engine should recover their ordering. That does
#    not depend on this package's own output at all.
#
# Regenerate the fixtures with fixtures/make_season.R, and only ever on
# purpose -- never to turn a red test green.

season <- prepare_matches(load_matches(test_path("fixtures", "season_synthetic.csv")))
truth  <- read.csv(test_path("fixtures", "season_truth.csv"),
                   colClasses = c("character", "numeric"))

test_that("the fitted ratings match the stored snapshot", {
  for (pairing in c("individual", "symmetric")) {
    snap <- read.csv(test_path("fixtures", paste0("snapshot_", pairing, ".csv")),
                     colClasses = c(player_id = "character", rating = "character",
                                    mean_rating = "character"))
    f <- fit_elo(season, pairing = pairing)
    expect_identical(f$n_matches, snap$n_matches[1], label = pairing)
    expect_identical(nrow(f$ratings), nrow(snap), label = pairing)
    expect_identical(f$ratings$player_id, snap$player_id, label = pairing)
    expect_equal(f$ratings$rating, as.numeric(snap$rating),
                 tolerance = 1e-12, label = pairing)
    # The mean is recorded rather than asserted to be 1500: under individual
    # pairing it drifts, and the snapshot is how that drift stays watched.
    expect_equal(mean(f$ratings$rating), as.numeric(snap$mean_rating[1]),
                 tolerance = 1e-12, label = pairing)
  }
})

test_that("the engine recovers the latent strength ordering", {
  f <- fit_elo(season)
  merged <- merge(f$ratings, truth, by = "player_id")
  rho <- suppressWarnings(cor(merged$rating, merged$true_strength,
                              method = "spearman"))
  expect_gt(rho, 0.85)
})

test_that("the two pairing rules agree on who is good, not on the numbers", {
  iv <- fit_elo(season, pairing = "individual")$ratings
  sy <- fit_elo(season, pairing = "symmetric")$ratings
  both <- merge(iv, sy, by = "player_id", suffixes = c("_iv", "_sy"))
  expect_gt(cor(both$rating_iv, both$rating_sy, method = "spearman"), 0.9)
  expect_false(isTRUE(all.equal(both$rating_iv, both$rating_sy, tolerance = 1e-6)))
})

test_that("a full season keeps every invariant", {
  f <- fit_elo(season)
  expect_false(anyNA(f$ratings$rating))
  expect_true(all(is.finite(f$ratings$rating)))
  expect_identical(sum(f$ratings$matches), 2L * f$n_matches)
  expect_identical(exclusion_report(f)$n_kept + sum(exclusion_report(f)$dropped),
                   exclusion_report(f)$n_input)
})

test_that("symmetric pairing conserves the pool over a full season", {
  f <- fit_elo(season, pairing = "symmetric")
  expect_equal(mean(f$ratings$rating), 1500, tolerance = 1e-9)
})

test_that("surface models fit independently on a full season", {
  for (s in c("Hard", "Clay", "Grass", "Carpet")) {
    f <- fit_elo(season, surface = s)
    expect_gt(f$n_matches, 0, label = s)
    expect_lt(f$n_matches, fit_elo(season)$n_matches, label = s)
    expect_false(anyNA(f$ratings$rating), label = s)
  }
})

test_that("re-ordering a full season changes nothing", {
  reference <- fit_elo(season)
  set.seed(99)
  raw <- load_matches(test_path("fixtures", "season_synthetic.csv"))
  shuffled <- fit_elo(prepare_matches(raw[sample(nrow(raw)), , drop = FALSE]))
  expect_identical(shuffled$ratings$rating, reference$ratings$rating)
})
