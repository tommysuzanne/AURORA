# Vue d’ensemble (architecture)

## Objectif

Décrire l’architecture d’Aurora (EA MQL5) sans divulguer de formules propriétaires.

## Résumé (depuis la doc source)

Aurora est un EA MQL5 **événementiel** et **modulaire**, conçu pour :
- être rapide sur le chemin critique (`OnTick`) via cache/snapshot et calculs regroupés,
- être robuste en production via une pipeline de guards (sessions / week-end / news) et un contrat d’inputs,
- être testable via une couche optionnelle de simulation en Strategy Tester (latence / slippage / rejections / spread padding).

## See also

- Modèle événementiel : `event-model.md`
- Modules : `modules.md`
- Workflows backtest : `../workflows/backtesting.md`

