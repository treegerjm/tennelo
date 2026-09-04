# `tennelo` — Elo-Wertungen für Tennis in R

Zusammengeführter Projektplan.

> Diese Fassung führt `PLAN-tennelo_neu.md` und `PLAN-tennelo-revised.md`
> zusammen. Grundgerüst ist `-revised`; die mathematische Schärfe, der
> festgelegte Matchumfang und die Werkzeugfragen kommen aus `_neu`.
> Abschnitt 12 hält fest, was woher stammt und wo die beiden Vorlagen sich
> widersprachen. Abschnitt 11 hält die getroffenen Entscheidungen fest und
> nennt den einen Punkt, der vor Stufe 4 noch an der Quelle zu prüfen ist.

---

## 1. Ziel und Forschungsfragen

`tennelo` ist ein öffentliches R-Paket, das aus ATP-Matchdaten reproduzierbare
Elo-Wertungen berechnet — insgesamt und getrennt nach Belag.

Die begleitende Analyse beantwortet für einen **festgelegten Stichtag** zwei
präzise Fragen:

1. Bei welchen aktiven Spielern weicht die Elo-Rangfolge am stärksten von der
   offiziellen ATP-Rangliste ab?
2. Welche aktiven Spieler bewertet das in `tennelo` implementierte Modell
   insgesamt und auf den einzelnen Belägen am höchsten?

Der Hintergrund: Die ATP-Weltrangliste misst Turnierteilnahme und
Turnierkategorie, nicht Gegnerqualität. Elo gewichtet die Gegnerstärke. Wo die
beiden auseinanderlaufen, ist inhaltlich interessant.

Wichtige Einschränkung, die im README und in der Analyse stehen bleibt: Elo ist
eine Schätzung **innerhalb eines offengelegten Modells**, keine objektive
Messung der „wahren" Spielstärke. Das Paket ist das wiederverwendbare Werkzeug;
die Analyse beantwortet die Forschungsfragen.

### Nicht-Ziele für Version 1

- keine Shiny-App und kein Dashboard
- keine Punkt-für-Punkt-Daten
- kein Wettmodell und kein Vorhersagedienst
- keine Verletzungs- oder Abwesenheitskorrektur
- keine Mischung aus Gesamt- und Belag-Elo
- **kein Vergleich über Epochen hinweg** — beide Fragen betreffen aktive Spieler
  zu einem Stichtag; Aussagen der Form „X wäre gegen Y von 1985 favorisiert"
  trägt das Modell nicht
- keine CRAN-Einreichung
- keine Match- oder Ranglistendaten Dritter im Repository

---

## 2. Rahmen

- **Sprache:** R. Code, Funktionsnamen, roxygen2-Dokumentation, README und
  Vignetten auf Englisch — das Repository ist öffentlich.
- **Paketname:** `tennelo`. Am 2026-09-04 geprüft: auf CRAN nicht vergeben
  (24.888 Pakete), fügt sich in die bestehende Familie `elo`, `EloRating`,
  `EloChoice`, `EloOptimized`, `EloSteepness`.
- **Code-Lizenz:** MIT.
- **Hinweis zur Entstehung.** Der Code wurde mit KI-Unterstützung entwickelt.
  Das steht als ein bis zwei Sätze am Ende des README unter
  „Acknowledgements" — neben der Attribution an Jeff Sackmann, die dort ohnehin
  hingehört. **Nicht** in `DESCRIPTION` (strukturierte Metadaten, falscher Ort)
  und **nicht** als `Co-Authored-By`-Trailer in den Commits: das erzeugt auf
  GitHub eine zweite Autorenzeile an jedem Commit und trägt einen internen
  Sitzungslink dauerhaft in ein öffentliches Repository.

### Abhängigkeiten — bewusst schlank

| Feld | Pakete | Begründung |
|---|---|---|
| `Imports` (Kern) | `rlang` | Der mathematische Kern und `fit_elo()` brauchen nichts weiter. |
| ~~`Imports` (ab Stufe 2)~~ | ~~`dplyr`, `readr`~~ | **Nicht eingetreten.** Base R (`read.csv`, `order`, `merge`) reicht vollständig. Das Paket hat damit genau **eine** Abhängigkeit statt drei. |
| `Suggests` | `testthat`, `ggplot2` | Das Paket bleibt ohne Grafik voll benutzbar. `knitr`/`rmarkdown` werden nur für die Analyse gebraucht, die außerhalb des Pakets liegt. |

`plot_elo_history()` prüft `ggplot2` zur Laufzeit über
`rlang::check_installed()`. Was nur für Tests, Vignetten oder die Analyse
gebraucht wird, steht nicht unter `Imports`.

---

## 3. Daten, Lizenz und Reproduzierbarkeit

### 3.1 Quellen — **geprüft am 2026-09-04, Lage hat sich geändert**

Der Plan ging von Jeff Sackmanns Repository `JeffSackmann/tennis_atp` aus.
**Dieses Repository existiert nicht mehr.** Geprüft:

```text
JeffSackmann/tennis_atp                 HTTP 404
JeffSackmann/tennis_wta                 HTTP 404
JeffSackmann/tennis_slam_pointbypoint   HTTP 404
JeffSackmann/tennis_MatchChartingProject  HTTP 200   ← einziges verbliebenes Repo
```

Der Account hat noch **ein** öffentliches Repository. Warum die Datensätze
verschwunden sind, ist von außen nicht erkennbar.

**Verfügbarer Ersatz:** `Aneeshers/tennis-sackmann-archive` — ein
Archivspiegel, angelegt am 2026-06-25, ausdrücklich „data only", unter CC
BY-NC-SA 4.0 mit Attribution an Sackmann und mitgeführtem
`UPSTREAM_README.md`. Inhalt geprüft:

| | |
|---|---|
| Einzelmatches | `atp_matches_1968.csv` … `atp_matches_2026.csv` (59 Jahresdateien) |
| Ranglisten | `atp_rankings_70s/80s/90s/00s/10s/20s/current.csv` |
| Spielertabelle | `atp_players.csv` (66.912 Einträge) |
| Ebenfalls vorhanden | Qual/Challenger (49), Futures (36), Doppel (21) — für dieses Projekt nicht benötigt |

**Datenstand des Spiegels:** letzter Turniertag `2026-05-25`, jüngste Rangliste
`2026-06-08`. Das ist der Stichtag, den die Analyse bekommt — nicht der
Kalendertag des Laufs.

**Entscheidung am 2026-09-04: der Archivspiegel wird verwendet.** Eine Anfrage
beim Urheber war kurzzeitig vorgesehen und wurde verworfen.

Die Pflichten aus CC BY-NC-SA gelten unabhängig davon und werden wie in 3.2
beschrieben erfüllt: Namensnennung Jeff Sackmann, nicht kommerzielle Nutzung,
keine Weiterverteilung der Daten. `DATA-SOURCES.md` nennt zusätzlich den
Spiegel als tatsächlich genutzten Bezugsweg, das ursprüngliche Repository als
Herkunft und den Umstand, dass Letzteres seit 2026 nicht mehr erreichbar ist.

