# Exec-plan (quand créer un plan)

## Objectif

Définir quand un agent doit écrire un “exec-plan” avant de modifier le code.

## Créer un plan quand

- Modification d’inputs, enums, ou du contrat d’inputs (`ValidateInputs()`).
- Modification de l’architecture (wiring des modules, modèle événementiel).
- Changements sur exécution (async manager, predictive/reactive) ou sur guards (session/weekend/news).
- Changement de compatibilité (ressources `#resource`, indicateurs `.ex5`).

## Contenu minimal d’un exec-plan

- But + critères de succès.
- Fichiers impactés (chemins repo).
- Risques (live/backtest).
- Stratégie de tests (compilation, backtest, logs).
- Mise à jour doc requise (`DOCS/*` + `MQL5/README.md` si pointeurs).

