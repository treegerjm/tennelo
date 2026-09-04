# Generates the synthetic match and ranking fixtures.
#
# Everything here is invented. No row is copied or derived from any real data
# set, so the fixtures carry the same MIT licence as the rest of the package
# and can be distributed with it.
#
# Run with: Rscript tests/testthat/fixtures/make_synthetic.R

set.seed(20260904)
out_dir <- dirname(sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)))
if (length(out_dir) == 0 || out_dir == "") out_dir <- "tests/testthat/fixtures"

row <- function(tid, tname, surface, level, date, mnum, rnd, best_of, score,
                wid, wname, lid, lname) {
  data.frame(tourney_id = tid, tourney_name = tname, surface = surface,
             tourney_level = level, tourney_date = date, match_num = mnum,
             round = rnd, best_of = best_of, score = score,
             winner_id = wid, winner_name = wname,
             loser_id = lid, loser_name = lname,
             stringsAsFactors = FALSE)
}

P <- c("101" = "Ada Adams", "102" = "Bo Baker", "103" = "Cy Chase",
       "104" = "Di Dunn",  "105" = "Ed Evans", "106" = "Fi Frost")
nm <- function(id) unname(P[as.character(id)])
m <- function(tid, tname, surf, lvl, date, mnum, rnd, score, w, l, bo = 3)
  row(tid, tname, surf, lvl, date, mnum, rnd, bo, score, w, nm(w), l, nm(l))

d <- rbind(
  # --- two tournaments running in the SAME week, with OVERLAPPING match_num.
  # Without tourney_id and the trailing player ids in the sort key, the order
  # of these rows would not be well defined.
  m("2020-A01", "Alpha Open", "Hard",  "A", "20200106", 1, "SF", "6-4 6-4", 101, 102),
  m("2020-A01", "Alpha Open", "Hard",  "A", "20200106", 2, "SF", "7-5 6-3", 103, 104),
  m("2020-A01", "Alpha Open", "Hard",  "A", "20200106", 3, "F",  "6-2 6-2", 101, 103),
  m("2020-B01", "Beta Open",  "Clay",  "A", "20200106", 1, "SF", "6-1 6-1", 105, 106),
  m("2020-B01", "Beta Open",  "Clay",  "A", "20200106", 2, "SF", "6-3 6-4", 102, 104),
  m("2020-B01", "Beta Open",  "Clay",  "A", "20200106", 3, "F",  "6-4 7-6(3)", 105, 102),

  # --- a Grand Slam, best of five, later in the year
  m("2020-G01", "Grand Slam", "Grass", "G", "20200629", 1, "QF", "6-3 6-4 6-4", 101, 105, 5),
  m("2020-G01", "Grand Slam", "Grass", "G", "20200629", 2, "QF", "7-6(4) 6-4 6-7(2) 6-3", 103, 106, 5),
  m("2020-G01", "Grand Slam", "Grass", "G", "20200629", 3, "SF", "6-4 6-4 6-4", 101, 103, 5),

  # --- round robin, where match_num is the only order within the group
  m("2020-F01", "Tour Finals", "Hard", "F", "20201115", 1, "RR", "6-4 6-4", 101, 103),
  m("2020-F01", "Tour Finals", "Hard", "F", "20201115", 2, "RR", "6-2 6-2", 105, 102),
  m("2020-F01", "Tour Finals", "Hard", "F", "20201115", 3, "F",  "7-5 6-4", 101, 105),

  # --- rows that must be excluded, one per reason
  m("2020-A01", "Alpha Open", "Hard", "A", "20200106", 10, "R16", "W/O",        104, 106),
  m("2020-A01", "Alpha Open", "Hard", "A", "20200106", 11, "R16", "",           106, 104),
  m("2020-A01", "Alpha Open", "Hard", "A", "20200106", 12, "R16", "6-1 RET",    102, 105),
  m("2020-D01", "Davis Cup",  "Clay", "D", "20200302",  1, "RR", "6-0 6-0",     101, 106),
  m("2020-C01", "Challenger", "Hard", "C", "20200302",  1, "F",  "6-4 6-4",     106, 104),
  m("2020-A01", "Alpha Open", "Hard", "A", "20200106", 13, "R16", "6-3 6-3",     NA, 104),
  m("2020-A01", "Alpha Open", "Hard", "A", "20200106", 14, "R16", "6-3 6-3",    103, ""),

  # --- a missing surface: kept overall, dropped from surface models
  m("2021-A01", "Alpha Open", "",      "A", "20210104", 1, "F", "6-4 6-4", 103, 101)
)
# --- an exact duplicate of an existing row: dropped, and counted
d <- rbind(d, d[d$tourney_id == "2020-A01" & d$match_num == 3, ])

d <- d[, c("tourney_id","tourney_date","tourney_name","tourney_level",
           "match_num","surface","round","best_of","score",
           "winner_id","winner_name","loser_id","loser_name")]
write.csv(d, file.path(out_dir, "matches_synthetic.csv"), row.names = FALSE, na = "")

# --- a file whose only defect is an unknown round code.
# "ZZ" is deliberately meaningless. An earlier version of this fixture used
# "ER", which then turned out to be a real code (the 2007 round-robin
# experiment) and had to be added to ROUND_RANK -- at which point this fixture
# silently stopped testing anything. Keep this code invented.
bad <- m("2020-A01", "Alpha Open", "Hard", "A", "20200106", 20, "ZZ", "6-4 6-4", 101, 102)
bad <- bad[, names(d)]
write.csv(bad, file.path(out_dir, "matches_bad_round.csv"), row.names = FALSE, na = "")

# --- the same match twice with different winners: a conflict, not a duplicate
conf <- rbind(
  m("2020-A01", "Alpha Open", "Hard", "A", "20200106", 30, "R16", "6-4 6-4", 101, 102),
  m("2020-A01", "Alpha Open", "Hard", "A", "20200106", 30, "R16", "6-4 6-4", 102, 101)
)
write.csv(conf[, names(d)], file.path(out_dir, "matches_conflict.csv"),
          row.names = FALSE, na = "")

# --- rankings: weekly Mondays, player ids from the same space as the matches
dates <- format(seq(as.Date("2020-11-02"), as.Date("2020-12-07"), by = "7 days"), "%Y%m%d")
rk <- do.call(rbind, lapply(dates, function(dt) {
  data.frame(ranking_date = dt, rank = 1:6,
             player = c(101, 105, 103, 102, 104, 106),
             points = c(9000, 7000, 5500, 4000, 3000, 1500),
             stringsAsFactors = FALSE)
}))
# one ranking row for a player who never appears in the match data
rk <- rbind(rk, data.frame(ranking_date = dates, rank = 7L, player = 999L,
                           points = 900L, stringsAsFactors = FALSE))
rk <- rk[order(rk$ranking_date, rk$rank), ]
write.csv(rk, file.path(out_dir, "rankings_synthetic.csv"), row.names = FALSE)

cat("wrote fixtures to", out_dir, "\n")
