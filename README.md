# tennelo

Elo ratings for tennis, computed from ATP match results — overall and by
playing surface.

The ATP ranking measures tournament entry and tournament category. Elo weights
the quality of the opponent. `tennelo` exists to compute the second one
reproducibly, so the two can be compared.

**Status:** complete for version 1. Core, data preparation, fitting engine,
ranking comparison and the analysis are all implemented and tested. See
[`PLAN.md`](PLAN.md) for the full specification.

## Results

Fitted over **182,775 tour-level matches from 1968 to 2026-05-25**, covering
5,896 players. Full write-up in
[`analysis/elo-vs-ranking.qmd`](analysis/elo-vs-ranking.qmd).

### Who the model rates highest

Active players, at least 20 career matches, as of 2026-05-25:

| # | Player | Elo | Matches |
|--:|---|--:|--:|
| 1 | Jannik Sinner | 2432.9 | 434 |
| 2 | Carlos Alcaraz | 2363.5 | 364 |
| 3 | Novak Djokovic | 2257.0 | 1359 |
| 4 | Alexander Zverev | 2171.5 | 771 |
| 5 | Arthur Fils | 2120.3 | 163 |

By surface the answer changes, which is the point of fitting them separately:

| Surface | Matches | Leader | Second | Third |
|---|--:|---|---|---|
| Hard | 74,710 | **Sinner** 2363 | Alcaraz 2236 | Djokovic 2224 |
| Clay | 64,326 | **Alcaraz** 2269 | Sinner 2231 | Djokovic 2149 |
| Grass | 22,815 | **Djokovic** 2189 | Alcaraz 2133 | Sinner 2034 |

Grass rests on a third of the clay sample, so it is the least stable of the
three. Carpet is excluded from the leaderboards: it was 22% of matches in 1975,
but the ATP dropped it at the end of the 2000s and no active player has a
meaningful record on it.

### Where Elo and the ATP ranking disagree

Spearman rank correlation **0.715** across 178 eligible players, with **14 of
20** shared in the top 20, comparing to the ATP ranking of the same day.

The disagreements are not noise. They fall into two groups, and each one traces
to a documented limitation of this model:

**Elo far above ATP** — Kokkinakis (Elo 46, ATP 855), Ymer (98 vs 900),
Nishikori (34 vs 703). These are players returning from long absences. An ATP
ranking decays when you stop entering tournaments; an Elo rating does not move
at all. The model has no absence correction.

**ATP far above Elo** — Quinn (Elo 151, ATP 50), Royer (165 vs 74), Bellucci
(147 vs 73). These are young players climbing fast. They built much of their
ranking at Challenger level, which this analysis excludes, so they enter at
1500 with no earned history.

### Does it hold up

The leader is the same under every variant tried:

| Variant | Spearman | Top-20 overlap | Leader |
|---|--:|--:|---|
| baseline | 0.715 | 14/20 | Sinner |
| symmetric pairing | 0.730 | 14/20 | Sinner |
| retirements excluded | 0.698 | 12/20 | Sinner |
| `k_start = 150` | 0.677 | 14/20 | Sinner |
| `k_start = 400` | 0.726 | 14/20 | Sinner |

## The rating core

```r
elo_expected(1500, 1500)
#> [1] 0.5

elo_k(0)     # a debutant's K-factor
#> [1] 131.3264

elo_k(100)   # after a hundred matches
#> [1] 38.85655

elo_update(1500, 2000, score_a = 1, k_a = elo_k(0), k_b = elo_k(100))
#> $a       1624.328
#> $b       1963.157
#> $delta_a 124.3282
#> $delta_b -36.84318
```

### Two pairing rules

When two players meet, each has their own experience-based K-factor, but a
match produces only one transfer of points. `tennelo` supports both answers and
documents the trade-off rather than hiding it.

**`individual`** — each player moves by their own K. This is the convention of
published tennis Elo lists, and it lets a rating built on hundreds of matches
resist a single result. The pool is not conserved; it drifts by exactly
`(k_a - k_b) * delta`, which is asserted as an identity in the tests.

**`symmetric`** — both players move by `elo_match_k(k_a, k_b)`, the geometric
mean. Transfers are equal and opposite, and the pool keeps its total. The cost
is that a veteran's K is pulled upward simply because the opponent is
inexperienced.

A debutant (K = 131.3, rated 1500) beating a veteran (K = 38.9, rated 2000):

| rule | debutant | veteran | pool |
|---|---:|---:|---:|
| `individual` | +124.3 | −36.8 | +87.5 |
| `symmetric` | +67.6 | −67.6 | ±0 |

`individual` is the default. The drift does not affect a comparison of players
at a single date, which is what the analysis does.

## Precision

Floating-point addition is not associative, so the package distinguishes
properties that hold to the last bit from those that need a tolerance, and says
which is which. `elo_expected(1500, 1500)` is exactly `0.5`;
`elo_expected(a, b) + elo_expected(b, a)` equals `1` only to within about
`1e-12`. Promising bit-equality everywhere would be a promise the arithmetic
cannot keep.

Invalid input is an error, never a silently returned `NA`.

## Installation

```r
# install.packages("pak")
pak::pak("treegerjm/tennelo")
```

## Licence

MIT for the code. **No match or ranking data is included in this repository**,
and all committed test fixtures are synthetic. The source data is CC BY-NC-SA
4.0 and is downloaded by the user; see [`DATA-SOURCES.md`](DATA-SOURCES.md).

## Acknowledgements

Match and ranking data compiled by Jeff Sackmann, used under CC BY-NC-SA 4.0.
Users are responsible for complying with that licence when downloading and
processing the data; see [`DATA-SOURCES.md`](DATA-SOURCES.md).

Parts of this package were written with AI assistance. The model design, the
decisions recorded in `PLAN.md` and their rationale are the author's.
