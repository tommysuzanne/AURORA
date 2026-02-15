# Input contract (règles de cohérence)

## Objectif

Documenter les règles de validation exécutées au démarrage. En cas de violation, l’EA :
- logge la liste des violations,
- affiche une alerte,
- **refuse l’initialisation**.

## Source-of-truth

- `MQL5/Experts/Aurora.mq5` : fonction `ValidateInputs()` et messages `RequireInput(..., errors, "...")`.

## Où regarder (debug)

- Chercher `[INPUT-CONTRACT]` dans l’onglet **Experts** (MT5).

## Règles (liste)

Cette liste est extraite des messages `RequireInput(..., errors, "...")` du code.

> Note : un message est une “violation” qui sera loggée sous la forme `[INPUT-CONTRACT][NN] <message>`.

```text
[RISK] Risk non numérique
[SUPER] CeAtrMult non numérique
[MOM] InpKeltner_Mult non numérique
[EXIT] TrailingStopLevel non numérique
[EXIT] TrailAtrMult non numérique
[BE] InpBE_Trigger_Ratio non numérique
[BE] InpBE_Offset_SpreadMult non numérique
[EXIT] InpExit_HardSL_Multiplier non numérique
[ELASTIC] InpElastic_Max_Scale non numérique
[SESSION] InpSess_DelevTargetPct non numérique
[PYRA] TrendScale_VolMult non numérique
[RISK] RiskMode invalide
[HURST] InpHurst_Timeframe invalide
[EXEC] Reverse bool invalide
[BE] InpBE_OnNewBar bool invalide
[EXEC] MultipleOpenPos bool invalide
[PYRA] TrendScale_TrailSync bool invalide
[SESSION] InpSess_CloseRestricted bool invalide
[WEEKEND] InpWeekend_ClosePendings bool invalide
[SESSION] InpSess_RespectBrokerSessions bool invalide
[LOG] InpLog_General bool invalide
[LOG] InpLog_Position bool invalide
[LOG] InpLog_Risk bool invalide
[LOG] InpLog_Session bool invalide
[LOG] InpLog_News bool invalide
[LOG] InpLog_Strategy bool invalide
[LOG] InpLog_Orders bool invalide
[LOG] InpLog_Diagnostic bool invalide
[LOG] InpLog_Simulation bool invalide
[LOG] InpLog_Dashboard bool invalide
[LOG] InpLog_Invariant bool invalide
[LOG] InpLog_IndicatorInternal bool invalide
[EXEC] MagicNumber doit être > 0
[EXEC] TimerInterval doit être dans [1..3600]
[EXEC] InpEntry_Dist_Pts doit être >= 0
[EXEC] InpEntry_Expiration_Sec doit être >= 0
[PRED] InpPredictive_Update_Threshold doit être >= 0
[PRED] InpPredictive_Offset doit être >= 0 en mode POINTS
[PRED] InpPredictive_ATR_Period doit être >= 1 en mode ATR
[PRED] InpPredictive_ATR_Mult doit être > 0 en mode ATR
[EXEC] InpEntry_Dist_Pts doit être > 0 en mode REACTIVE+STOP
[RISK] Risk doit être > 0 en mode FIXED_VOL/MIN_AMOUNT
[RISK] Risk (%) doit être dans ]0..100]
[RISK] InpMaxDailyTrades doit être -1 ou > 0
[RISK] InpMaxLotSize doit être -1 ou > 0
[RISK] InpMaxTotalLots doit être -1 ou > 0
[RISK] SpreadLimit doit être -1 ou > 0
[RISK] SignalMaxGapPts doit être -1 ou > 0
[RISK] Slippage doit être >= 0
[RISK] EquityDrawdownLimit doit être dans [0..100]
[RISK] InpVirtualBalance doit être -1 ou > 0
[RISK] Risk (lot fixe) ne doit pas dépasser InpMaxLotSize
[RISK] InpMaxTotalLots doit être >= InpMaxLotSize
[SUPER] CeAtrPeriod doit être >= 1
[SUPER] CeAtrMult doit être > 0
[SUPER] ZlPeriod doit être >= 2
[SUPER] InpAdaptive_ER_Period doit être >= 2
[SUPER] InpAdaptive_ZLS_MinPeriod doit être >= 2
[SUPER] InpAdaptive_ZLS_MaxPeriod doit être >= MinPeriod
[SUPER] InpAdaptive_ZLS_Smooth doit être dans ]0..1]
[SUPER] InpAdaptive_Vol_ShortPeriod doit être >= 2
[SUPER] InpAdaptive_Vol_LongPeriod doit être > ShortPeriod
[SUPER] InpAdaptive_CE_MinMult doit être > 0
[SUPER] InpAdaptive_CE_MaxMult doit être >= MinMult
[SUPER] InpAdaptive_CE_BaseMult doit être > 0
[SUPER] InpAdaptive_Vol_Threshold doit être > 0
[MOM] InpKeltner_KamaPeriod doit être >= 2
[MOM] InpKeltner_KamaFast doit être >= 1
[MOM] InpKeltner_KamaSlow doit être > KamaFast
[MOM] InpKeltner_AtrPeriod doit être >= 1
[MOM] InpKeltner_Mult doit être > 0
[MOM] InpKeltner_Min_ER doit être dans [-1..1]
[MOM] InpSmartMom_Vol_Short doit être >= 2
[MOM] InpSmartMom_Vol_Long doit être > Vol_Short
[MOM] InpSmartMom_MinMult doit être > 0
[MOM] InpSmartMom_MaxMult doit être >= MinMult
[FILTER] InpStress_VR_Threshold doit être > 0
[FILTER] InpStress_TriggerBars doit être >= 1
[FILTER] InpStress_CooldownBars doit être >= 0
[HURST] InpHurst_Window doit être >= 20
[HURST] InpHurst_Smoothing doit être dans [1..Window-1]
[HURST] InpHurst_Threshold doit être dans ]0..1[
[VWAP] InpVWAP_DevLimit doit être > 0
[KURT] InpKurtosis_Period doit être >= 20
[KURT] InpKurtosis_Threshold doit être >= 0
[TRAP] InpTrap_WickRatio doit être >= 1
[TRAP] InpTrap_MinBodyPts doit être > 0
[SPIKE] InpRegime_Spike_AtrPeriod doit être >= 2
[SPIKE] InpRegime_Spike_MaxAtrMult doit être > 0
[SMOOTH] InpRegime_Smooth_Ticks doit être >= 2
[SMOOTH] InpRegime_Smooth_MaxDevPts doit être > 0
[EXIT] InpSL_Points doit être > 0
[EXIT] InpSL_AtrPeriod doit être >= 2 pour mode ATR
[EXIT] InpSL_AtrMult doit être > 0 pour mode ATR
[TRAIL] TrailingStopLevel doit être dans ]0..100]
[TRAIL] TrailFixedPoints doit être > 0
[TRAIL] TrailAtrPeriod doit être >= 2
[TRAIL] TrailAtrMult doit être > 0
[BE] InpBE_Trigger_Ratio doit être > 0
[BE] InpBE_Trigger_Pts doit être > 0
[BE] InpBE_AtrPeriod doit être >= 2
[BE] InpBE_AtrMultiplier doit être > 0
[BE] InpBE_Offset_SpreadMult doit être dans [0..10]
[BE] InpBE_Min_Offset_Pts doit être >= 0
[CLOSE] InpClose_ConfirmBars doit être dans [1..BuffSize-1]
[EXIT-ON-CLOSE] InpExit_HardSL_Multiplier doit être >= 1.0
[EXIT] IgnoreSL exige TrailingStop ou Exit_OnClose (anti no-stop state)
[ELASTIC] InpElastic_ATR_Short doit être >= 2
[ELASTIC] InpElastic_ATR_Long doit être > ATR_Short
[ELASTIC] InpElastic_Max_Scale doit être >= 1.0
[ELASTIC] Au moins un canal d'application doit être actif
[PYRA] TrendScale_MaxLayers doit être dans [1..20]
[PYRA] TrendScale_StepPts doit être > 0
[PYRA] TrendScale_VolMult doit être > 0
[PYRA] TrendScale_MinConf doit être dans [0..1]
[PYRA] TrendScale_TrailDist_2 doit être > 0
[PYRA] TrendScale_TrailDist_3 doit être > 0
[PYRA] TrailDist_3 doit être <= TrailDist_2
[PYRA] TrendScale_ATR_Period doit être >= 2
[PYRA] TrendScale_ATR_Mult_2 doit être > 0
[PYRA] TrendScale_ATR_Mult_3 doit être > 0
[PYRA] TrendScale_Enable exige MultipleOpenPos=true
[SESSION] InpSess_StartHour doit être dans [0..23]
[SESSION] InpSess_EndHour doit être dans [0..23]
[SESSION] InpSess_StartMin doit être dans [0..59]
[SESSION] InpSess_EndMin doit être dans [0..59]
[SESSION] InpSess_StartHourB doit être dans [0..23]
[SESSION] InpSess_EndHourB doit être dans [0..23]
[SESSION] InpSess_StartMinB doit être dans [0..59]
[SESSION] InpSess_EndMinB doit être dans [0..59]
[SESSION] Fenêtre A invalide: start == end (fenêtre d'1 minute)
[SESSION] Fenêtre B invalide: start == end (fenêtre d'1 minute)
[SESSION] Aucun jour de trading actif alors que OpenNewPos=true
[EXEC] InpGuard_OneTradePerBar exige OpenNewPos=true
[SESSION] InpSess_DelevTargetPct doit être dans ]0..100]
[SESSION] En mode DELEVERAGE, InpSess_DelevTargetPct doit être < 100
[WEEKEND] InpWeekend_BufferMin doit être >= 1
[WEEKEND] InpWeekend_GapMinHours doit être >= 1
[WEEKEND] InpWeekend_BlockNewBeforeMin doit être >= 1
[WEEKEND] InpWeekend_BlockNewBeforeMin doit être <= 1440
[NEWS] InpNews_BlackoutB doit être dans [0..1440]
[NEWS] InpNews_BlackoutA doit être dans [0..1440]
[NEWS] InpNews_MinCoreHighMin doit être dans [0..1440]
[NEWS] InpNews_RefreshMin doit être dans [1..1440]
[NEWS] InpNews_Levels=NONE est incohérent avec InpNews_Enable=true
[NEWS] InpNews_Ccy invalide: <reason>
[NEWS] InpNews_Action doit être MONITOR_ONLY quand InpNews_Enable=false
[DASH] InpDash_NewsRows doit être dans [1..20]
[DASH] InpDash_Scale doit être 0 ou dans [50..300]
[SIM] InpSim_LatencyMs doit être dans [0..10000]
[SIM] InpSim_SpreadPad_Pts doit être >= 0
[SIM] InpSim_Comm_PerLot doit être >= 0
[SIM] InpSim_Slippage_Add doit être >= 0
[SIM] InpSim_Rejection_Prob doit être dans [0..100]
[SIM] InpSim_StartTicket doit être >= VIRTUAL_TICKET_START
```

TODO(verify): régénérer la liste si `ValidateInputs()` change — Comment obtenir: extraire toutes les chaînes `RequireInput(..., errors, ...)` depuis `MQL5/Experts/Aurora.mq5`.

## See also

- Inputs index : `index.md`
- Debugging : `../workflows/debugging.md`

## Last verified
Last verified: 2026-02-15 — Méthode: lecture statique + comparaison avec `MQL5/Experts/Aurora.mq5` (AURORA_VERSION=3.44).
