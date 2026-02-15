# Exécution live (runbook minimal)

## Objectif

Attacher l’EA à un graphique et valider qu’il s’initialise correctement.

## Procédure (haut niveau)

1. Dans MT5, attacher l’EA `Aurora` au graphique.
2. Activer **Algo Trading**.
3. Si l’EA refuse l’initialisation, diagnostiquer via les logs `[INPUT-CONTRACT]`.

## Dépannage

- Si le dashboard n’apparaît pas, vérifier `InpDash_Enable=true` et la compatibilité Canvas.
- Si le filtre news “ne bloque rien”, vérifier `InpNews_Enable` / `InpNews_Levels` / `InpNews_Action`.

## TODOs

- TODO(verify): procédure exacte pour retrouver les logs “Experts” sur MT5 (chemin UI) — Comment obtenir: ouvrir l’onglet *Experts* et noter les étapes UI.

## See also

- Contrat d’inputs : `../inputs/input-contract.md`
- Debugging : `../workflows/debugging.md`

