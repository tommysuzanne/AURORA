# Inputs — 2.3 Pyramidage

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "2.3 - Pyramidage"
input bool                      TrendScale_Enable           = false;                    // Activer le pyramidage
input int                       TrendScale_MaxLayers        = 3;                        // Nombre max d'ajouts
input double                    TrendScale_StepPts          = 500;                      // Distance en points pour déclencher un ajout (points)
input double                    TrendScale_VolMult          = 1.0;                      // Multiplicateur de volume pour l'ajout [0.5-2.0]
input double                    TrendScale_MinConf          = 0.8;                      // Score de confiance min requis [0.0-1.0]
input bool                      TrendScale_TrailSync        = true;                     // Activer la syncronisation du SL (Trailing de groupe)
input ENUM_PYRA_TRAIL_MODE      TrendScale_TrailMode        = PYRA_TRAIL_POINTS;        // Mode de Trailing (Points/ATR)
input int                       TrendScale_TrailDist_2      = 300;                      // Distance Trailing (2 couches) (points)
input int                       TrendScale_TrailDist_3      = 150;                      // Distance Trailing (3+ couches) (points)
input int                       TrendScale_ATR_Period       = 14;                       // Période (ATR)
input double                    TrendScale_ATR_Mult_2       = 2.0;                      // Multiplicateur (ATR) (2 couches)
input double                    TrendScale_ATR_Mult_3       = 1.0;                      // Multiplicateur (ATR) (3+ couches)
```

## See also

- Pyramidage (concepts) : `../strategies/pyramiding.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

