# Inputs

## Objectif

Centraliser la référence des inputs d’Aurora : noms, types, defaults, descriptions, et dépendances (input contract).

## Source-of-truth

- Définition des inputs : `MQL5/Experts/Aurora.mq5` (section `//|   Inputs   |`)
- Contrat / validation : `MQL5/Experts/Aurora.mq5` (fonction `ValidateInputs()`)
- Enums/types : `MQL5/Include/Aurora/aurora_types.mqh`

## Index

- Input contract (refus d’init) : [`input-contract.md`](input-contract.md)
- Dictionnaire (par groupes, même ordre que le code) :
  - [`1-1-entrees.md`](1-1-entrees.md)
  - [`1-2-supertrend.md`](1-2-supertrend.md)
  - [`1-3-momentum.md`](1-3-momentum.md)
  - [`1-4-filtres-entree.md`](1-4-filtres-entree.md)
  - [`1-5-sorties.md`](1-5-sorties.md)
  - [`1-6-sorties-intelligentes.md`](1-6-sorties-intelligentes.md)
  - [`2-1-execution.md`](2-1-execution.md)
  - [`2-2-risque.md`](2-2-risque.md)
  - [`2-3-pyramidage.md`](2-3-pyramidage.md)
  - [`3-1-sessions.md`](3-1-sessions.md)
  - [`3-2-news.md`](3-2-news.md)
  - [`4-1-dashboard.md`](4-1-dashboard.md)
  - [`4-2-logs.md`](4-2-logs.md)
  - [`4-3-simulation.md`](4-3-simulation.md)

## Note “ne pas inventer”

Les descriptions doivent rester factuelles et vérifiables :
- si une description n’est pas confirmable, utiliser `TODO(verify)` ou `TODO(reconcile)` (voir `../style-guide.md`).
