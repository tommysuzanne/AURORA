# Inputs — 2.2 Risque

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "2.2 - Risque"
input ENUM_RISK                 RiskMode                    = RISK_DEFAULT;             // Mode de risque
input double                    Risk                        = 3;                        // Risque par trade (%/lot selon le mode)
input int                       InpMaxDailyTrades           = -1;                       // Limite de trades par jour (-1 = désactivé)
input double                    InpMaxLotSize               = -1;                       // Lots maximum par position (-1 = désactivé)
input double                    InpMaxTotalLots             = -1;                       // Lots maximum cumulés (-1 = désactivé)
input int                       SpreadLimit                 = -1;                       // Limite de spread (points) (-1 = désactivé)
input int                       Slippage                    = 30;                       // Slippage (points)
input int                       SignalMaxGapPts             = -1;                       // Max écart prix/signal (points) (-1 = désactivé)
input double                    EquityDrawdownLimit         = 0;                        // Limite de drawdown sur l’équity (%) (0 = désactivé)
input double                    InpVirtualBalance           = -1;                       // Solde Virtuel (0 ou -1 = Désactivé)
input bool                      MultipleOpenPos             = true;                     // Autoriser plusieurs positions simultanées
input bool                      OpenNewPos                  = true;                     // Autoriser l’ouverture de nouvelles positions
input bool                      InpGuard_OneTradePerBar     = false;                    // Autoriser une seule entrée par bougie (Anti-Flicker)
```

## See also

- Input contract : `input-contract.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

