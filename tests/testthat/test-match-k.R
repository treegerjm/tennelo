test_that("combining is symmetric and positive", {
  a <- c(131.33, 40, 12.5, 250)
  b <- c(38.86, 90, 12.5, 1)
  expect_identical(elo_match_k(a, b), elo_match_k(b, a))
  expect_true(all(elo_match_k(a, b) > 0))
})

test_that("equal K factors return that value bit-for-bit", {
  # The short-circuit exists for this: sqrt(k * k) is not exactly k for every
  # representable k, and this identity is worth having exactly.
  k <- c(1, 38.86, 131.32639022018836, 1e-8, 1e8, pi)
  expect_identical(elo_match_k(k, k), k)
})

test_that("the geometric mean lies between its inputs", {
  a <- 131.32639022018836
  b <- 38.856554586156830
  m <- elo_match_k(a, b)
  expect_gt(m, b)
  expect_lt(m, a)
})

test_that("the combined K is the documented geometric mean", {
  expect_equal(elo_match_k(131.32639022018836, 38.856554586156830),
               sqrt(131.32639022018836 * 38.856554586156830),
               tolerance = 1e-12)
})

test_that("a symmetric update conserves the pool exactly as designed", {
  ka <- elo_k(0); kb <- elo_k(100)
  km <- elo_match_k(ka, kb)
  u  <- elo_update(1500, 2000, score_a = 1, k_a = km, k_b = km)
  expect_identical(u$delta_b, -u$delta_a)
  expect_equal(u$a + u$b, 3500, tolerance = 1e-12)
})

test_that("invalid K factors are rejected", {
  expect_error(elo_match_k(0, 40),   class = "tennelo_error_value")
  expect_error(elo_match_k(-1, 40),  class = "tennelo_error_value")
  expect_error(elo_match_k(NA, 40),  class = "tennelo_error_value")
  expect_error(elo_match_k(Inf, 40), class = "tennelo_error_value")
})
