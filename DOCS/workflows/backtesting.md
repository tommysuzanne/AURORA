# Backtest & simulation réaliste

## Objectif

Backtester Aurora en tenant compte de la couche optionnelle de simulation (latence / slippage / rejections / spread padding).

## Sources

- Doc legacy : `DOCS/legacy/Aurora_Documentation.md` (sections “Logs & diagnostic”, “Backtest & simulation réaliste”)
- Code : `MQL5/Include/Aurora/aurora_simulation.mqh`, `MQL5/Experts/Aurora.mq5`

## Pourquoi une simulation ?

Le Strategy Tester remplit les ordres trop “parfaitement” (latence quasi nulle, slippage irréaliste).  
La simulation ajoute une couche pour rendre l’exécution plus conservatrice.

## Important

- La simulation est activée uniquement si `MQL_TESTER` est vrai.
- Activer/désactiver via `InpSim_Enable` (voir `../inputs/4-3-simulation.md`).

## Script de tests temporels

Un script de test existe : `MQL5/Scripts/Aurora_Temporal_EdgeTests.mq5`.

## See also

- Internal simulation : `../architecture/internals/simulation.md`
- Debugging : `debugging.md`

## Last verified
Last verified: 2026-02-15 — Méthode: lecture statique + comparaison avec `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