**Datenstand ist eingefroren.** Der Spiegel endet am 2026-05-25 und wird nicht
mehr fortgeschrieben, solange es kein Upstream gibt. Für die Reproduzierbarkeit
der Analyse ist das eher günstig — der Stichtag ist ohnehin festzuschreiben
(Abschnitt 7). Für eine spätere Fortschreibung des Projekts wäre eine neue
Quelle nötig.

Challenger-, Qualifikations-, Futures- und Doppeldateien werden nicht geladen
(Abschnitt 4.5).

### 3.2 Trennung der Lizenzen

Sackmanns Daten stehen derzeit unter CC BY-NC-SA 4.0: Namensnennung
erforderlich, nicht kommerziell, Share-Alike für weitergegebene Bearbeitungen.
Daraus folgt eine strikte Trennung, die von Anfang an so angelegt wird:

| Was | Lizenz |
|---|---|
| Paketcode | MIT |
| Test-Fixtures | MIT — weil **synthetisch erzeugt**, keine Quelldaten |
| Quelldaten | bleiben beim Nutzer, nie im Repository |

Konkret:

- Keine kopierten oder ausgeschnittenen Zeilen aus den Quelldaten im Paket.
- Sämtliche eingecheckten Fixtures sind synthetisch und in
  `tests/testthat/fixtures/README.md` als solche ausgewiesen.
- `DATA-SOURCES.md` dokumentiert Quelle, Urheber, URL, Lizenz, Abrufdatum und
  ausdrücklich, dass das Paket die Daten **nicht** weiterverteilt.
- Das README weist Nutzer darauf hin, dass sie beim Herunterladen und
  Verarbeiten selbst für die Einhaltung der Quellenlizenz verantwortlich sind.

Damit fällt die Lizenzfrage vollständig aus dem Repository heraus — es gibt
nichts abzuwägen und nichts vor der Veröffentlichung nachzuprüfen.

### 3.3 Lokaler Download und Provenienz

`data-raw/download_matches.R` und `data-raw/download_rankings.R` laden nach:

```text
data-raw/csv/matches/
data-raw/csv/rankings/
```

Die Skripte:

- zeigen vor dem Download Quelle, Lizenz und Attribution an;
- akzeptieren einen expliziten Jahresbereich beziehungsweise Stichtag;
- überschreiben vorhandene Dateien nur auf ausdrücklichen Wunsch;
- schreiben ein lokales Manifest mit Quell-URLs, Abrufzeit, Dateigrößen,
  SHA-256-Prüfsummen und, soweit verfügbar, der Commit-ID der Quelle;
- brechen bei fehlenden oder geänderten Spalten verständlich ab.

`data-raw/csv/` einschließlich Manifest steht vollständig in `.gitignore`.

### 3.4 Benötigte Felder

Matches:

```text
tourney_id, tourney_date, tourney_name, tourney_level,
match_num, surface, round, best_of, score,
winner_id, winner_name, loser_id, loser_name
```

`tourney_id` ist nicht optional: `tourney_date` ist für alle Matches eines
Turniers gleich und `match_num` läuft nur turnierintern — ohne `tourney_id` ist
die Reihenfolge bei parallel laufenden Turnieren mehrdeutig (Abschnitt 4.5).

Ranglisten: mindestens Ranglistendatum, Spieler-ID und ATP-Rang.

**Spieler-IDs sind der Identitätsschlüssel; Namen dienen nur der Anzeige.**

**Am 2026-09-04 an den Daten bestätigt** — das war der kritische Prüfpunkt vor
Stufe 4:

```text
Match-IDs (2026) in atp_players      355 von 355    100,0 %
Ranglisten-IDs  in atp_players      2409 von 2409   100,0 %
Match-IDs (2026) in Rangliste        326 von 355     91,8 %
```

`player` in den Ranglistendateien, `player_id` in `atp_players.csv` und
`winner_id`/`loser_id` in den Matchdateien sind **derselbe ID-Raum**. Der Join
in `compare_rankings()` kann wie geplant gebaut werden.

Die 8,2 % Matchspieler ohne Ranglisteneintrag sind kein Fehler, sondern der
erwartete Fall: Wildcards, Qualifikanten und Zurückgekehrte ohne Platzierung im
betrachteten Stand. Sie gehören in die Diagnose nicht zugeordneter Spieler
(5.4), nicht in einen Ausschluss.

Ranglisten erscheinen **montags**, im Abstand von 7 oder 14 Tagen. Spalten:
`ranking_date`, `rank`, `player`, `points`.
Zeilen ohne auflösbare Spieler-ID werden nicht über Namen zusammengeführt,
sondern mit strukturierter Warnung ausgeschlossen und im Ausschlussbericht
gezählt.

---

## 4. Elo-Modell

### 4.1 Erwartungswert

```text
E_A = 1 / (1 + 10^((R_B - R_A) / 400))
```

Jeder neue Spieler beginnt mit 1500 Punkten (`initial`, konfigurierbar).

### 4.2 Erfahrungsabhängiger K-Wert

Aus der Zahl der zuvor verarbeiteten Matches folgt je Spieler ein vorläufiger
K-Wert:

```text
K_i(m_i) = k_start / (m_i + offset)^shape
```

Voreinstellungen: `k_start = 250`, `offset = 5`, `shape = 0.4`.

Diese Werte sind konfigurierbar und werden als **Modellparameter** beschrieben,
nicht als universelle Tennis-Konvention. Zur Orientierung:
`elo_k(0) = 131.33`, `elo_k(1) = 122.09`, `elo_k(100) = 38.86`.

Die Matchzähler beider Spieler werden **erst nach** der Aktualisierung erhöht.

### 4.3 Wie aus zwei K-Werten ein Update wird — die Kernentscheidung

Jeder Spieler hat einen eigenen K-Wert aus seiner Erfahrung. Spielen die beiden
gegeneinander, gibt es aber nur eine Punktübertragung. Die Vorlagen
widersprachen sich hier direkt; die Regel wird deshalb ein benannter,
dokumentierter Parameter:

```r
fit_elo(matches, pairing = c("individual", "symmetric"), ...)
```

**`"individual"` — Voreinstellung.** Getrennte K-Werte je Spieler:

```text
d    = S_A - E_A
R_A' = R_A + K_A * d
R_B' = R_B - K_B * d
```

Das entspricht der in der Tennis-Elo-Literatur verbreiteten Konvention und
macht die Wertungen mit veröffentlichten Listen vergleichbar. Vor allem tut es
das, wofür der erfahrungsabhängige K gedacht ist: Ein Neuling springt stark,
eine auf hunderten Matches ruhende Wertung bewegt sich kaum.

Preis: die Summe bleibt **nicht** erhalten. Sie driftet — aber exakt
bezifferbar:

```text
sum(neu) - sum(alt) = (K_A - K_B) * d
```

**`"symmetric"` — Option.** Ein gemeinsamer Match-K über das geometrische
Mittel:

```text
K_match = sqrt(K_A * K_B)
delta   = K_match * (S_A - E_A)
R_A'    = R_A + delta
R_B'    = R_B - delta
```

Die Übertragung ist per Konstruktion gleich groß und entgegengesetzt, der
Bewertungspool behält seine Summe.

