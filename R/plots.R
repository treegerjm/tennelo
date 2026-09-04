#' Plot rating histories
#'
#' @param fit An object from [fit_elo()].
#' @param player_id One or more player ids.
#' @param ... Passed to `ggplot2::labs()`.
#'
#' @return A ggplot object.
#'
#' @details
#' ggplot2 is a suggested dependency, not an import: the package is fully
#' usable without graphics, so availability is checked at call time.
#' @export
plot_elo_history <- function(fit, player_id, ...) {
  fit_or_stop(fit)
  rlang::check_installed("ggplot2", reason = "to plot rating histories.")

  h <- do.call(rbind, lapply(player_id, function(p) elo_history(fit, p)))
  surface <- if (is.null(fit$config$surface)) "all surfaces" else fit$config$surface

  ggplot2::ggplot(
    h, ggplot2::aes(x = .data$tourney_date, y = .data$rating_after,
                    colour = .data$player_id)
  ) +
    ggplot2::geom_step() +
    ggplot2::geom_hline(yintercept = fit$config$initial,
                        linetype = "dashed", linewidth = 0.3) +
    ggplot2::labs(x = NULL, y = "Elo rating", colour = "player",
                  subtitle = paste0(surface, ", pairing: ", fit$config$pairing),
                  ...) +
    ggplot2::theme_minimal()
}
