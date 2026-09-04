# Input validation.
#
# Every check aborts with a classed condition so that tests can assert on the
# condition class rather than on message text. Nothing here ever returns NA:
# an invalid input is an error, by design. See DESIGN.md, "Precision".

abort_input <- function(message, class, arg) {
  rlang::abort(message, class = c(class, "tennelo_input_error"), arg = arg)
}

# Shared preamble for every numeric argument.
#
# Missing values are tested BEFORE the type test, and deliberately so. A bare
# `NA` in R is logical, not numeric, so a type-first order would answer someone
# who passed a missing value with "must be numeric, not logical" -- technically
# true and entirely unhelpful. Passing NA is a missing-value problem, and the
# message should say that.
check_basic <- function(x, arg) {
  if (anyNA(x)) {
    abort_input(paste0("`", arg, "` must not contain NA or NaN."),
                "tennelo_error_value", arg)
  }
  if (!is.numeric(x)) {
    abort_input(paste0("`", arg, "` must be numeric, not ", class(x)[1], "."),
                "tennelo_error_type", arg)
  }
  if (length(x) == 0L) {
    abort_input(paste0("`", arg, "` must have at least one element."),
                "tennelo_error_length", arg)
  }
  invisible(x)
}

# Ratings must be finite. Inf is rejected rather than propagated: while
# elo_expected(1500, Inf) would give 0, elo_expected(Inf, Inf) evaluates
# 10^(NaN) and yields NaN -- the one value the package promises never to return.
check_rating <- function(x, arg) {
  check_basic(x, arg)
  if (!all(is.finite(x))) {
    abort_input(paste0("`", arg, "` must be finite; Inf is not a rating."),
                "tennelo_error_value", arg)
  }
  invisible(x)
}

# Scores are wins and losses. Tennis has no draws, so 0.5 is not accepted --
# admitting it would silently permit a half-result the data can never contain.
check_score <- function(x, arg) {
  check_basic(x, arg)
  if (!all(x %in% c(0, 1))) {
    abort_input(paste0("`", arg, "` must be 0 or 1; tennis matches have no draws."),
                "tennelo_error_value", arg)
  }
  invisible(x)
}

check_k <- function(x, arg) {
  check_basic(x, arg)
  if (!all(is.finite(x)) || any(x <= 0)) {
    abort_input(paste0("`", arg, "` must be finite and strictly positive."),
                "tennelo_error_value", arg)
  }
  invisible(x)
}

check_count <- function(x, arg) {
  check_basic(x, arg)
  if (!all(is.finite(x)) || any(x < 0) || any(x != trunc(x))) {
    abort_input(paste0("`", arg, "` must be whole numbers >= 0."),
                "tennelo_error_value", arg)
  }
  invisible(x)
}

# A single scalar parameter, used for the K-factor shape arguments.
check_scalar <- function(x, arg, min = -Inf, exclusive = FALSE) {
  if (anyNA(x)) {
    abort_input(paste0("`", arg, "` must not be NA or NaN."),
                "tennelo_error_value", arg)
  }
  if (!is.numeric(x) || length(x) != 1L) {
    abort_input(paste0("`", arg, "` must be a single number."),
                "tennelo_error_type", arg)
  }
  if (!is.finite(x) || (if (exclusive) x <= min else x < min)) {
    abort_input(paste0("`", arg, "` must be a finite number ",
                       if (exclusive) "greater than " else "of at least ", min, "."),
                "tennelo_error_value", arg)
  }
  invisible(x)
}

# Vectorised arguments must recycle cleanly: equal lengths, or length 1.
check_recyclable <- function(...) {
  args <- list(...)
  n <- vapply(args, length, integer(1))
  bad <- n[n != 1L]
  if (length(bad) > 1L && length(unique(bad)) > 1L) {
    abort_input(
      paste0("Arguments must have equal length or length 1; got lengths ",
             paste(n, collapse = ", "), "."),
      "tennelo_error_length", names(args)[1]
    )
  }
  invisible(NULL)
}