**Warum `individual` und nicht `symmetric`.** Ein Neuling (0 Matches, K = 131,3,
Wertung 1500) schlägt einen Routinier (100 Matches, K = 38,9, Wertung 2000).
Die Siegwahrscheinlichkeit lag bei 5,3 %, also `d = 0,9468`:

| | Neuling | Routinier | Pool |
|---|---|---|---|
| `individual` | +124,3 | −36,8 | +87,5 |
| `symmetric` | +67,6 | −67,6 | ±0 |

Unter `symmetric` verliert der Routinier fast doppelt so viel — sein K wurde
faktisch von 38,9 auf 71,4 hochgezogen, **weil sein Gegner unerfahren ist**. Die
Erfahrungsgewichtung wird also von der Erfahrung des Gegners verwässert, und
zwar am stärksten bei Topspielern, die viele Erstrundenmatches gegen Neulinge
und Wildcards bestreiten. Genau diese Spieler sind das Thema von
Forschungsfrage 2.

Die Drift von `individual` schadet den beiden Forschungsfragen dagegen kaum:
Beide vergleichen Spieler **zum selben Stichtag**, und eine gleichmäßige
Inflation verschiebt keine Rangfolge. Drift wäre ein Problem beim Vergleich
über Epochen hinweg — den schließt Abschnitt 1 ausdrücklich aus.

Testbarkeit ist kein Argument für eine der beiden Seiten: Die Drift-Gleichung
legt die Abweichung genauso exakt fest wie die Summenerhaltung ihre Konstanz
und bricht bei jedem Fehler in Update-Formel oder K genauso zuverlässig
(Abschnitt 6.1).

Beide Modi werden getestet und dokumentiert. Die Analyse in Stufe 6 läuft mit
`"individual"`; die Sensitivitätstabelle rechnet beide, damit sichtbar wird, wie
viel die Wahl überhaupt ausmacht.

`S_A` ist 1 bei einem Sieg von A und 0 bei einer Niederlage. Das Paket
behauptet in keinem Modus, die Formel eines anderen Anbieters exakt zu
reproduzieren.

### 4.4 Gesamt- und Belagmodelle

- `surface = NULL` verarbeitet alle zulässigen Matches.
- `surface = "Clay"`, `"Hard"`, `"Grass"`, `"Carpet"` passt ein **unabhängiges**
  Modell nur mit Matches auf diesem Belag an.
- **Carpet** — Teppich, ein ausgerollter Hallenbelag, sehr schnell und mit
  niedrigem Absprung — war von den 1970ern bis in die 2000er verbreitet und
  wurde Ende der 2000er von der Tour genommen; die Hallenturniere spielen
  seither Indoor-Hartplatz. An den Daten bestätigt — Carpet-Anteil je Stichjahr:
  1968 7,7 %, 1975 22,3 %, 1985 15,4 %, 1995 16,6 %, 2005 8,6 %, ab 2015
  durchgehend 0,0 %. Die Matches bleiben im Gesamtmodell und die
  Funktion bleibt im Paket, weil das zehntausende real gespielte Partien sind.
  Eine Carpet-Rangliste **aktiver** Spieler wäre dagegen leer oder unsinnig;
  die Analyse führt deshalb nur Hard, Clay und Grass (Abschnitt 7).
- Der Erfahrungszähler eines Belagmodells zählt nur Matches auf diesem Belag.
- Matches mit fehlendem Belag fließen ins Gesamtmodell ein und werden aus
  Belagmodellen ausgeschlossen.
- Version 1 mischt Gesamt- und Belag-Elo bewusst nicht. Rasen- und
  Teppichergebnisse werden wegen der kleineren Stichprobe als weniger stabil
  gekennzeichnet.

Belag-Ranglisten verwenden eine eigene, niedrigere Mindestzahl an Matches
(Abschnitt 7).

### 4.5 Ein- und Ausschluss von Matches

| Punkt | Festlegung |
|---|---|
| Matchumfang | **Nur Tour-Level:** `tourney_level` in `G`, `M`, `A`, `F`, `O` — Grand Slams, Masters, 250/500, Tour Finals, Olympische Spiele. Kein Davis Cup (`D`): tote Rubber, Heimbelagswahl und Ersatzaufstellungen verzerren die Wertung. Kein Challenger, keine Qualifikation, keine Futures. Als Paketvoreinstellung gesetzt, über `levels` überschreibbar. |
| Gewichtung | keine. Weder `tourney_level` noch `best_of` gehen in den K-Faktor ein. Beide sind Filter- und Kontextspalten, keine Modellparameter. |
| Walkover | ausgeschlossen (kein gespieltes Match). Erkannt über `score`: leer, `NA`, oder normalisiert passend auf `W/O`, `WO`, `Walkover`, `DEF`, `Def.`. |
| Aufgabe (RET) | standardmäßig eingeschlossen — es wurde gespielt und ein Sieger steht fest. Für Sensitivitätsanalysen: `retirements = "exclude"`. |
| Freilose | ausgeschlossen. |
| Fehlende Spieler-ID | ausgeschlossen, nie über Namen zusammengeführt. |
| Duplikate | exakte Duplikate werden vor der Berechnung erkannt, ausgeschlossen und ausgewiesen. **Widersprüchliche** Duplikate (gleicher Schlüssel, anderes Ergebnis) sind ein Fehler. |
| Fehlender Belag | im Gesamtlauf enthalten, in Belagläufen ausgeschlossen. |

**Das Ergebnis der Aufbereitung enthält immer einen Ausschlussbericht. Keine
Filterung geschieht stillschweigend, und alle Ausschlusszahlen lassen sich mit
der Eingabezeilenzahl abstimmen.**

**In den Daten vorhandene `tourney_level`-Werte** (Stichjahre, 2026-09-04
erhoben): `A` 18.631, `M` 4.270, `G` 4.124, `D` 2.215, `F` 105, **`O` 64**.

