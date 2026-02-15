# Doc gardening (maintenance)

Objectif : garder `DOCS/` fiable et navigable dans le temps.

## Rituel (mensuel ou avant release)

1. Détecter les TODO anciens
   - Chercher `TODO(verify)` et `TODO(reconcile)` dans `DOCS/`.
   - Résoudre ou revalider (sinon, mettre à jour “Last verified”).
2. Détecter les liens cassés
   - Parcourir `DOCS/index.md` puis chaque `*/index.md`.
   - Fixer les liens ou ajouter un TODO.
3. Vérifier les points “source-of-truth”
   - Inputs et contrat : relire `MQL5/Experts/Aurora.mq5` (section Inputs + `ValidateInputs()`).
4. Nettoyer les redondances
   - Déplacer le détail vers les docs atomiques et laisser des résumés + liens.

## Signaux d’alarme

- Un index > ~200 lignes (il devient un monolithe).
- Une doc de workflow sans procédure vérifiable.
- Un fichier qui mélange “architecture”, “inputs” et “runbook” sans séparation.

