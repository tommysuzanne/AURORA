# Inputs — 1.2 SuperTrend

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "1.2 - SuperTrend"
input int                       CeAtrPeriod                 = 1;                        // Chandelier - Période (ATR)
input double                    CeAtrMult                   = 0.75;                     // Chandelier - Multiplicateur (ATR)
input int                       ZlPeriod                    = 50;                       // ZLSMA - Période (barres)
input bool                      InpAdaptive_Enable          = true;                     // Smart SuperTrend - Activer (Indicateurs Dynamiques)
input int                       InpAdaptive_ER_Period       = 30;                       // Smart SuperTrend - Période d'analyse Efficiency Ratio (Bruit)
input int                       InpAdaptive_ZLS_MinPeriod   = 30;                       // Smart SuperTrend - ZLSMA Min - Période (Marché Rapide)
input int                       InpAdaptive_ZLS_MaxPeriod   = 90;                       // Smart SuperTrend - ZLSMA Max - Période (Marché Range/Bruit)
input double                    InpAdaptive_ZLS_Smooth      = 0.1;                      // Smart SuperTrend - Facteur de lissage Période [0.01-1.0]
input int                       InpAdaptive_Vol_ShortPeriod = 10;                       // Smart SuperTrend - Volatilité ATR Court
input int                       InpAdaptive_Vol_LongPeriod  = 100;                      // Smart SuperTrend - Volatilité ATR Long
input double                    InpAdaptive_CE_BaseMult     = 2.5;                      // Smart SuperTrend - Chandelier Base Multiplicateur
input double                    InpAdaptive_CE_MinMult      = 2.0;                      // Smart SuperTrend - Chandelier Min Mult (Calme)
input double                    InpAdaptive_CE_MaxMult      = 5.0;                      // Smart SuperTrend - Chandelier Max Mult (Explosion)
input double                    InpAdaptive_Vol_Threshold   = 1.2;                      // Smart SuperTrend - Seuil Volatilité (Ratio) pour bascule HA/Prix
input ENUM_SIGNAL_SOURCE        InpSignal_Source            = SIGNAL_SRC_HEIKEN_ASHI;   // Smart SuperTrend - Source du Signal (Correction Lag)
```

## See also

- Index inputs : `index.md`
- Core SuperTrend : `../strategies/core-supertrend.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

