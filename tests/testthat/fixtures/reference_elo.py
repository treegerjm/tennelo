"""Unabhaengige Referenzrechnung fuer tennelo.
Bewusst NICHT aus dem R-Code abgeleitet: eigene Implementierung, eigene Sprache.
Erzeugt die Sollwerte fuer tests/testthat/fixtures/ratings_expected.csv
"""
import math

K_START, OFFSET, SHAPE, INITIAL = 250.0, 5.0, 0.4, 1500.0

def elo_k(m):        return K_START / (m + OFFSET) ** SHAPE
def elo_expected(ra, rb): return 1.0 / (1.0 + 10.0 ** ((rb - ra) / 400.0))
def match_k(ka, kb): return ka if ka == kb else math.sqrt(ka * kb)

# Match-Folge: (Sieger, Verlierer). Deckt ab:
#   1  beide neu            -> K_a == K_b, beide Modi identisch
#   2  ungleiches K         -> Modi laufen auseinander
#   3  Favorit gewinnt      -> kleines delta
#   4  Ueberraschung        -> grosses delta
#   5  a repeated pairing, with both counters advanced
SEQ = [("A","B"), ("C","A"), ("A","B"), ("B","C"), ("C","A")]

def run(pairing):
    r = {p: INITIAL for p in "ABC"}
    n = {p: 0 for p in "ABC"}
    out = []
    for i, (w, l) in enumerate(SEQ, 1):
        ka, kb = elo_k(n[w]), elo_k(n[l])
        e = elo_expected(r[w], r[l])
        d = 1.0 - e
        if pairing == "individual":
            dw, dl = ka * d, -kb * d
        else:
            km = match_k(ka, kb)
            dw, dl = km * d, -km * d
        before = r[w] + r[l]
        r[w] += dw; r[l] += dl
        n[w] += 1;  n[l] += 1
        out.append(dict(match=i, winner=w, loser=l, k_w=ka, k_l=kb, e_w=e, d=d,
                        w_new=r[w], l_new=r[l], drift=(r[w]+r[l]) - before))
    return out, r, n

for mode in ("individual", "symmetric"):
    rows, r, n = run(mode)
    print(f"=== pairing = {mode} ===")
    print(f"{'#':>2} {'S':>2} {'V':>2} {'K_S':>10} {'K_V':>10} {'E_S':>9} "
          f"{'Sieger neu':>14} {'Verlierer neu':>14} {'Drift':>9}")
    for x in rows:
        print(f"{x['match']:>2} {x['winner']:>2} {x['loser']:>2} {x['k_w']:>10.6f} "
              f"{x['k_l']:>10.6f} {x['e_w']:>9.6f} {x['w_new']:>14.9f} "
              f"{x['l_new']:>14.9f} {x['drift']:>+9.6f}")
    print(f"   Endstand : " + "  ".join(f"{p}={r[p]:.9f}({n[p]})" for p in "ABC"))
    print(f"   Summe    : {sum(r.values()):.9f}   (Start 4500)")
    print(f"   Mittel   : {sum(r.values())/3:.9f}\n")
