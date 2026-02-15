# Inputs — 1.4 Filtres d’Entrée

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "1.4 - Filtres d'Entrée"
input bool                      InpStress_Enable            = false;                    // Smart Filters - Activer
input double                    InpStress_VR_Threshold      = 1.5;                      // Smart Filters - Seuil Volatilité Ratio
input int                       InpStress_TriggerBars       = 3;                        // Smart Filters - Barres Confirm
input int                       InpStress_CooldownBars      = 10;                       // Smart Filters - Cooldown (barres)
input bool                      InpHurst_Enable             = false;                    // Structure - HURST - Activer
input double                    InpHurst_Threshold          = 0.55;                     // Structure - HURST - Seuil Chaos
input ENUM_TIMEFRAMES           InpHurst_Timeframe          = PERIOD_M1;                // Structure - HURST - Timeframe
input int                       InpHurst_Window             = 100;                      // Structure - HURST - Fenêtre (bars)
input int                       InpHurst_Smoothing          = 5;                        // Structure - HURST - Lissage (WMA)
input bool                      InpVWAP_Enable              = false;                    // Structure - VWAP - Activer
input double                    InpVWAP_DevLimit            = 3.0;                      // Structure - VWAP - Déviation Max
input bool                      InpKurtosis_Enable          = false;                    // Structure - Kurtosis - Activer
input double                    InpKurtosis_Threshold       = 1.5;                      // Structure - Kurtosis - Seuil Excess [0.5-5.0]
input int                       InpKurtosis_Period          = 100;                      // Structure - Kurtosis - Période [50-500]
input bool                      InpTrap_Enable              = false;                    // Structure - Trap Candle - Activer (Anti Stop-Hunt)
input double                    InpTrap_WickRatio           = 2.0;                      // Structure - Trap Candle - Ratio Wick/Body Min [2.0-5.0]
input int                       InpTrap_MinBodyPts          = 50;                       // Structure - Trap Candle - Body Min (Points) [10-100]
input bool                      InpRegime_Spike_Enable      = false;                    // Urgence - Spike Guard - Activer (Anti-Crash)
input double                    InpRegime_Spike_MaxAtrMult  = 4.0;                      // Urgence - Spike Guard - Seuil ATR (Bougie > x*ATR)
input int                       InpRegime_Spike_AtrPeriod   = 14;                       // Urgence - Spike Guard - Période ATR
input bool                      InpRegime_FatTail_Enable    = false;                    // Urgence - Fat Tail Guard - Mode Prédictif "OnBar" (Anti-Chasse)
input bool                      InpRegime_Smooth_Enable     = false;                    // Urgence - Whistle-Clean - Activer Lissage Prix
input int                       InpRegime_Smooth_Ticks      = 5;                        // Urgence - Whistle-Clean - Ticks Moyenne [3-10]
input int                       InpRegime_Smooth_MaxDevPts  = 100;                      // Urgence - Whistle-Clean - Déviation Max Sécurité (Points)
```

## See also

- Guards & filtres : `../strategies/guards-regime-filters.md`
- Indicateurs internes : `../architecture/indicators.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

