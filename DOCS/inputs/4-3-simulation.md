# Inputs — 4.3 Backtest (simulation)

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "4.3 - Backtest"
input bool                      InpSim_Enable               = true;                     // Activer la simulation réaliste
input int                       InpSim_LatencyMs            = 25;                       // Latence (ms) (25ms = VPS Rapide)
input int                       InpSim_SpreadPad_Pts        = 10;                       // Marge Bruit Spread (Points)
input double                    InpSim_Comm_PerLot          = 0.0;                      // Commission simulée (hook non branché globalement)
input int                       InpSim_Slippage_Add         = 25;                       // Slippage Forcé (Points)
input int                       InpSim_Rejection_Prob       = 1;                        // Probabilité de rejet d'ordre (%)
input ulong                     InpSim_StartTicket          = 100000;                   // Ticket virtuel de départ
```

## See also

- Backtesting : `../workflows/backtesting.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

