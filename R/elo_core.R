#' Expected score of a match
#'
#' The standard Elo expectation: the probability that player A beats player B,
#' given their current ratings. A 400-point advantage corresponds to expected
#' odds of 10 to 1.
#'
#' @param rating_a,rating_b Numeric ratings. Must be finite; `NA`, `NaN` and
#'   `Inf` are errors, not missing values.
#'
#' @return A numeric vector in `[0, 1]`, the same length as the recycled
#'   inputs. Never `NaN`.
#'
#' @details
#' The result saturates at the edges of double precision: it rounds to exactly
#' `1` once `rating_a` exceeds `rating_b` by 6382 points, and to exactly `0`
#' once it trails by 123302 points. Both are far outside any rating a real
#' match sequence produces; they are documented so that tests can assert the
#' saturation rather than stumble into it.
#'
#' @examples
#' elo_expected(1500, 1500)   # 0.5, exactly
#' elo_expected(1900, 1500)   # a 400-point favourite
#' @export
elo_expected <- function(rating_a, rating_b) {
  check_rating(rating_a, "rating_a")
  check_rating(rating_b, "rating_b")
  check_recyclable(rating_a = rating_a, rating_b = rating_b)
  1 / (1 + 10^((rating_b - rating_a) / 400))
}

#' Experience-dependent K-factor
#'
#' The K-factor sets how far a single result moves a rating. It decays with the
#' number of matches a player has already had, so that a newcomer's rating
#' finds its level quickly while an established rating stays stable.
#'
#' @param matches_played Whole numbers `>= 0`: matches played *before* the
#'   match being rated.
#' @param k_start,offset,shape Model parameters. The defaults
#'   (`250`, `5`, `0.4`) follow the convention common in tennis Elo work, but
#'   they are parameters of this model, not universal constants.
#'
#' @return A numeric vector of strictly positive K-factors, decreasing in
#'   `matches_played`.
#'
#' @details
#' `K(m) = k_start / (m + offset)^shape`. With the defaults, a debutant gets
#' `K(0) = 131.33` and a player with 100 matches gets `K(100) = 38.86`.
#'
#' @examples
#' elo_k(0)     # 131.3264
#' elo_k(100)   # 38.85655
#' @export
elo_k <- function(matches_played, k_start = 250, offset = 5, shape = 0.4) {
  check_count(matches_played, "matches_played")
  check_scalar(k_start, "k_start", min = 0, exclusive = TRUE)
  check_scalar(offset, "offset", min = 0, exclusive = TRUE)
  check_scalar(shape, "shape", min = 0)
  k_start / (matches_played + offset)^shape
}

#' Combine two K-factors into a single match K-factor
#'
#' Used by the `"symmetric"` pairing rule, which gives both players the same
#' K-factor so that the rating pool keeps its total.
#'
#' @param k_a,k_b Strictly positive, finite K-factors.
#'
#' @return The geometric mean `sqrt(k_a * k_b)`.
#'
#' @details
#' Equal inputs return that value bit-for-bit. This is a deliberate
#' short-circuit: `sqrt(k * k)` is not exactly `k` for every representable `k`,
#' and `elo_match_k(k, k) == k` is a property worth having exactly rather than
#' approximately.
#'
#' @examples
#' elo_match_k(131.33, 38.86)
#' elo_match_k(50, 50)   # exactly 50
#' @export
elo_match_k <- function(k_a, k_b) {
  check_k(k_a, "k_a")
  check_k(k_b, "k_b")
  check_recyclable(k_a = k_a, k_b = k_b)
  ifelse(k_a == k_b, k_a, sqrt(k_a * k_b))
}

#' Surprise of a result
#'
#' The signed difference between what happened and what was expected. This is
#' the quantity the K-factor scales.
#'
#' Kept as its own function, rather than inlined into [elo_update()], because
#' it is testable to the last bit: once the delta is added onto a rating, that
#' precision is gone.
#'
#' @param rating_a,rating_b Finite numeric ratings.
#' @param score_a `1` if player A won, `0` if player A lost.
#'
#' @return `score_a - elo_expected(rating_a, rating_b)`, in `(-1, 1)`.
#'
#' @keywords internal
#' @noRd
elo_delta <- function(rating_a, rating_b, score_a) {
  check_score(score_a, "score_a")
  score_a - elo_expected(rating_a, rating_b)
}

#' Update two ratings after a match
#'
#' @param rating_a,rating_b Finite numeric ratings before the match.
#' @param score_a `1` if player A won, `0` if player A lost. Tennis has no
#'   draws, so `0.5` is an error.
#' @param k_a K-factor applied to player A.
#' @param k_b K-factor applied to player B. Defaults to `k_a`.
#'
#' @return A list with the new ratings `a` and `b` and the amounts transferred,
#'   `delta_a` and `delta_b`.
#'
#' @details
#' The default `k_b = k_a` is what selects the pairing rule, so that the core
#' needs no mode switch:
#'
#' * **`"individual"`** — pass each player's own K-factor. This matches the
#'   convention of published tennis Elo lists and lets an established rating
#'   resist a single result. The rating pool is then not conserved; it drifts by
#'   exactly `(k_a - k_b) * delta`, which is a testable identity rather than an
#'   unbounded error.
#' * **`"symmetric"`** — pass `elo_match_k(k_a, k_b)` for both, or rely on the
#'   default. The transfers are then equal and opposite by construction, and
#'   `delta_b == -delta_a` holds bit-for-bit.
#'
#' @examples
#' # Two debutants, so both K-factors agree and the pool is conserved.
#' elo_update(1500, 1500, score_a = 1, k_a = elo_k(0))
#'
#' # A debutant beats a veteran, each with their own K-factor.
#' elo_update(1500, 2000, score_a = 1, k_a = elo_k(0), k_b = elo_k(100))
#' @export
elo_update <- function(rating_a, rating_b, score_a, k_a, k_b = k_a) {
  check_rating(rating_a, "rating_a")
  check_rating(rating_b, "rating_b")
  check_score(score_a, "score_a")
  check_k(k_a, "k_a")
  check_k(k_b, "k_b")
  check_recyclable(rating_a = rating_a, rating_b = rating_b,
                   score_a = score_a, k_a = k_a, k_b = k_b)

  d <- score_a - elo_expected(rating_a, rating_b)
  delta_a <- k_a * d
  # Not -delta_a: under "individual" the two transfers differ. When k_b is k_a,
  # this still produces the exact negation, because -(k * d) == (-k) * d... but
  # we compute it as -(k_b * d) so the symmetric case is exact by construction.
  delta_b <- -(k_b * d)

  list(
    a       = rating_a + delta_a,
    b       = rating_b + delta_b,
    delta_a = delta_a,
    delta_b = delta_b
  )
}
