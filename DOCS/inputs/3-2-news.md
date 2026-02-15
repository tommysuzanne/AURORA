# Inputs — 3.2 Actualités (News)

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "3.2 - Actualités"
input bool                      InpNews_Enable              = true;                     // Activer le filtre d'actualités
input ENUM_NEWS_LEVELS          InpNews_Levels              = NEWS_LEVELS_HIGH_MEDIUM;  // Niveaux bloqués (Aucune/Fortes/Fortes+Moyennes/Toutes)
input string                    InpNews_Ccy                 = "USD";                    // Devises surveillées (vide = auto)
input int                       InpNews_BlackoutB           = 30;                       // Fenêtre avant news (minutes) [0–240]
input int                       InpNews_BlackoutA           = 15;                       // Fenêtre après news (minutes) [0–240]
input int                       InpNews_MinCoreHighMin      = 2;                        // Noyau minimal news fortes (minutes ≥0)
input ENUM_NEWS_ACTION          InpNews_Action              = NEWS_ACTION_MONITOR_ONLY; // Action pendant la fenêtre (Bloquer entrées/gestion/Tout et fermer)
input int                       InpNews_RefreshMin          = 15;                       // Rafraîchissement calendrier (minutes ≥1)
```

## See also

- Internal news : `../architecture/internals/news.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

