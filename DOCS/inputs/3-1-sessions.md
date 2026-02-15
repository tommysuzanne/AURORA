# Inputs — 3.1 Sessions

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` (section Inputs)

## Définition (extrait)

```mql5
input group "3.1 - Sessions"
input bool                      InpSess_EnableTime          = false;                    // Activer la session horaire A
input int                       InpSess_StartHour           = 0;                        // Heure de début [0–23]
input int                       InpSess_StartMin            = 0;                        // Minutes de début [0–59]
input int                       InpSess_EndHour             = 23;                       // Heure de fin [0–23]
input int                       InpSess_EndMin              = 59;                       // Minutes de fin [0–59]
input bool                      InpSess_EnableTimeB         = false;                    // Activer la session horaire B
input int                       InpSess_StartHourB          = 0;                        // Heure de début B [0–23]
input int                       InpSess_StartMinB           = 0;                        // Minutes de début B [0–59]
input int                       InpSess_EndHourB            = 23;                       // Heure de fin B [0–23]
input int                       InpSess_EndMinB             = 59;                       // Minutes de fin B [0–59]
input ENUM_SESSION_CLOSE_MODE   InpSess_CloseMode           = SESS_MODE_OFF;            // Mode de clôture de la session horaire
input double                    InpSess_DelevTargetPct      = 50.0;                     // Allègement - % Volume à conserver
input bool                      InpSess_TradeMon            = true;                     // Trader le lundi
input bool                      InpSess_TradeTue            = true;                     // Trader le mardi
input bool                      InpSess_TradeWed            = true;                     // Trader le mercredi
input bool                      InpSess_TradeThu            = true;                     // Trader le jeudi
input bool                      InpSess_TradeFri            = true;                     // Trader le vendredi
input bool                      InpSess_TradeSat            = false;                    // Trader le samedi
input bool                      InpSess_TradeSun            = false;                    // Trader le dimanche
input bool                      InpSess_CloseRestricted     = false;                    // Fermer positions jours non autorisés
input bool                      InpWeekend_Enable           = false;                    // Fermer positions avant le week‑end
input int                       InpWeekend_BufferMin        = 30;                       // Marge avant fermeture (minutes) [5–120]
input int                       InpWeekend_GapMinHours      = 2;                        // Gap min. week‑end (heures) [2–6]
input int                       InpWeekend_BlockNewBeforeMin  = 30;                     // Bloquer nouvelles entrées avant close (minutes)
input bool                      InpWeekend_ClosePendings    = true;                     // Fermer ordres en attente avant close
input bool                      InpSess_RespectBrokerSessions = true;                   // Respecter les sessions broker
```

## See also

- Weekend guard : `../architecture/internals/weekend-guard.md`

## Last verified
Last verified: 2026-02-15 — Méthode: extrait depuis `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).

