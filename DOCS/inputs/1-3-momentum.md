# Inputs — 1.3 Momentum

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "1.3 - Momentum"
input int                       InpKeltner_KamaPeriod       = 10;                       // KAMA - Efficiency Period
input int                       InpKeltner_KamaFast         = 2;                        // KAMA - Fast SC
input int                       InpKeltner_KamaSlow         = 30;                       // KAMA - Slow SC
input int                       InpKeltner_AtrPeriod        = 14;                       // Channel - ATR Period
input double                    InpKeltner_Mult             = 2.5;                      // Channel - Multiplier
input double                    InpKeltner_Min_ER           = 0.3;                      // Channel - Min Efficiency Threshold (Anti-Vibration)
input bool                      InpSmartMom_Enable          = false;                    // Smart Momentum - Activer (Canaux Dynamiques)
input int                       InpSmartMom_Vol_Short       = 10;                       // Smart Momentum - Volatilité Court
input int                       InpSmartMom_Vol_Long        = 100;                      // Smart Momentum - Volatilité Long
input double                    InpSmartMom_MinMult         = 1.5;                      // Smart Momentum - Multiplicateur Min (Calme)
input double                    InpSmartMom_MaxMult         = 5.0;                      // Smart Momentum - Multiplicateur Max (Explosion)
```

## See also

- Index inputs : `index.md`
- Core Momentum : `../strategies/core-momentum.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

