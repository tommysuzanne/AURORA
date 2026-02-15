# Internal — Simulation “reality check” (Strategy Tester)

## Objectif

Décrire la couche de simulation et ce qu’elle modifie (latence, slippage, rejections, spread padding), sans détails propriétaires.

## Source-of-truth

- `MQL5/Include/Aurora/aurora_simulation.mqh`
- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (section “Backtest & simulation réaliste”)

## Résumé (depuis la doc source)

La simulation vise à rendre le Strategy Tester plus conservateur :
- rejets aléatoires (“off quotes”),
- slippage forcé,
- padding de spread,
- latence (Sleep) au déclenchement,
- pendings “virtuels” gérés par l’EA.

Note : activée uniquement si `MQL_TESTER` est vrai.

## See also

- Inputs simulation : `../../inputs/4-3-simulation.md`
- Workflow backtesting : `../../workflows/backtesting.md`

