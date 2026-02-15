# Core — SuperTrend

## Source (doc legacy)

`DOCS/legacy/Aurora_Documentation.md` (section “Core SuperTrend”).

## Résumé

Composants :
- `Chandelier Exit` (ATR) pour le contexte tendance,
- `ZLSMA` comme filtre directionnel,
- source de signal configurable (`InpSignal_Source`) : Heiken Ashi, prix réel, adaptatif.

Mode adaptatif (`InpAdaptive_*`) :
- fait varier la sensibilité (période ZLSMA et/ou multiplicateur CE) selon des mesures de bruit/volatilité.

## Inputs

Voir `../inputs/1-2-supertrend.md`.

