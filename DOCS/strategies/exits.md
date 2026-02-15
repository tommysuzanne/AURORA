# Sorties (SL / Trailing / Break-even / Exit-on-close)

## Source (doc legacy)

`DOCS/legacy/Aurora_Documentation.md` (section “Sorties”).

## Résumé (doc source)

Trailing :
- `TrailingStop` + `TrailMode` (`STANDARD`, `FIXED_POINTS`, `ATR`)
- `TrailingStopLevel` ou `TrailFixedPoints` ou `TrailAtr*` selon le mode.

Break-even :
- `InpBE_*` (ratio, points, ATR) + `InpBE_OnNewBar` pour limiter la variabilité.

Exit-on-close (anti-wick) :
- `InpExit_OnClose` active la logique “sortie sur clôture”.
- `aurora_virtual_stops.mqh` conserve des niveaux virtuels et peut dessiner des repères.

## Inputs

Voir `../inputs/1-5-sorties.md` et `../inputs/1-6-sorties-intelligentes.md`.

