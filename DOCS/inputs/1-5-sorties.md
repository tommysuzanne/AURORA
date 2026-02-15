# Inputs — 1.5 Sorties

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "1.5 - Sorties"
input bool                      IgnoreSL                    = true;                     // Stop Loss - Ignorer
input ENUM_SL_MODE              InpSL_Mode                  = SL_MODE_DEV_POINTS;       // Stop Loss - Mode de Calcul
input int                       InpSL_Points                = 650;                      // Stop Loss - Distance / Déviation (Points)
input int                       InpSL_AtrPeriod             = 14;                       // Stop Loss - Période (ATR)
input double                    InpSL_AtrMult               = 1.0;                      // Stop Loss - Multiplicateur (ATR)
input bool                      TrailingStop                = true;                     // Trailing Stop - Activer
input ENUM_TRAIL_MODE           TrailMode                   = TRAIL_STANDARD;           // Trailing Stop - Mode de Trailing
input double                    TrailingStopLevel           = 50.0;                     // Trailing Stop - Niveau (% du SL)
input int                       TrailFixedPoints            = 100;                      // Trailing Stop - Niveau (Points)
input int                       TrailAtrPeriod              = 14;                       // Trailing Stop - Période (ATR)
input double                    TrailAtrMult                = 2.5;                      // Trailing Stop - Multiplicateur (ATR)
input bool                      InpBE_Enable                = false;                    // Break‑Even — Activer
input ENUM_BE_MODE              InpBE_Mode                  = BE_MODE_RATIO;            // Break‑Even - Mode de déclenchement
input double                    InpBE_Trigger_Ratio         = 1.0;                      // Break‑Even — Déclencheur (Ratio du SL)
input int                       InpBE_Trigger_Pts           = 100;                      // Break‑Even — Déclencheur (Points fixes)
input double                    InpBE_Offset_SpreadMult     = 1.5;                      // Break‑Even — Offset (spread×k) [0–5]
input int                       InpBE_Min_Offset_Pts        = 10;                       // Break‑Even — Offset minimum (points)
input bool                      InpBE_OnNewBar              = true;                     // Break‑Even — Appliquer à la nouvelle bougie uniquement
input int                       InpBE_AtrPeriod             = 14;                       // Break‑Even — Période (ATR)
input double                    InpBE_AtrMultiplier         = 1.0;                      // Break‑Even — Multiplicateur (ATR)
input bool                      CloseOrders                 = false;                    // Clôture Inverse - Activer
input int                       InpClose_ConfirmBars        = 2;                        // Clôture Inverse - Barres de confirmation [1–4]
input bool                      InpExit_OnClose             = false;                    // Anti-Wick - Activer Sortie sur Clôture
input double                    InpExit_HardSL_Multiplier   = 2.0;                      // Anti-Wick - Multiplicateur SL Hard
```

## See also

- Sorties (concepts) : `../strategies/exits.md`
- Sorties intelligentes : `1-6-sorties-intelligentes.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

