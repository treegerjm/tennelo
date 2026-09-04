# The precision contract from PLAN section 6.1.
#
# Properties are split into those that hold to the last bit and those that need
# a tolerance. The split is not cosmetic: claiming bit-equality everywhere would
# be a promise the arithmetic cannot keep, and claiming tolerance everywhere
# would throw away real sharpness. Each test says which side it is on and why.

# ---- bit-exact -------------------------------------------------------------

test_that("even ratings give exactly one half", {
  # 10^0 is exactly 1 and 1/2 is exactly representable, so this is not "close
  # to" 0.5 -- it is 0.5.
  expect_identical(elo_expected(1500, 1500), 0.5)
  expect_identical(elo_expected(0, 0), 0.5)
  expect_identical(elo_expected(-300, -300), 0.5)
})

test_that("a 400-point gap matches the closed form exactly", {
  # -400/400 is exactly -1, so both sides evaluate the identical expression.
  expect_identical(elo_expected(1900, 1500), 1 / (1 + 10^-1))
  expect_identical(elo_expected(1500, 1900), 1 / (1 + 10^1))
})

test_that("expectation rises strictly with the player's own rating", {
  # A pure comparison of doubles: no arithmetic identity is being asserted.
  e <- elo_expected(seq(1000, 2000, by = 5), 1500)
  expect_true(all(diff(e) > 0))
})

test_that("K decays strictly and stays positive", {
  k <- elo_k(0:500)
  expect_true(all(diff(k) < 0))
  expect_true(all(k > 0))
})

test_that("the winner always gains and the loser always loses", {
  # Follows from 0 < E < 1 and k > 0, so it holds for every input, not just
  # the plausible ones.
  grid <- expand.grid(ra = seq(1000, 2000, by = 250),
                      rb = seq(1000, 2000, by = 250),
                      k  = c(1, 40, 131.33))
  won  <- elo_update(grid$ra, grid$rb, 1, grid$k)
  lost <- elo_update(grid$ra, grid$rb, 0, grid$k)
  expect_true(all(won$delta_a > 0), label = "winner gains")
  expect_true(all(won$delta_b < 0), label = "loser drops")
  expect_true(all(lost$delta_a < 0))
  expect_true(all(lost$delta_b > 0))
})

test_that("an upset moves more than an expected win", {
  k <- elo_k(10)
  upset    <- elo_update(1500, 2000, score_a = 1, k_a = k)
  expected <- elo_update(2000, 1500, score_a = 1, k_a = k)
  expect_true(abs(upset$delta_a) > abs(expected$delta_a))
})

test_that("with one shared K the transfers are exactly opposite", {
  # delta_b is computed as -(k_b * d), so with k_b == k_a this is the exact
  # negation -- no rounding sits between the two.
  u <- elo_update(1632.5, 1487.25, score_a = 1, k_a = 73.125)
  expect_identical(u$delta_b, -u$delta_a)
})

# ---- with tolerance --------------------------------------------------------

test_that("the two expectations sum to one", {
  # 10^x and 10^-x are not exact reciprocals, so this is an approximate
  # identity even though it is an exact one on paper.
  a <- c(1500, 1723.5, 900, 2100)
  b <- c(1500, 1490.25, 2000, 1000)
  expect_equal(elo_expected(a, b) + elo_expected(b, a),
               rep(1, length(a)), tolerance = 1e-12)
})

test_that("a shared K conserves the rating pool", {
  u <- elo_update(1712.5, 1488.75, score_a = 0, k_a = 44.5)
  # (a + d) + (b - d) rounds, so the sum is preserved to tolerance, not exactly.
  expect_equal(u$a + u$b, 1712.5 + 1488.75, tolerance = 1e-12)
})

test_that("separate K factors drift by exactly the predicted amount", {
  # The sharpest property in the package: the drift is not merely permitted,
  # it is pinned down. Any change to the update rule or the K-factor breaks it.
  ra <- 1500; rb <- 2000
  ka <- elo_k(0); kb <- elo_k(100)
  u  <- elo_update(ra, rb, score_a = 1, k_a = ka, k_b = kb)
  d  <- 1 - elo_expected(ra, rb)
  expect_equal((u$a + u$b) - (ra + rb), (ka - kb) * d, tolerance = 1e-12)
})

# ---- edge behaviour --------------------------------------------------------

test_that("expectation saturates without ever producing NaN", {
  # Thresholds measured on R 4.6.1; the test sits well clear of them, because a
  # test on the exact boundary checks the platform's rounding, not the model.
  expect_identical(elo_expected(1500, 1500 - 7000), 1)
  expect_identical(elo_expected(1500, 1500 + 130000), 0)

  wide <- elo_expected(1500, 1500 + c(0, 1e3, 1e4, 1e5, 1e6))
  expect_false(any(is.nan(wide)))
  expect_true(all(wide >= 0 & wide <= 1))
})

test_that("K is finite at zero matches", {
  expect_equal(elo_k(0), 250 / 5^0.4, tolerance = 1e-12)
  expect_true(is.finite(elo_k(0)))
})

# ---- invalid input is an error, never NA -----------------------------------

test_that("non-finite ratings are rejected", {
  # Inf is refused rather than propagated: elo_expected(Inf, Inf) would
  # evaluate 10^NaN and return the one value the package promises never to give.
  expect_error(elo_expected(NA, 1500),   class = "tennelo_error_value")
  expect_error(elo_expected(NaN, 1500),  class = "tennelo_error_value")
  expect_error(elo_expected(Inf, 1500),  class = "tennelo_error_value")
  expect_error(elo_expected(1500, -Inf), class = "tennelo_error_value")
  expect_error(elo_expected("1500", 1500), class = "tennelo_error_type")
})

test_that("scores other than 0 or 1 are rejected", {
  k <- elo_k(0)
  expect_error(elo_update(1500, 1500, 0.5, k), class = "tennelo_error_value")
  expect_error(elo_update(1500, 1500, 2, k),   class = "tennelo_error_value")
  expect_error(elo_update(1500, 1500, NA, k),  class = "tennelo_error_value")
})

test_that("non-positive K factors are rejected", {
  expect_error(elo_update(1500, 1500, 1, k_a = 0),   class = "tennelo_error_value")
  expect_error(elo_update(1500, 1500, 1, k_a = -10), class = "tennelo_error_value")
  expect_error(elo_update(1500, 1500, 1, k_a = NA),  class = "tennelo_error_value")
})

test_that("match counts must be whole and non-negative", {
  expect_error(elo_k(-1),  class = "tennelo_error_value")
  expect_error(elo_k(2.5), class = "tennelo_error_value")
  expect_error(elo_k(NA),  class = "tennelo_error_value")
})

test_that("incompatible argument lengths are rejected", {
  expect_error(elo_expected(c(1500, 1600, 1700), c(1500, 1600)),
               class = "tennelo_error_length")
})
