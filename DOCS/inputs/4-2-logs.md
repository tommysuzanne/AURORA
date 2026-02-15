# Inputs — 4.2 Logs

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "4.2 - Logs"
input bool                      InpLog_General              = false;                    // Journaux généraux (init, erreurs)
input bool                      InpLog_Position             = false;                    // Positions (ouvertures/fermetures auto)
input bool                      InpLog_Risk                 = false;                    // Gestion du risque (equity/DD/volumes)
input bool                      InpLog_Session              = false;                    // Sessions (hors news)
input bool                      InpLog_News                 = false;                    // News & calendrier économique
input bool                      InpLog_Strategy             = false;                    // Stratégie/Signaux
input bool                      InpLog_Orders               = false;                    // Trading/ordres (retcodes)
input bool                      InpLog_Diagnostic           = false;                    // Diagnostic technique (buffers, indicateurs)
input bool                      InpLog_Simulation           = false;                    // Simulation (Ordres virtuels/Rejets)
input bool                      InpLog_Dashboard            = false;                    // Dashboard (Interface/Rendu)
input bool                      InpLog_Invariant            = false;                    // Invariants runtime (new-exposure guard)
input bool                      InpLog_IndicatorInternal    = false;                    // Logs internes des indicateurs iCustom
```

## See also

- Debugging : `../workflows/debugging.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

