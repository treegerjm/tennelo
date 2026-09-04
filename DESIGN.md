# Design notes

Why `tennelo` is built the way it is. This covers the decisions that are not
obvious from the code, and the reasoning behind the ones that could plausibly
have gone the other way.

## The question

The ATP ranking measures tournament entry and tournament category: enter more
events, win at bigger ones, rise. It does not weight who you beat. Elo does.
The two therefore measure different things, and where they disagree is
informative.

`tennelo` computes the second one reproducibly so the comparison can be made.
The package is the tool; `analysis/elo-vs-ranking.qmd` is the answer.

Elo is an estimate inside a disclosed model. It is not a measurement of true
playing strength, and the package takes care never to claim otherwise.

## The model

For player A against player B:

```
E_A = 1 / (1 + 10^((R_B - R_A) / 400))
```

Every player starts at 1500. A result moves a rating by `K * (S - E)`, where
`S` is 1 for a win and 0 for a loss — tennis has no draws, so 0.5 is rejected
rather than quietly accepted.

`K` falls with experience, so that a newcomer's rating finds its level quickly
while a rating built on hundreds of matches stays stable:

```
K(m) = k_start / (m + offset)^shape        k_start = 250, offset = 5, shape = 0.4
```

With those defaults `K(0) = 131.33` and `K(100) = 38.86`. They follow the
convention common in tennis Elo work, but they are parameters of this model,
not universal constants, and the analysis reports results across a range of
them.

Match counters advance only *after* an update, so both players are rated on the
experience they brought into the match.

## Two players, two K-factors, one transfer

This is the decision with the most consequence, and it is genuinely contested.

Each player has their own experience-based K. A match produces one transfer of
points. Something has to give.

**`individual`** moves each player by their own K. **`symmetric`** gives both
the geometric mean `sqrt(K_A * K_B)`.

A debutant (K = 131.3, rated 1500) beating a veteran (K = 38.9, rated 2000),
a 5.3% result:

| rule | debutant | veteran | pool |
|---|---:|---:|---:|
| `individual` | +124.3 | −36.8 | +87.5 |
| `symmetric` | +67.6 | −67.6 | ±0 |

`symmetric` conserves the rating pool, which is a clean property. The cost is
visible in the table: the veteran loses nearly twice as much, because their K
was dragged from 38.9 up to 71.4 **by their opponent's inexperience**. The
experience weighting is diluted by whoever happens to be across the net — and
that happens most often to top players, who play many first-round matches
against newcomers and wildcards. Those are exactly the players a leaderboard is
about.

`individual` keeps the weighting intact and pays with a pool that drifts. But
the drift is not an unbounded error; it is exactly

```
sum(after) - sum(before) = (K_A - K_B) * (S_A - E_A)
```

which the tests assert as an identity. Testability is therefore not an argument
for either side: this equation pins the drift down as tightly as conservation
pins down its absence.

What settles it is that the drift does not affect the questions being asked.
Both compare players **on one date**, and a uniform inflation moves no ranks.
Drift would matter for cross-era comparison, which is out of scope for exactly
this reason.

`individual` is the default. `symmetric` is available, and the analysis reports
both, so the size of the choice is visible rather than asserted.

## Precision

Floating-point addition is not associative. Claiming bit-equality everywhere
would be a promise the arithmetic cannot keep; claiming tolerance everywhere
throws away real sharpness. So the two are separated, and each property says
which side it is on and why.

**Exact** (`expect_identical`)

| property | why it is exact |
|---|---|
| `elo_expected(1500, 1500) == 0.5` | `10^0` is exactly 1, and `1/2` is representable |
| `elo_expected(1900, 1500) == 1/(1 + 10^-1)` | `-400/400` is exactly `-1`; both sides evaluate the same expression |
| monotonicity of `elo_expected` and `elo_k` | pure comparisons, no arithmetic identity |
| winner gains, loser loses | follows from `0 < E < 1` and `k > 0` |
| `elo_match_k(k, k) == k` | short-circuited on equality (see below) |
| `delta_b == -delta_a` under one shared K | one delta, computed once |

**Approximate** (`expect_equal`, tolerance `1e-12`)

| property | why it is not exact |
|---|---|
| `elo_expected(a, b) + elo_expected(b, a) == 1` | `10^x` and `10^-x` are not exact reciprocals |
| pool conservation under `symmetric` | `(a + d) + (b - d)` rounds |
| the drift identity under `individual` | same rounding |

`elo_match_k(k, k)` returns `k` by short-circuit rather than computing
`sqrt(k * k)`, which is not exactly `k` for every representable `k`. The
identity is worth having exactly.

**Saturation**, measured rather than estimated: `elo_expected` rounds to
exactly `1` once the rating gap reaches 6382 points and to exactly `0` at
123302, passing through the subnormal range in between without ever producing
`NaN`. Tests sit well clear of both thresholds, because a test on the boundary
checks the platform's rounding rather than the model.