`O` steht für die **Olympischen Spiele**. Im ursprünglichen Plan schlicht
übersehen, **am 2026-09-04 entschieden: eingeschlossen.** Es sind reale Matches
zwischen Tour-Spielern im Vollfeld; der Ausschlussgrund für Davis Cup — tote
Rubber, Heimbelagswahl, Ersatzaufstellungen — trifft hier nicht zu. Dass es
keine Weltranglistenpunkte gibt, ist für ein Elo-Modell ohne Gewichtung
irrelevant (Zeile „Gewichtung" oben).

**Bekannte Folge der Tour-Level-Beschränkung.** Jeder Spieler betritt den
Datensatz mit 1500 — das entspricht ungefähr einem durchschnittlichen
Tour-Profi. Ein echter Neuling ist darunter, kommt also mit geschenkten Punkten
an und gibt sie in seinen ersten Matches an seine Gegner ab. `min_matches` hält
ihn aus der Rangliste heraus, korrigiert aber die Wertung seiner Gegner nicht.
Betroffen sind vor allem aufstrebende Spieler mit kurzer Tour-Historie — also
ausgerechnet die Gruppe, bei der Elo und ATP-Rangliste am stärksten
auseinanderlaufen. Das wird in Abschnitt 7 als Grenze der Aussagekraft
ausgewiesen und nicht wegdefiniert.

### 4.6 Reihenfolge und ihre Grenze

`tourney_date` ist das Startdatum des **Turniers**, nicht des Matches. Die
Chronologie stimmt damit turnierweise, nicht tagesgenau: innerhalb einer Woche
kann ein früher gespieltes Match nach einem später gespielten einsortiert
werden. Das ist eine Eigenschaft der Quelle — sie wird dokumentiert und nicht
wegdefiniert. `elo_peak()` gibt entsprechend ein Turnierdatum zurück.

Das Paket verspricht eine **deterministische Annäherung** an die Chronologie,
keine exakte Reihenfolge über parallel laufende Turniere hinweg. Sortiert wird
über einen vollständigen Schlüssel:

```text
tourney_date
tourney_id
round_rank
match_num
winner_id
loser_id
```

`round_rank` ist eine **explizite** Zuordnung. Erst über neun Stichjahre
erhoben, dann beim ersten Lauf über den vollständigen Datensatz korrigiert:

```text
R128 → R64 → R32 → R16 → ER → RR → QF → SF → F
```

**`ER` fehlte in der Stichprobe.** Der volle Datensatz enthält 32 Zeilen mit
diesem Code, alle aus 2007, alle Level `A`, verteilt auf vier Turniere:
Adelaide, Buenos Aires, Delray Beach, Las Vegas — je acht Matches. Das ist das
Round-Robin-Format, das die ATP 2007 bei vier 250er-Turnieren erprobte. `ER`
(„early round") wird **vor** der Gruppenphase gespielt; an den Daten geprüft
ziehen in allen vier Turnieren alle acht ER-Sieger in `RR` ein. Der Code steht
deshalb zwischen `R16` und `RR`.

Gefunden wurde er nicht durch Nachdenken, sondern weil `prepare_matches()` bei
einem unbekannten Rundencode abbricht statt alphabetisch zu sortieren. Genau
dafür ist diese Regel da.

`BR` (Spiel um Platz 3, 63 Vorkommen im vollen Datensatz) steht auf derselben Stufe wie `F`.
Qualifikationsrunden (`Q1`–`Q3`) tauchen in den Tour-Level-Dateien **nicht** auf
— die stehen in den nicht verwendeten `qual_chall`-Dateien. Der Sortierschlüssel
braucht sie deshalb nicht.

Innerhalb von `RR` (Gruppenphase der Tour Finals) gibt es keine natürliche
Ordnung; dort entscheidet `match_num`. **Ein unbekannter Rundencode ist ein verständlicher
Fehler, kein `NA` und keine stillschweigend alphabetische Einsortierung.**

`winner_id` und `loser_id` am Ende sind deterministische Tie-Breaker, keine
Behauptung über die tatsächliche Spielreihenfolge. Ohne sie bricht die
Invariante „andere Zeilenreihenfolge ändert nichts" bei wiederholten
`match_num`-Werten. README und Analyse nennen diese Einschränkung und ihren
möglichen Einfluss auf knappe Bewertungsabstände.

---

## 5. Öffentliche Schnittstelle

### 5.1 Reine Kernfunktionen

```r
elo_expected(rating_a, rating_b)
elo_k(matches_played, k_start = 250, offset = 5, shape = 0.4)
elo_match_k(k_a, k_b)                      # geometrisches Mittel
elo_update(rating_a, rating_b, score_a, k_a, k_b = k_a)

# intern, nicht exportiert
elo_delta(rating_a, rating_b, score_a)     # score_a - elo_expected(...)
```

`elo_update()` gibt beide neuen Wertungen und den übertragenen Betrag zurück:

```r
list(a = ..., b = ..., delta_a = ..., delta_b = ...)
```

Bei `k_b = k_a` (dem symmetrischen Fall) gilt `delta_b == -delta_a` bitgenau.

`elo_delta()` steht als eigene interne Funktion da und nicht inline in
`elo_update()`, weil sich an ihr die Update-Regel bitgenau testen lässt — bei
`elo_update()` selbst geht die Genauigkeit durch die Addition auf die Wertung
verloren (Abschnitt 6.1).

`elo_match_k(k, k)` gibt `k` bitgenau zurück (Kurzschluss bei Gleichheit statt
`sqrt(k*k)`, das nicht für alle `k` exakt ist).

### 5.2 Datenaufbereitung

```r
load_matches(path)
prepare_matches(raw,
                levels = c("G", "M", "A", "F", "O"),
                retirements = c("include", "exclude"))

load_rankings(path)
prepare_rankings(raw)
```

Aufbereitete Objekte behalten ihren Validierungs- und Ausschlussbericht als
Attribut.

### 5.3 Einmal berechnen, mehrfach auswerten

```r
fit_elo(matches,
        surface  = NULL,
        initial  = 1500,
        pairing  = c("individual", "symmetric"),
        k_start  = 250, offset = 5, shape = 0.4)
```

`fit_elo()` liefert ein Objekt der Klasse `tennelo_fit` mit:

- Konfiguration und Modellparametern (inklusive `pairing`);
- Datenstichtag und Provenienzmetadaten;
- aktuellen Spielerwertungen und Matchzahlen;
- vollständigem Bewertungsverlauf;
- Ausschlussbericht.

Alle nachgelagerten Funktionen arbeiten auf diesem Objekt, statt den Datensatz
je Spieler neu zu durchlaufen — ein Diagramm mit fünf Spielern kostet sonst
fünf vollständige Läufe über rund 190.000 Matches:

```r
elo_ratings(fit, as_of = NULL)
elo_history(fit, player_id)
elo_leaderboard(fit, n = 20, as_of = NULL,
                active_within = 365, min_matches = 20)
elo_peak(fit, player_id, min_matches = 20)
plot_elo_history(fit, player_id, ...)
```

`as_of = NULL` bezeichnet das letzte verarbeitete Datum.

`min_matches` ist kein Detail, sondern notwendig: bei `k_start = 250` holt ein
Spieler mit drei Überraschungssiegen über 300 Punkte und stünde ungefiltert in
den Top 20. Spieler unterhalb der Schwelle werden je nach explizitem Argument
ausgeschlossen oder sichtbar als vorläufig gekennzeichnet.

### 5.4 Vergleich mit der ATP-Rangliste

```r
compare_rankings(fit, rankings, as_of,
                 active_within = 365, min_matches = 20, n = 20)
```

Wählt den jüngsten ATP-Ranglistenstand, der nicht nach `as_of` liegt, verbindet
über die Spieler-ID und liefert:

- die tatsächlich verwendeten Elo- und ATP-Daten;
- Zahl und Anteil erfolgreich verbundener Spieler;
- Spearman-Rangkorrelation;
- Top-n-Überschneidung;
- Rangdifferenz jedes gemeinsamen Spielers;
- Diagnose nicht zugeordneter Spieler.

Ein Vergleich heißt nur dann „Vergleich desselben Tages", wenn beide Daten
tatsächlich übereinstimmen. Weder ein bestimmter Erstplatzierter noch eine
feste Top-20-Überschneidung ist als Korrektheitsbeweis fest verdrahtet.

---

## 6. Korrektheitsanforderungen und Tests

Fließkommaaddition ist nicht assoziativ. Deshalb wird getrennt zwischen
Eigenschaften, die **bitgenau** gelten, und solchen, die eine **Toleranz**
brauchen. Pauschales `==` über alle Eigenschaften wäre eine Zusage, die der
Code nicht halten kann; pauschale Toleranz verschenkt umgekehrt echte Schärfe.

### 6.1 Eigenschaften der Kernfunktionen

**Bitgenau (`expect_identical`)**

| Eigenschaft | warum exakt |
|---|---|
| `elo_expected(1500, 1500) == 0.5` | `10^0 == 1`, `1/2` ist exakt darstellbar |
| `elo_expected(1900, 1500) == 1/(1 + 10^-1)` | `-400/400` ist exakt `-1`, beide Seiten rechnen dasselbe |
| `elo_expected` streng monoton steigend in `rating_a` | reiner Vergleich |
| `elo_k` fällt monoton in `matches_played` und bleibt `> 0` | reiner Vergleich |
| `elo_match_k(a, b) == elo_match_k(b, a)`, immer `> 0` | Symmetrie der Multiplikation |
| `elo_match_k(k, k) == k` | Kurzschluss bei Gleichheit (5.1) |
| Sieger gewinnt immer Punkte, Verlierer verliert immer Punkte | folgt aus `0 < E < 1` und `k > 0` |
| eine Überraschung bewegt mehr als ein erwarteter Sieg (gleiches K) | Vergleich zweier `abs(delta)` |
| `pairing = "symmetric"`: `delta_b == -delta_a` | ein `delta`, einmal berechnet |

**Mit Toleranz (`expect_equal`, `tolerance = 1e-12`)**

| Eigenschaft | warum nicht exakt |
|---|---|
| `elo_expected(a, b) + elo_expected(b, a) == 1` | `10^x` und `10^-x` sind keine exakten Kehrwerte |
| `symmetric`: `new_a + new_b == old_a + old_b` | `(a + d) + (b - d)` rundet |
| `symmetric`: `new_a - old_a == -(new_b - old_b)` | dieselbe Rundung |
| `individual`: `sum(neu) - sum(alt) == (K_A - K_B) * d` | dito |

Die Drift-Gleichung für `individual` ist die eigentliche Verschärfung: sie legt
die Abweichung exakt fest, statt sie nur zu erlauben. Verschiebt sich etwas an
der Update-Formel oder am K-Faktor, bricht sie genauso zuverlässig wie die
Summenregel im symmetrischen Fall.

**Randverhalten**

- `elo_expected` liegt immer in `[0, 1]` und liefert nie `NaN`. **Am 2026-09-04
  in R 4.6.1 ausgemessen**, nicht geschätzt:

  | Wertungsdifferenz | Ergebnis |
  |---|---|
  | ab 6382 Punkten | exakt `1.0` (darunter `0.99999999999999978`) |
  | ab 123.302 Punkten | exakt `0.0` (darunter `5.59e-309`, subnormal) |
  | `Inf` als Wertung | **abgelehnt** — Eingabefehler, siehe unten |

  Die untere Grenze entsteht durch Rundung auf 1, die obere durch Überlauf von
  `10^x` nach `Inf`. Dazwischen läuft der Wert durch den subnormalen Bereich —
  klein, aber endlich und ohne `NaN`.

  **Für die Tests heißt das:** Grenzwerte deutlich jenseits der Schwelle wählen
  (etwa 7000 und 130.000), nicht knapp daneben. Ein Test genau an der Kante
  prüft die Rundungsregel der Plattform, nicht das Modell.

  **`Inf` wird bei der Eingabeprüfung abgelehnt** — Korrektur gegenüber der
  ersten Fassung dieses Abschnitts. Ein einzelnes unendliches Argument liefert
  zwar sauber `0` oder `1`, aber `elo_expected(Inf, Inf)` rechnet `10^NaN` und
  gibt `NaN` zurück: genau den Wert, den das Paket nie liefern soll. Eine
  unendliche Wertung ist ohnehin keine Wertung. Der Fall ist damit durch
  Validierung ausgeschlossen statt durch Fallunterscheidung in der Formel.
- `elo_k(0)` ist endlich: `250 / 5^0.4 = 131.33`.
- Ungültige Eingaben werfen einen Fehler, nicht `NA`.
- Die Tests vermeiden im Übrigen extreme Eingaben, bei denen
  Wahrscheinlichkeiten auf exakt 0 oder 1 runden — außer in den Randtests selbst.

### 6.2 Eigenschaften über einen Datensatz

Mit synthetischen Fixtures gilt:

```text
es entstehen keine NA- oder unendlichen Wertungen
jeder eingeschlossene Spieler erscheint im Ergebnis
derselbe aufbereitete Input erzeugt zweimal bitgleiche Ergebnisse
eine zufällige Reihenfolge der Rohzeilen ändert das Ergebnis nicht
Duplikat- und Rundencode-Regeln verhalten sich wie dokumentiert
ein Spieler mit ausschließlich Siegen endet über 1500
alle Ausschlusszahlen lassen sich mit der Eingabezeilenzahl abstimmen
```

Je nach Modus zusätzlich:

```text
individual: Mittelwert driftet — keine Invariante, sondern
            im Snapshot mitgeschrieben und zwischen zwei Läufen unverändert
symmetric : Gesamtsumme == 1500 * Spielerzahl        (Toleranz)
            Mittelwert aller Spieler == 1500          (Toleranz)
```

Die Invarianz gegen eine andere Zeilenreihenfolge beruht auf dem vollständigen
Sortierschlüssel aus 4.6. Die Fixtures enthalten deshalb ausdrücklich parallele
Turniere und wiederholte `match_num`-Werte.

### 6.3 Von Hand berechnete Beispiele

Mindestens eine kleine synthetische Matchfolge wird unabhängig von Hand
gerechnet und mit allen erwarteten Zwischenständen abgelegt — je einmal für
`symmetric` und `individual`. Das prüft die Engine direkter als jeder Vergleich
mit einer fremden Rangliste.

### 6.4 Synthetischer Regressions-Snapshot

Eine generierte synthetische Saison dient als goldene Datei. Sie enthält neben
den Wertungen den Mittelwert und die Zahl der Spieler. Änderungen daran müssen
bewusst geprüft werden. Da keine kopierten Quelldaten enthalten sind, wird sie
gemeinsam mit dem MIT-lizenzierten Testcode verteilt.

### 6.5 Optionale externe Validierung

Der Abgleich mit echten Daten liegt außerhalb der regulären Pakettests und der
CI:

- läuft nur, wenn der Nutzer die lizenzierten Quelldaten lokal heruntergeladen
  hat; Referenzliste und Rohdaten stehen in `.gitignore`;
- exakter Datenstichtag und Manifest werden lokal festgehalten;
- der Bericht nennt Spearman-Rangkorrelation der gemeinsamen Spieler, die
  Top-n-Überschneidung und die größten Einzelabweichungen mit Namen;
- die Kennzahlen wandern ins README.

**Als Orientierung, ausdrücklich nicht als Schwelle:** Spearman über 0.90 und
mindestens 15 gemeinsame Spieler in den Top 20 sprechen für eine korrekte
Umsetzung. Sie gelten für `pairing = "individual"` — unter `"symmetric"` sind
größere Abweichungen zu erwarten und kein Fehlersignal, weil die
Vergleichslisten mit individuellen K gerechnet sind. Werden diese Werte
deutlich verfehlt, liegt die Ursache erfahrungsgemäß in der Sortierreihenfolge,
im K-Faktor oder bei den ein- beziehungsweise ausgeschlossenen Spielen.

Exakte Zahlengleichheit ist weder erreichbar noch das Ziel — veröffentlichte
Listen benutzen eigene K-Faktoren, eigene Einschlussregeln und teils
Qualifikationsspiele. Eine Abweichung löst eine Untersuchung aus, beweist aber
keinen Implementierungsfehler. Als Test formuliert würde diese Prüfung die CI an
Datenpflege scheitern lassen statt an Codefehlern. Deshalb Bericht.

---

## 7. Spezifikation der Analyse

`analysis/elo-vs-ranking.qmd` nennt zu Beginn:

- Stichtag der Matchdaten;
- tatsächlich verwendetes ATP-Ranglistendatum;
- eingeschlossene Turnierkategorien;
- Aktivitätsfenster;
- Mindestzahl an Gesamt- und Belagmatches;
- Umgang mit Aufgaben;
- Paarungsregel, Modellparameter und Paketversion;
- Quellenmanifest und Ausschlusszahlen.

Voreinstellungen der Analyse für Version 1:

```text
Datenzeitraum:      1968 bis Stichtag
Turnierkategorien:  G, M, A, F, O — Tour-Level inkl. Olympia,
                    kein Davis Cup, kein Challenger, keine Qualifikation
Paarungsregel:      individual
Stichtag:           der jüngste Turniertag im Datensatz zum Zeitpunkt des Laufs
aktiver Spieler:    mindestens ein eingeschlossenes Match in den letzten 365 Tagen
Gesamtrangliste:    mindestens 20 eingeschlossene Karrierematches
Belagrangliste:     mindestens 10 eingeschlossene Karrierematches auf diesem Belag
Beläge im Bericht:  Hard, Clay, Grass — Carpet nur als historische Fußnote
ATP-Vergleich:      jüngste ATP-Rangliste am oder vor dem Elo-Stichtag
```

Das sind sichtbare Analyseentscheidungen, keine versteckten Paketregeln.

**Zum Stichtag.** „Der jüngste Turniertag im Datensatz" ist die *Regel* für das
Skript. Der daraus tatsächlich gefundene Tag wird als konkretes Datum ins
Manifest und in den Bericht geschrieben und dort eingefroren. Ohne das liefert
derselbe Code in drei Monaten andere Zahlen, und die veröffentlichten Ergebnisse
wären nicht mehr reproduzierbar.

Inhalt:

1. Datenabdeckung und Ausschlussbericht
2. aktuelle Gesamt-Elo-Rangliste
3. aktuelle Rangliste je Belag mit Stichprobengrößen
4. Elo-gegen-ATP-Streudiagramm und Rangkorrelation
5. größte positive und negative Rangabweichungen
6. ausgewählte Spielerverläufe und nicht vorläufige Höchstwerte
7. Sensitivität gegenüber K-Parametern, Paarungsregel, Aktivitätsfenster,
   Mindestmatchschwelle und Einschluss von Aufgaben
8. Grenzen der Aussagekraft

Die Grenzen umfassen ausdrücklich:

- angenäherte Reihenfolge, weil `tourney_date` das Turnierstartdatum ist;
- Abdeckung der verwendeten Turniere und den Einfluss fehlender unterklassiger
  Historie auf Neueinsteiger — Challenger und Qualifikation sind bewusst nicht
  enthalten, weshalb aufstrebende Spieler mit kurzer Tour-Historie bei 1500
  starten statt mit einer erspielten Wertung (Abschnitt 4.5);
- Unsicherheit durch Initialisierung und frühe Bewertungen;
- kleine Stichproben auf Rasen und Teppich;
- fehlende Verletzungs-, Abwesenheits- und Belagmischungs-Korrektur;
- Elo als modellabhängige Schätzung statt objektiver Wahrheit.

Das README enthält die wichtigsten Ergebnisse und zwei bis drei Abbildungen, so
dass jemand die Antwort auf die Fragen aus Abschnitt 1 findet, ohne Code zu
lesen oder auszuführen.

---

## 8. Projektstruktur

```text
tennelo/
├── DESCRIPTION
├── NAMESPACE                       von roxygen2 erzeugt
├── LICENSE                         MIT, nur Code
├── DATA-SOURCES.md                 Quelle, Attribution, Datenlizenzhinweis
├── README.md
├── .gitignore                      data-raw/csv/, reference/, lokale Manifeste,
│                                   .Rproj.user, .Rhistory
├── .Rbuildignore                   ^analysis$, ^data-raw$, ^\.github$,
│                                   ^PLAN-tennelo.*\.md$, ^LICENSE\.md$
├── R/
│   ├── elo_core.R                  elo_expected, elo_k, elo_match_k,
│   │                               elo_delta, elo_update
│   ├── elo_fit.R                   Engine und tennelo_fit-Klasse
│   ├── elo_query.R                 Ratings, Verlauf, Rangliste, Höchstwert
│   ├── matches.R                   Laden, Prüfen, Aufbereiten, Sortieren
│   ├── rankings.R                  ATP-Ranglisten laden, prüfen, vergleichen
│   └── plots.R                     plot_elo_history
├── man/                            von roxygen2 erzeugt
├── tests/
│   ├── testthat.R
│   └── testthat/
│       ├── test-elo-core.R
│       ├── test-match-k.R
│       ├── test-prepare-matches.R
│       ├── test-elo-invariants.R
│       ├── test-rankings.R
│       ├── test-hand-computed.R
│       ├── test-synthetic-snapshot.R
│       └── fixtures/
│           ├── README.md           weist die Fixtures als synthetisch aus
│           ├── matches_synthetic.csv
│           ├── rankings_synthetic.csv
│           └── ratings_expected.csv
├── data-raw/
│   ├── download_matches.R
│   └── download_rankings.R
├── analysis/
│   ├── elo-vs-ranking.qmd
│   └── validate-external.R         optional, braucht lokale lizenzierte Daten
└── .github/workflows/R-CMD-check.yaml
```

Zwei Punkte, die keine Geschmacksfragen sind:

- **`.Rbuildignore` ist nicht optional** — ohne ihn scheitert `R CMD check` an
  `analysis/` und `data-raw/`, und ein sauberer Check steht in der Definition of
  Done.
- **Fixtures liegen unter `tests/testthat/fixtures/`**, nicht unter
  `tests/fixtures/`. Das ist die testthat-Konvention und erspart jedem Zugriff
  den Umweg über `test_path("..", "fixtures", ...)`.

---

## 9. Umsetzungsreihenfolge

### Stufe 0 — Werkzeuge

Auf diesem Rechner ist **kein R installiert**. Zuerst R, dann `devtools`,
`roxygen2`, `testthat`. Ohne lauffähiges R lassen sich die Eigenschaftstests
nicht ausführen — und bei Fließkommazusagen ist genau das Ausführen der Punkt.

### Stufe 1 — Paketgerüst und mathematischer Kern — **erledigt 2026-09-04**

Ergebnis: 65 Tests grün, `R CMD check --as-cran` meldet `Status: OK` (keine
ERROR, WARNING oder NOTE). Werkzeuglücken, die dabei zu schließen waren und
für die CI nicht relevant sind: `libgit2`, `harfbuzz`, `fribidi`, `libtiff`
(R-Paketkette), TinyTeX plus `makeindex` (PDF-Handbuch), `tidy-html5` 5.8
(HTML-Validierung; macOS liefert eine zu alte Version mit).

- Paketstruktur, roxygen2, testthat, `.Rbuildignore`, CI-Workflow
- `elo_expected()`, `elo_k()`, `elo_match_k()`, `elo_delta()`, `elo_update()`
- beide Paarungsregeln
- die Genauigkeitstabelle aus 6.1 als Tests, bitgenau und toleranzbehaftet
- von Hand gerechnete Beispiele (6.3)

Braucht keine Daten und kein Netz.

### Stufe 2 — Matchprüfung und deterministische Aufbereitung — **erledigt 2026-09-04**

`R/matches.R`, 260 Zeilen. Ausschlussbericht, Duplikat- und Rundenlogik,
vollständiger Sortierschlüssel. Synthetische Fixtures mit parallelen Turnieren
und überlappenden `match_num`.

- Schemaprüfung und normalisierte Score-Kennzeichen
- Spieler-ID-Regel, Rundenzuordnung, Duplikatbehandlung, Levelfilter
- vollständiger Sortierschlüssel und Ausschlussbericht
- synthetische Fixtures für Grenzfälle: parallele Turniere, wiederholte
  `match_num`, unbekannte Rundencodes, Walkover, RET, fehlende IDs

### Stufe 3 — Berechnungsengine und Abfrage-API — **erledigt 2026-09-04**

`R/elo_fit.R`, `R/elo_query.R`, `R/plots.R`. Ein Lauf über 182.775 Matches
dauert 3,7 Sekunden. Der Snapshot prüft zusätzlich, ob die Engine die latenten
Stärken der synthetischen Saison zurückgewinnt (Spearman > 0,85) — das ist eine
Korrektheitsaussage, keine reine Regressionsaussage.

- `tennelo_fit`-Objekt und eine gemeinsame Engine
- Wertungen, Verläufe, Höchstwerte, gefilterte Ranglisten
- Gesamt- und Belagmodelle
- Datensatzinvarianten (6.2) und synthetischer Regressions-Snapshot (6.4)

### Stufe 4 — Ranglistendaten und Stichtagsvergleich — **erledigt 2026-09-04**

`R/rankings.R`. Ein Fehler fiel erst beim Rendern auf: `compare_rankings()`
erzeugte zwei Spalten namens `elo_rank`. `print()` verdeckt das, ggplots
Tidy-Eval nicht. Behoben, plus Regressionstest auf doppelte Spaltennamen.

- Ranglistenprüfung und Auswahl des passenden Stichtags
- Diagnose der Verknüpfung über Spieler-IDs
- Korrelation, Top-n-Überschneidung, Rangdifferenzen
- vollständig synthetische End-to-End-Tests

### Stufe 5 — Lokaler Datenworkflow und externe Validierung — **erledigt 2026-09-04**

`data-raw/source.R`, `download_matches.R`, `download_rankings.R`,
`analysis/validate-external.R`, `DATA-SOURCES.md`. Geladen: 59 Match-Dateien
und 8 Ranglistendateien, beide mit Manifest samt SHA-256 und Commit-ID des
Spiegels (`8373358735`).

- Downloadskripte und Provenienzmanifest
- `DATA-SOURCES.md` und Lizenzhinweis im README
- `analysis/validate-external.R`: optionaler Abgleich mit echten Daten,
  außerhalb der CI
- Prüfung der Empfindlichkeit gegenüber Reihenfolge und Ausschlüssen

Hier zeigt sich zum ersten Mal, ob die Umsetzung inhaltlich stimmt.

### Stufe 6 — Beantwortung der Forschungsfragen — **erledigt 2026-09-04**

`analysis/elo-vs-ranking.qmd`, 323 Zeilen, gerendert nach HTML. Quarto ist auf
diesem Rechner nicht installierbar ohne sudo, gerendert wurde deshalb mit
`rmarkdown` — die Chunk-Syntax ist identisch, die Datei bleibt eine gültige
`.qmd`. Ergebnisse im README.

- fester, dokumentierter Analysestichtag
- Gesamt- und Belagranglisten mit Zulassungsregeln
- Vergleich mit der zeitlich passenden ATP-Rangliste
- Sensitivitätsprüfungen und Grenzen der Aussagekraft
- knappe Ergebnisse und Abbildungen im README

---

## 10. Definition of Done für Version 1 — **abgehakt 2026-09-04**

| Kriterium | Stand |
|---|---|
| `R CMD check` lokal ohne Netzwerkzugriff sauber | ✅ `Status: OK`, keine ERROR/WARNING/NOTE |
| CI eingerichtet | ✅ Ubuntu und macOS, `error-on: warning` |
| alle regulären Tests nur auf synthetischen Daten | ✅ 262 Tests, keine echten Daten im Repo |
| beide Paarungsregeln dokumentiert und getestet | ✅ Drift-Gleichung für `individual`, Summenerhaltung für `symmetric` |
| Genauigkeitszusagen getrennt nach bitgenau/toleranzbehaftet | ✅ mit Begründung je Zeile |
| andere Zeilenreihenfolge ändert nichts | ✅ 30 Durchläufe mit zufälliger Permutation |
| alle Ausschlüsse ausgewiesen und abstimmbar | ✅ `182.775 + 16.614 = 199.389` |
| einmal rechnen, mehrfach abfragen | ✅ `tennelo_fit`, ein Lauf in 3,7 s |
| Elo und ATP zu kompatiblen Ständen | ✅ beide 2026-05-25, `same_day = TRUE` |
| README trennt Modell von objektiver Spielstärke | ✅ |
| Code- und Datenlizenz getrennt sichtbar | ✅ MIT vs. CC BY-NC-SA, `DATA-SOURCES.md` |
| Reproduzierbarkeit über Manifest | ✅ SHA-256 je Datei plus Commit-ID |
| Analysestichtag als konkretes Datum festgehalten | ✅ 2026-05-25 im Bericht und Manifest |

### Ergebnis der Forschungsfragen

**Frage 2 — wer wird am höchsten bewertet?** Sinner (2432,9), Alcaraz (2363,5),
Djokovic (2257,0). Je Belag ein anderer Erster: Sinner auf Hard, Alcaraz auf
Clay, Djokovic auf Grass.

**Frage 1 — wo weichen Elo und ATP am stärksten ab?** Spearman 0,715, Top-20-
Überlappung 14 von 20. Die Abweichungen sind nicht zufällig, sondern zerfallen
in zwei Gruppen, die jeweils auf eine **dokumentierte Grenze des Modells**
zurückgehen:

- *Elo weit über ATP* — Kokkinakis (46 vs. 855), Ymer (98 vs. 900), Nishikori
  (34 vs. 703): Rückkehrer nach langer Pause. Die ATP-Wertung verfällt bei
  Nichtteilnahme, die Elo-Wertung bewegt sich gar nicht. Das Modell hat keine
  Abwesenheitskorrektur (Abschnitt 7).
- *ATP weit über Elo* — Quinn (151 vs. 50), Royer (165 vs. 74), Bellucci
  (147 vs. 73): junge Aufsteiger, die ihre Punkte großteils auf Challenger-Ebene
  geholt haben. Genau die in 4.5 benannte Folge der Tour-Level-Beschränkung.

Beide Richtungen bestätigen also die im Plan vorab benannten Einschränkungen,
statt sie zu widerlegen. Der Erstplatzierte ist unter jeder geprüften Variante
derselbe (Paarungsregel, Aufgaben, `k_start` von 150 bis 400).

## 11. Getroffene und offene Entscheidungen

### Getroffen

| # | Frage | Entscheidung |
|---|---|---|
| 1 | Paarungsregel | **`individual`** als Voreinstellung, `symmetric` als Option und in der Sensitivitätstabelle (4.3) |
| 2 | Datenzeitraum | **ab 1968**, vollständig (3.1) |
| 3 | Analysestichtag | **jüngster Turniertag im Datensatz**, als konkretes Datum im Manifest eingefroren (7) |
| 4 | Turnierkategorien | **nur Tour-Level** `G/M/A/F`, kein Davis Cup, kein Challenger, keine Qualifikation, keine Futures (4.5) |
| 6 | Carpet | **im Modell behalten, aus dem Bericht heraus** — keine Carpet-Rangliste aktiver Spieler (4.4, 7) |

Zwei dieser Entscheidungen haben eine bewusst in Kauf genommene Folge, die im
Bericht ausgewiesen wird:

- `individual` lässt den Mittelwert driften. Für einen Vergleich zum selben
  Stichtag ist das folgenlos; für Vergleiche über Epochen hinweg wäre es das
  nicht — die schließt Abschnitt 1 aus.
- Tour-Level ohne Challenger lässt aufstrebende Spieler bei 1500 starten statt
  mit einer erspielten Wertung. Das betrifft ausgerechnet die Gruppe, bei der
  Elo und ATP-Rangliste am stärksten auseinanderlaufen.

### Erledigt am 2026-09-04 — Quellenprüfung

Der Prüfpunkt „Struktur der Ranglistendateien" ist abgearbeitet. Alle drei
Fragen sind beantwortet (3.4):

1. **Spaltennamen** — `ranking_date`, `rank`, `player`, `points`. Wie erwartet.
2. **Gleicher ID-Raum?** — **Ja**, zu 100 % in beiden Richtungen. Der Join kann
   wie geplant über die Spieler-ID gebaut werden. Stufe 4 bleibt unverändert.
3. **Abdeckung und Rhythmus** — montags, 7- oder 14-Tage-Abstand, jüngster Stand
   `2026-06-08`.

Zusätzlich bestätigt: alle 13 Pflichtspalten in allen Stichjahren ab 1968
vorhanden; die neun Rundencodes vollständig erhoben (4.6); Carpet-Verlauf
belegt (4.4).

### Entschieden am 2026-09-04 — die zwei Funde aus der Prüfung

**A. Datenquelle: Archivspiegel.** Sackmanns `tennis_atp` ist offline (3.1).
`Aneeshers/tennis-sackmann-archive` ist vollständig, CC BY-NC-SA ausgewiesen und
Sackmann attribuiert; das Projekt bezieht die Daten von dort. Eine Anfrage beim
Urheber war zwischenzeitlich vorgesehen und wurde verworfen.

Damit sind **alle sechs Stufen unblockiert.** Die Lizenzpflichten bleiben
bestehen und werden über 3.2 und `DATA-SOURCES.md` erfüllt; da ohnehin keine
Daten im Repository landen, ändert sich an der Paketstruktur nichts.

Zwei Punkte, die aus dem Wegfall des Upstreams folgen und im README stehen:

- Der Datenstand ist **eingefroren** — letzter Turniertag 2026-05-25, jüngste
  Rangliste 2026-06-08. Die Analyse ist damit dauerhaft reproduzierbar, aber
  nicht fortschreibbar.
- `data-raw/download_matches.R` und `download_rankings.R` ziehen vom Spiegel und
  halten dessen Commit sowie die SHA-256-Prüfsummen im Manifest fest (3.3). Fällt
  auch der Spiegel weg, ist am Manifest wenigstens nachvollziehbar, womit
  gerechnet wurde.

**B. Olympische Spiele: eingeschlossen.** `tourney_level == "O"` kommt in die
Voreinstellung (4.5).

### Offen

Keine offenen Planentscheidungen.

## 12. Herkunft der Festlegungen

**Aus `PLAN-tennelo-revised.md` übernommen:** zwei präzise Forschungsfragen mit
Stichtag; die epistemische Einschränkung zu Elo; ATP-Ranglistendaten als zweite
Quelle samt `compare_rankings()`; `fit_elo()` und die `tennelo_fit`-Klasse;
`as_of` und `active_within`; Spieler-IDs als Identitätsschlüssel; Duplikat-,
Freilos- und `retirements`-Behandlung; der durchgehende Ausschlussbericht;
`winner_id`/`loser_id` als Tie-Breaker im Sortierschlüssel; ausschließlich
synthetische Fixtures; `DATA-SOURCES.md`, SHA-256-Manifest und Provenienz; die
von Hand gerechneten Beispiele; die Definition of Done.

**Aus `PLAN-tennelo_neu.md` übernommen:** die Trennung bitgenau/toleranzbehaftet
samt Begründung je Zeile; die Drift-Gleichung; das Randverhalten; der
festgelegte Matchumfang `G/M/A/F` ohne Davis Cup mit Begründung; „keine
Gewichtung" als ausdrückliche Festlegung; die schlanken Abhängigkeiten mit
`ggplot2` in `Suggests` und `rlang::check_installed()`; `.Rbuildignore`;
Fixtures unter `tests/testthat/fixtures/`; `elo_delta()` als interne Funktion;
die Begründung für `min_matches`; die Orientierungswerte für den externen
Abgleich; `tourney_date` als Turnierstartdatum; Stufe 0.

**Neu in dieser Fassung:** `pairing` als Parameter statt einer willkürlichen
Entscheidung zwischen den beiden Vorlagen; `elo_match_k(k, k) == k` per
Kurzschluss statt `sqrt(k*k)`; die korrigierten Randwerte (`elo_k(0) = 131.33`
statt der in `_neu` angegebenen 131.0; die am 2026-09-04 in R ausgemessenen
Sättigungsgrenzen 6382 und 123.302 statt der zunächst geschätzten 6400 und
123.200); das Einfrieren des Stichtags im Manifest; die ausgewiesene Folge der
Tour-Level-Beschränkung für Neueinsteiger; die Behandlung von Carpet; die
Abschnitte 11 und 12.

**Wo der Plan von `-revised` abweicht, obwohl er dessen Gerüst nutzt:**
`individual` statt `symmetric` als Voreinstellung. Begründung in 4.3 — die
Verwässerung der Erfahrungsgewichtung trifft unter `symmetric` ausgerechnet die
Topspieler, um die es in Forschungsfrage 2 geht, während die Drift von
`individual` bei einem Vergleich zum selben Stichtag folgenlos bleibt.
