# Style guide (DOCS/)

Objectif : docs **agent-centric**, faciles à maintenir, faciles à vérifier.

## Principes

- **Docs atomiques** : un sujet = un fichier; index courts; liens croisés.
- **Progressive disclosure** : index → overview → détails; éviter les “murs de texte”.
- **Structure stable** : noms de fichiers stables; éviter les renames fréquents.
- **Ne pas inventer** : si une info n’est pas dans les sources du repo, créer un TODO explicite.
- **Confidentialité** : ne pas ajouter de formules propriétaires non présentes dans la doc source.

## Liens et chemins

- Tous les chemins mentionnés dans le texte doivent être **relatifs au repo** (ex: `MQL5/Experts/Aurora.mq5`).
- Pour les liens Markdown, utiliser des chemins relatifs qui fonctionnent sur GitHub :
  - Depuis `DOCS/*` vers `MQL5/*` : l’URL est souvent `../MQL5/...`, mais le libellé doit rester `MQL5/...`.

Exemple :

```md
[MQL5/Experts/Aurora.mq5](../MQL5/Experts/Aurora.mq5)
```

## Format TODO (standard)

- `TODO(verify): <ce qui manque> — Comment obtenir: <action concrète>`
- `TODO(reconcile): <divergence doc vs code> — Comment trancher: <fichier + recherche à faire>`

## “Last verified” (docs critiques)

Les docs critiques doivent se terminer par :

```md
## Last verified
Last verified: YYYY-MM-DD — Méthode: <comment on a vérifié>
```

Docs critiques (minimum) :
- `getting-started/install-compile.md`
- `architecture/event-model.md`
- `inputs/input-contract.md`
- `workflows/backtesting.md`

## Gabarit minimal recommandé

```md
# Titre

## Objectif

## Sources
- <fichiers du repo, chemins relatifs>

## Procédure / contenu

## See also
- <liens vers docs atomiques>

## Last verified
Last verified: YYYY-MM-DD — Méthode: ...
```