Infinite ratings are rejected at the door. A single infinite argument would
behave, but `elo_expected(Inf, Inf)` evaluates `10^NaN` and returns the one
value the package promises never to return. Invalid input is always an error,
never a silently returned `NA`.

## Order, and its limit

The engine is inherently order-dependent: a rating at time *t* depends on
*t−1*. The result is reproducible only because preparation imposes a **total**
order:

```
tourney_date, tourney_id, round_rank, match_num, winner_id, loser_id
```

`tourney_id` is not optional — `tourney_date` is identical for every match of a
tournament and `match_num` runs only within one, so concurrent tournaments
would otherwise be interleaved arbitrarily. The trailing player ids are
deterministic tie-breakers, not a claim about the true order of play; without
them the guarantee that re-ordering the input leaves the result unchanged fails
wherever `match_num` repeats. Tests shuffle the input rows thirty times and
require bit-identical output.

`round_rank` is an explicit mapping, never alphabetical — sorted as text a final
would precede a quarter-final and nobody would notice:

```
R128 → R64 → R32 → R16 → ER → RR → QF → SF → F        BR ranks with F
```

`ER` is the early round of the round-robin format the ATP trialled in 2007 at
four 250-level events. It is played before the group stage: in all four events
every one of the eight ER winners went on to appear in RR. It accounts for 32
rows in the entire data set, and it was found only because an unknown round
code aborts rather than being guessed at.

**The limit:** `tourney_date` is the start date of the *tournament*, not of the
match. The chronology is correct tournament by tournament, not day by day —
within one week a match played earlier can be rated after one played later.
That is a property of the source. It is documented rather than defined away,
and it is why `elo_peak()` returns a tournament date.

## What is rated

| | |
|---|---|
| Included | Grand Slams, Masters, 250/500, Tour Finals, Olympics (`G M A F O`) |
| Excluded | Davis Cup — dead rubbers, home choice of surface, substitute line-ups |
| Excluded | Challenger, qualifying, futures |
| Weighting | none: neither tournament level nor best-of enters the K-factor |
| Walkovers | excluded — no match was played |
| Retirements | included by default — the match was played and a winner stands |
| Duplicates | identical rows dropped and counted; conflicting rows are an error |
| Missing ids | excluded, never joined by name |

Player ids are the identity key throughout. Names are for display only. Joining
on names would silently merge distinct players and split single ones.

**Every excluded row is counted by reason**, and the counts reconcile with the
input row count. Nothing is filtered silently.

Surface models are fitted independently, with their own experience counters,
and are never blended with the overall model. Matches with no recorded surface
are rated overall and excluded from surface models.

## Testing

Four layers, each doing something the others cannot.

**Properties of the core** are asserted per the precision contract above.

**Hand-computed values** come from a separate implementation, in another
language, written before the R code and committed beside the fixture it
generates. A fixture generated by the code under test proves only that the code
agrees with itself.

**Dataset invariants** run over synthetic fixtures built to be awkward:
concurrent tournaments, repeated `match_num`, unknown round codes, walkovers,
retirements, missing ids, exact and conflicting duplicates.

**A synthetic season** serves twice. As a regression snapshot it detects
unintended change. As a correctness check it does something a snapshot cannot:
the results were drawn from known latent strengths, so a working engine should
recover their ordering, and the test requires it to.

Comparison against a published Elo list lives in `analysis/validate-external.R`,
outside the package tests and outside CI. As a test it would fail whenever
someone else's list was updated — data maintenance, not a code defect. It is a
plausibility check, not an oracle.

## Data and licences

The package contains no match or ranking data, and every committed fixture is
synthetic. The MIT licence therefore covers everything in the repository
without qualification, and the CC BY-NC-SA source data never enters it. See
`DATA-SOURCES.md`.

Downloads write a manifest recording each file's URL, size, SHA-256 checksum,
retrieval time and the source commit, so a published result can say exactly
which bytes produced it.

## What the model cannot do

- **No absence correction.** A player returning after a year out keeps the
  rating they left with, while their ATP ranking has decayed. This is the
  single largest source of disagreement between the two.
- **No lower-tier history.** Everyone enters at 1500, roughly an average tour
  professional. A real newcomer is below that and hands out points they never
  earned. Rising players are therefore under-rated relative to their ATP rank.
- **Early ratings are uncertain.** A player near the minimum-match threshold can
  sit high on a short run of upsets. `min_matches` limits this; it does not
  remove it. Without it, three upsets at `k_start = 250` are worth over 300
  points and a place in the top 20.
- **Small samples on grass**, and carpet is excluded from leaderboards: it was
  22% of matches in 1975, but the ATP dropped it at the end of the 2000s and no
  active player has a meaningful record on it. Those matches remain in the
  overall model.
- **No cross-era comparison.** Under `individual` pairing the pool drifts, so
  ratings from different decades are not on a common scale.
- **Approximate within-week order**, as described above.
