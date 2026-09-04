# Generates a synthetic season used as a regression snapshot.
#
# Fully invented: 48 players with latent strengths, 12 tournaments across four
# surfaces, results drawn from a Bradley-Terry model on those strengths. No row
# derives from any real data set.
#
# Run with: Rscript tests/testthat/fixtures/make_season.R

set.seed(4242)
out_dir <- "tests/testthat/fixtures"

n_players <- 48
players <- sprintf("%03d", seq_len(n_players) + 200)
strength <- sort(rnorm(n_players, 0, 250), decreasing = TRUE)
names(strength) <- players

surfaces <- c("Hard", "Clay", "Grass", "Carpet")
levels   <- c("G", "M", "A", "F", "O")
rounds   <- c("R32", "R16", "QF", "SF", "F")

rows <- list(); k <- 0L
for (t in 1:12) {
  date  <- format(as.Date("2020-01-06") + (t - 1L) * 28L, "%Y%m%d")
  surf  <- surfaces[((t - 1L) %% 4L) + 1L]
  lvl   <- levels[((t - 1L) %% 5L) + 1L]
  tid   <- sprintf("2020-S%02d", t)
  field <- sample(players, 32)
  mnum  <- 0L
  for (r in rounds) {
    winners <- character(0)
    for (i in seq(1, length(field), by = 2)) {
      a <- field[i]; b <- field[i + 1L]
      p <- 1 / (1 + 10^((strength[[b]] - strength[[a]]) / 400))
      w <- if (runif(1) < p) a else b
      l <- if (w == a) b else a
      mnum <- mnum + 1L; k <- k + 1L
      rows[[k]] <- data.frame(
        tourney_id = tid, tourney_date = date,
        tourney_name = paste("Synthetic", t), tourney_level = lvl,
        match_num = mnum, surface = surf, round = r,
        best_of = if (lvl == "G") 5L else 3L,
        score = "6-4 6-4", winner_id = w, winner_name = paste("Player", w),
        loser_id = l, loser_name = paste("Player", l),
        stringsAsFactors = FALSE
      )
      winners <- c(winners, w)
    }
    field <- winners
  }
}
season <- do.call(rbind, rows)
write.csv(season, file.path(out_dir, "season_synthetic.csv"), row.names = FALSE)
cat("wrote", nrow(season), "matches\n")

# The latent strengths the results were drawn from. Storing them turns the
# snapshot into a correctness check as well as a regression check: a working
# engine should recover this ordering, not merely reproduce yesterday's output.
write.csv(data.frame(player_id = players, true_strength = unname(strength),
                     stringsAsFactors = FALSE),
          file.path(out_dir, "season_truth.csv"), row.names = FALSE)

# The golden file. Regenerate deliberately, never to make a red test go green.
suppressMessages(pkgload::load_all(".", quiet = TRUE))
m <- prepare_matches(load_matches(file.path(out_dir, "season_synthetic.csv")))
for (pairing in c("individual", "symmetric")) {
  f <- fit_elo(m, pairing = pairing)
  snap <- f$ratings
  snap$rating <- sprintf("%.17g", snap$rating)
  snap$pairing <- pairing
  snap$n_matches <- f$n_matches
  snap$mean_rating <- sprintf("%.17g", mean(f$ratings$rating))
  write.csv(snap, file.path(out_dir, paste0("snapshot_", pairing, ".csv")),
            row.names = FALSE)
}
cat("wrote snapshots\n")
