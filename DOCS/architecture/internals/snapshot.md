# Internal — Snapshot positions

## Objectif

Expliquer le snapshot positions : cache “once per tick” pour réduire les appels API et fournir des agrégats cohérents.

## Source-of-truth

- `MQL5/Include/Aurora/aurora_snapshot.mqh`
- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (section “Snapshot positions”)

## Résumé

- `Update(magic, symbol)` parcourt `PositionsTotal()` une fois et produit :
  - liste positions filtrées,
  - indices buys/sells,
  - agrégats (profit, volume, exposition nette).
- `OnTradeTransaction` peut invalider le cache après un deal et enrichir un cache commissions.

