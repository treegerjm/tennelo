# Expected values computed independently of this package.
#
# fixtures/ratings_expected.csv was produced by fixtures/reference_elo.py -- a
# separate implementation, in a different language, written before this code
# existed. That is the point: a fixture generated from the code under test
# only proves the code agrees with itself.
#
# The sequence is five matches between three players, chosen to cover:
#   match 1  both players new, so k_a == k_b and both pairing rules must agree
#   match 2  unequal K, where the two rules start to diverge
#   match 3  the favourite wins  -- small delta
#   match 4  an upset            -- large delta
#   match 5  a repeated pairing, with both counters advanced

fixture <- read.csv(test_path("fixtures", "ratings_expected.csv"),
                    stringsAsFactors = FALSE)

replay <- function(pairing) {
  rows <- fixture[fixture$pairing == pairing, ]
  ratings <- c(A = 1500, B = 1500, C = 1500)
  counts  <- c(A = 0, B = 0, C = 0)
  got <- data.frame(winner_new = numeric(0), loser_new = numeric(0),
                    drift = numeric(0))

  for (i in seq_len(nrow(rows))) {
    w <- rows$winner[i]; l <- rows$loser[i]
    k_w <- elo_k(counts[[w]])
    k_l <- elo_k(counts[[l]])
    if (pairing == "symmetric") {
      k_w <- k_l <- elo_match_k(k_w, k_l)
    }
    before <- ratings[[w]] + ratings[[l]]
    u <- elo_update(ratings[[w]], ratings[[l]], score_a = 1,
                    k_a = k_w, k_b = k_l)
    ratings[[w]] <- u$a; ratings[[l]] <- u$b
    counts[[w]]  <- counts[[w]] + 1
    counts[[l]]  <- counts[[l]] + 1
    got[i, ] <- c(u$a, u$b, (u$a + u$b) - before)
  }
  list(step = got, final = ratings, counts = counts, expected = rows)
}

test_that("the individual-K run reproduces the hand-computed values", {
  r <- replay("individual")
  expect_equal(r$step$winner_new, r$expected$winner_new, tolerance = 1e-12)
  expect_equal(r$step$loser_new,  r$expected$loser_new,  tolerance = 1e-12)
})

test_that("the symmetric-K run reproduces the hand-computed values", {
  r <- replay("symmetric")
  expect_equal(r$step$winner_new, r$expected$winner_new, tolerance = 1e-12)
  expect_equal(r$step$loser_new,  r$expected$loser_new,  tolerance = 1e-12)
})

test_that("both rules agree on the first match, where the K factors are equal", {
  # The anchor. If this diverges, something fundamental is wrong -- both
  # players are new, so there is nothing for the rules to disagree about.
  iv <- replay("individual"); sy <- replay("symmetric")
  expect_identical(iv$step$winner_new[1], sy$step$winner_new[1])
  expect_identical(iv$step$loser_new[1],  sy$step$loser_new[1])
})

test_that("the rules diverge once experience differs", {
  # Not a scale factor on the same ratings: the two rules produce genuinely
  # different rating paths, and therefore different expectations downstream.
  iv <- replay("individual"); sy <- replay("symmetric")
  expect_false(isTRUE(all.equal(iv$final[["A"]], sy$final[["A"]],
                                tolerance = 1e-6)))
})

test_that("individual K drifts by exactly the predicted amount each match", {
  r <- replay("individual")
  expect_equal(r$step$drift, r$expected$drift, tolerance = 1e-12)
  expect_false(isTRUE(all.equal(sum(r$final), 4500, tolerance = 1e-9)))
})

test_that("symmetric K conserves the pool at every step", {
  r <- replay("symmetric")
  expect_equal(r$step$drift, rep(0, nrow(r$step)), tolerance = 1e-12)
  expect_equal(sum(r$final), 4500, tolerance = 1e-12)
  expect_equal(mean(r$final), 1500, tolerance = 1e-12)
})

test_that("every player is accounted for", {
  r <- replay("individual")
  expect_equal(sort(names(r$final)), c("A", "B", "C"))
  expect_equal(sum(r$counts), 10)   # five matches, two players each
  expect_false(anyNA(r$final))
})
