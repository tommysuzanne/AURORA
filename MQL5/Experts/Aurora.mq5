//+------------------------------------------------------------------+
//|                                                           Aurora |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright     "Copyright 2026, Tommy Suzanne"
#property link          " https://github.com/tommysuzanne"
#define AURORA_VERSION  "3.44"
#property version       AURORA_VERSION
#property description   "L'avenir appartient à ceux qui comprennent que la vraie économie est solaire : donner sans s'appauvrir."
#property icon          "\\Images\\Aurora_Icon.ico"
#property strict


//+------------------------------------------------------------------+
//|  Includes                                                        |
//+------------------------------------------------------------------+

#include <Aurora/aurora_async_manager.mqh>
CAsyncOrderManager g_asyncManager; // Instance globale
#include <Aurora/aurora_engine.mqh>
#include <Aurora/aurora_constants.mqh>
#include <Aurora/aurora_session_manager.mqh>
#include <Aurora/aurora_weekend_guard.mqh>
#include <Aurora/aurora_newsfilter.mqh>
#include <Aurora/aurora_guard_pipeline.mqh>
#include <Aurora/aurora_types.mqh>
#include <Aurora/aurora_pyramiding.mqh>
#include <Aurora/aurora_snapshot.mqh>
#include <Aurora/aurora_dashboard.mqh>


//+------------------------------------------------------------------+
//|   Inputs                                                         |
//+------------------------------------------------------------------+

input group "1.1 - Entrées"
input ENUM_STRATEGY_CORE        InpStrategy_Core            = STRAT_CORE_SUPER_TREND;   // Mode d'entrée (Super Trend / Momentum)
input bool                      Reverse                     = false;                    // Inverser la direction des signaux (Buy↔Sell)


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

input group "1.6 - Sorties Intelligentes"
input bool                      InpElastic_Enable           = false;                    // Activer Modèle Élastique (Hybrid VR + Noise)
input bool                      InpElastic_Apply_SL         = true;                     // Appliquer au Stop Loss Initial
input bool                      InpElastic_Apply_Trail      = true;                     // Appliquer au Trailing Stop (Distance & Step)
input bool                      InpElastic_Apply_BE         = false;                    // Appliquer au Break-Even (Trigger)
input int                       InpElastic_ATR_Short        = 5;                        // Période ATR Court (Choc)
input int                       InpElastic_ATR_Long         = 100;                      // Période ATR Long (Mémoire)
input double                    InpElastic_Max_Scale        = 2.0;                      // Facteur d'expansion Maximum

input group "2.1 - Éxécution"
input ulong                     MagicNumber                 = 77008866;                 // Numéro magique
input ENUM_ENTRY_STRATEGY       InpEntry_Strategy           = STRATEGY_PREDICTIVE;      // Stratégie d'éxécution (Réactif / Prédictif)
input ENUM_PREDICTIVE_OFFSET_MODE InpPredictive_Offset_Mode = OFFSET_MODE_POINTS;       // Prédictif - Mode Offset (Points / ATR)
input int                       InpPredictive_Offset        = 0;                        // Prédictif - Offset (Points fixes)
input int                       InpPredictive_ATR_Period    = 14;                       // Prédictif - Période (ATR)
input double                    InpPredictive_ATR_Mult      = 0.1;                      // Prédictif - Multiplicateur (ATR)
input int                       InpPredictive_Update_Threshold = 2;                     // Prédictif - Seuil de Mise à jour (Points)
input ENUM_ENTRY_MODE           InpEntry_Mode               = ENTRY_MODE_MARKET;        // Réactif - Mode d'éxécution (Market / Limit / Stop)
input int                       InpEntry_Dist_Pts           = 0;                        // Réactif - Distance d'entrée (Points)
input int                       InpEntry_Expiration_Sec     = 15;                       // Réactif - Expiration Pending Order (Secondes)
input AURORA_OPEN_SIDE          InpOpen_Side                = DIR_BOTH_SIDES;           // Type de positions (Long / Short / Bidirectionnel)
input ENUM_FILLING              Filling                     = FILLING_DEFAULT;          // Type de remplissage des ordres (Auto/FOK/IOC/RETURN)
input int                       TimerInterval               = 1;                        // Intervalle du timer (secondes)

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

input group "3.2 - Actualités"
input bool                      InpNews_Enable              = true;                     // Activer le filtre d'actualités
input ENUM_NEWS_LEVELS          InpNews_Levels              = NEWS_LEVELS_HIGH_MEDIUM;  // Niveaux bloqués (Aucune/Fortes/Fortes+Moyennes/Toutes)
input string                    InpNews_Ccy                 = "USD";                    // Devises surveillées (vide = auto)
input int                       InpNews_BlackoutB           = 30;                       // Fenêtre avant news (minutes) [0–240]
input int                       InpNews_BlackoutA           = 15;                       // Fenêtre après news (minutes) [0–240]
input int                       InpNews_MinCoreHighMin      = 2;                        // Noyau minimal news fortes (minutes ≥0)
input ENUM_NEWS_ACTION          InpNews_Action              = NEWS_ACTION_MONITOR_ONLY; // Action pendant la fenêtre (Bloquer entrées/gestion/Tout et fermer)
input int                       InpNews_RefreshMin          = 15;                       // Rafraîchissement calendrier (minutes ≥1)

input group "4.1 - Dashboard"
input bool                      InpDash_Enable              = false;                    // Activer le Dashboard
input int                       InpDash_NewsRows            = 5;                        // Nombre de lignes de News à afficher
input int                       InpDash_Scale               = 0;                        // Echelle % (0 = Auto DPI)
input ENUM_BASE_CORNER          InpDash_Corner              = CORNER_LEFT_UPPER;        // Coin d'ancrage du dashboard

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

input group "4.3 - Backtest"
input bool                      InpSim_Enable               = true;                     // Activer la simulation réaliste
input int                       InpSim_LatencyMs            = 25;                       // Latence (ms) (25ms = VPS Rapide)
input int                       InpSim_SpreadPad_Pts        = 10;                       // Marge Bruit Spread (Points)
input double                    InpSim_Comm_PerLot          = 0.0;                      // Commission simulée (hook non branché globalement)
input int                       InpSim_Slippage_Add         = 25;                       // Slippage Forcé (Points)
input int                       InpSim_Rejection_Prob       = 1;                        // Probabilité de rejet d'ordre (%)
input ulong                     InpSim_StartTicket          = 100000;                   // Ticket virtuel de départ



const int BuffSize = AURORA_BUFF_SIZE;

GerEA ea;
datetime lastCandle;
datetime tc;
CAuroraSessionManager g_session;
CAuroraWeekendGuard   g_weekend;
CAuroraNewsFilter newsFilter;

CAuroraPyramiding       g_pyramiding;
CAuroraDashboard        g_dashboard;
CAuroraSnapshot         g_snapshot; // Global Position Snapshot (Performance O(1))
SAuroraState            g_state; // State Global

// Stats Globals
double g_max_dd_alltime = 0.0;
double g_max_dd_daily = 0.0;
datetime g_last_stat_day = 0;
// Note: Profit Total calculated on the fly or via history
double g_cache_profit_total = 0.0;
bool   g_history_dirty = true;


string                g_gv_dd_name = ""; // Persistence Key
datetime              g_lastSignalBar = 0; // Guard Global 1-Trade-Per-Bar
datetime              g_lastTradeBar = 0;  // Guard based on confirmed executions
datetime              g_lastTradeTime = 0;
int                   g_daily_trade_count = 0;
datetime              g_daily_trade_day = 0;
datetime              g_lastExposureInvariantBar = 0;
string                g_lastExposureInvariantReason = "";
double                g_trendScaleConfidence = 0.0;

// --- ON-BAR CACHE (Institutional Optimization) ---
struct SCacheOnBar {
   bool   regimeToxic;      // Combined filters (Hurst, Kurtosis)
   string regimeStatus;     // Message for dashboard
   bool   vwapBlockBuy;     // Gravity block Buy
   bool   vwapBlockSell;    // Gravity block Sell
   bool   trapSignal;       // Trap Candle detected
   
   // Metriques Optimisées (OnTick Minimalist)
   double effRatio;         // Efficiency Ratio (Cached)
   double volRatio;         // Volatility Ratio (Cached)
   double noiseFactor;      // Noise Factor (Cached)
   
   // APE Pre-Calculations
   double predBuyPrice;     
   double predSellPrice;    
   double predSL_Buy;
   double predSL_Sell;
   double predVolBuy;
   double predVolSell;
   bool   predictiveLevelsReady;
   
   void Reset() {
      regimeToxic = false;
      regimeStatus = "SAFE";
      vwapBlockBuy = false;
      vwapBlockSell = false;
      trapSignal = false;
      effRatio = 0.0;
      volRatio = 1.0;
      noiseFactor = 1.0;
      predBuyPrice = 0;
      predSellPrice = 0;
      predSL_Buy = 0;
      predSL_Sell = 0;
      predVolBuy = 0;
      predVolSell = 0;
      predictiveLevelsReady = false;
   }
};
SCacheOnBar g_barCache;

void LogExposureInvariantOncePerBar(const string reason, const string source, const bool allowEntryState) {
    datetime bar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (bar <= 0) bar = AuroraClock::Now();
    if (g_lastExposureInvariantBar == bar && g_lastExposureInvariantReason == reason) return;
    g_lastExposureInvariantBar = bar;
    g_lastExposureInvariantReason = reason;
    CAuroraLogger::InfoInvariant(StringFormat("[INVARIANT][NEW-EXPOSURE] BLOCKED reason=%s source=%s OpenNewPos=%s allowEntry=%s",
        reason,
        source,
        (OpenNewPos ? "true" : "false"),
        (allowEntryState ? "true" : "false")));
}

bool IsNewExposureAllowed(const bool allowEntry, const string source) {
    if (OpenNewPos && allowEntry) return true;
    const string reason = (!OpenNewPos ? "OPEN_NEW_POS_DISABLED" : "ENTRY_GUARD_BLOCKED");
    LogExposureInvariantOncePerBar(reason, source, allowEntry);
    return false;
}

datetime ResolveTradeBarFromTime(const datetime tradeTime)
{
    datetime nowBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (tradeTime <= 0) return nowBar;
    int shift = iBarShift(_Symbol, PERIOD_CURRENT, tradeTime, false);
    if (shift < 0) return nowBar;
    datetime bar = iTime(_Symbol, PERIOD_CURRENT, shift);
    if (bar <= 0) return nowBar;
    return bar;
}

// --- VALIDATION HELPERS ---
void AddInputError(string &errors[], const string msg) {
    int n = ArraySize(errors);
    ArrayResize(errors, n + 1);
    errors[n] = msg;
}

void RequireInput(const bool condition, string &errors[], const string msg) {
    if (!condition) AddInputError(errors, msg);
}

bool IsCsvCurrencyListValid(const string raw, string &reason) {
    reason = "";
    if (raw == NULL || raw == "") return true;

    string list = raw;
    StringReplace(list, " ", "");
    StringToUpper(list);

    int start = 0;
    int len = StringLen(list);
    if (len == 0) return true;

    while (true) {
        int pos = StringFind(list, ",", start);
        string token = (pos == -1) ? StringSubstr(list, start) : StringSubstr(list, start, pos - start);
        if (token == "") {
            reason = "devise vide dans la liste";
            return false;
        }
        if (StringLen(token) != 3) {
            reason = StringFormat("devise '%s' invalide (3 lettres attendues)", token);
            return false;
        }
        for (int i = 0; i < 3; i++) {
            int c = StringGetCharacter(token, i);
            if (c < 65 || c > 90) {
                reason = StringFormat("devise '%s' invalide (A-Z attendu)", token);
                return false;
            }
        }
        if (pos == -1) break;
        start = pos + 1;
        if (start >= len) {
            reason = "virgule terminale invalide";
            return false;
        }
    }
    return true;
}

void LogInputScopeWarning(const string msg) {
    CAuroraLogger::WarnDiag("[INPUT-SCOPE][WARN] " + msg);
}

void LogInputScope() {
    const bool predictive = (InpEntry_Strategy == STRATEGY_PREDICTIVE);
    const bool reactive = !predictive;
    const bool superCore = (InpStrategy_Core == STRAT_CORE_SUPER_TREND);

    CAuroraLogger::InfoDiag(StringFormat("[INPUT-SCOPE] Mode Execution=%s | Core=%s",
        (predictive ? "PREDICTIVE" : "REACTIVE"),
        (superCore ? "SUPER_TREND" : "MOMENTUM")));

    if (predictive) {
        CAuroraLogger::InfoDiag("[INPUT-SCOPE][ACTIVE] Predictive: InpPredictive_Update_Threshold, InpEntry_Expiration_Sec");
        if (superCore) {
            CAuroraLogger::InfoDiag("[INPUT-SCOPE][ACTIVE] SuperTrend+Predictive: InpPredictive_Offset_Mode, InpPredictive_Offset, InpPredictive_ATR_Period, InpPredictive_ATR_Mult");
        } else {
            CAuroraLogger::InfoDiag("[INPUT-SCOPE][IGNORED] SuperTrend Predictive offset params ignored with Momentum core");
        }
        CAuroraLogger::InfoDiag("[INPUT-SCOPE][IGNORED] Reactive execution params: InpEntry_Mode, InpEntry_Dist_Pts");
    } else {
        CAuroraLogger::InfoDiag("[INPUT-SCOPE][ACTIVE] Reactive: InpEntry_Mode, InpEntry_Dist_Pts(ENTRY_MODE_STOP), InpEntry_Expiration_Sec(ENTRY_MODE_STOP/LIMIT)");
        CAuroraLogger::InfoDiag("[INPUT-SCOPE][IGNORED] Predictive params: InpPredictive_Offset_Mode, InpPredictive_Offset, InpPredictive_ATR_Period, InpPredictive_ATR_Mult, InpPredictive_Update_Threshold");
    }

    if (superCore) {
        CAuroraLogger::InfoDiag("[INPUT-SCOPE][ACTIVE] SuperTrend: CeAtrPeriod, CeAtrMult, ZlPeriod, InpAdaptive_*, InpSignal_Source(REACTIVE)");
        CAuroraLogger::InfoDiag("[INPUT-SCOPE][IGNORED] Momentum params: InpKeltner_*, InpSmartMom_*");
        if (predictive) {
            CAuroraLogger::InfoDiag("[INPUT-SCOPE][IGNORED] InpSignal_Source ignored in SuperTrend+Predictive");
        }
    } else {
        CAuroraLogger::InfoDiag("[INPUT-SCOPE][ACTIVE] Momentum: InpKeltner_*, InpSmartMom_*");
        CAuroraLogger::InfoDiag("[INPUT-SCOPE][IGNORED] SuperTrend params: CeAtrPeriod, CeAtrMult, ZlPeriod, InpAdaptive_*, InpSignal_Source");
    }

    // Ambiguity warnings: predictive vs reactive
    if (predictive && (InpEntry_Mode != ENTRY_MODE_MARKET || InpEntry_Dist_Pts > 0)) {
        LogInputScopeWarning("InpEntry_Mode / InpEntry_Dist_Pts configurés mais ignorés en mode PREDICTIVE.");
    }
    if (reactive) {
        if (InpPredictive_Update_Threshold != 2 ||
            InpPredictive_Offset_Mode != OFFSET_MODE_POINTS ||
            InpPredictive_Offset != 0 ||
            InpPredictive_ATR_Period != 14 ||
            MathAbs(InpPredictive_ATR_Mult - 0.1) > 1e-12) {
            LogInputScopeWarning("Paramètres Predictive configurés mais ignorés en mode REACTIVE.");
        }
        if (InpEntry_Mode == ENTRY_MODE_MARKET && InpEntry_Expiration_Sec > 0) {
            LogInputScopeWarning("InpEntry_Expiration_Sec n'affecte pas les entrées MARKET en mode REACTIVE.");
        }
    }

    // Ambiguity warnings: core-specific
    if (superCore) {
        if (InpKeltner_KamaPeriod != 10 || InpKeltner_KamaFast != 2 || InpKeltner_KamaSlow != 30 ||
            InpKeltner_AtrPeriod != 14 || MathAbs(InpKeltner_Mult - 2.5) > 1e-12 ||
            MathAbs(InpKeltner_Min_ER - 0.3) > 1e-12 || InpSmartMom_Enable ||
            InpSmartMom_Vol_Short != 10 || InpSmartMom_Vol_Long != 100 ||
            MathAbs(InpSmartMom_MinMult - 1.5) > 1e-12 || MathAbs(InpSmartMom_MaxMult - 5.0) > 1e-12) {
            LogInputScopeWarning("Paramètres Momentum configurés mais ignorés en core SUPER_TREND.");
        }
        if (predictive && InpSignal_Source != SIGNAL_SRC_HEIKEN_ASHI) {
            LogInputScopeWarning("InpSignal_Source configuré mais ignoré en SUPER_TREND+PREDICTIVE.");
        }
    } else {
        if (CeAtrPeriod != 1 || MathAbs(CeAtrMult - 0.75) > 1e-12 || ZlPeriod != 50 ||
            InpAdaptive_Enable || InpAdaptive_ER_Period != 30 || InpAdaptive_ZLS_MinPeriod != 30 ||
            InpAdaptive_ZLS_MaxPeriod != 90 || MathAbs(InpAdaptive_ZLS_Smooth - 0.1) > 1e-12 ||
            InpAdaptive_Vol_ShortPeriod != 10 || InpAdaptive_Vol_LongPeriod != 100 ||
            MathAbs(InpAdaptive_CE_BaseMult - 2.5) > 1e-12 || MathAbs(InpAdaptive_CE_MinMult - 2.0) > 1e-12 ||
            MathAbs(InpAdaptive_CE_MaxMult - 5.0) > 1e-12 || MathAbs(InpAdaptive_Vol_Threshold - 1.2) > 1e-12 ||
            InpSignal_Source != SIGNAL_SRC_HEIKEN_ASHI) {
            LogInputScopeWarning("Paramètres SuperTrend configurés mais ignorés en core MOMENTUM.");
        }
        if (predictive && (InpPredictive_Offset_Mode != OFFSET_MODE_POINTS || InpPredictive_Offset != 0 ||
            InpPredictive_ATR_Period != 14 || MathAbs(InpPredictive_ATR_Mult - 0.1) > 1e-12)) {
            LogInputScopeWarning("Offsets Predictive (SuperTrend) configurés mais ignorés en MOMENTUM+PREDICTIVE.");
        }
    }
}

bool ValidateInputs() {
    string errors[];
    ArrayResize(errors, 0);

    // [MATRIX] Numeric sanity (finite checks)
    RequireInput(MathIsValidNumber(Risk), errors, "[RISK] Risk non numérique");
    RequireInput(MathIsValidNumber(CeAtrMult), errors, "[SUPER] CeAtrMult non numérique");
    RequireInput(MathIsValidNumber(InpKeltner_Mult), errors, "[MOM] InpKeltner_Mult non numérique");
    RequireInput(MathIsValidNumber(TrailingStopLevel), errors, "[EXIT] TrailingStopLevel non numérique");
    RequireInput(MathIsValidNumber(TrailAtrMult), errors, "[EXIT] TrailAtrMult non numérique");
    RequireInput(MathIsValidNumber(InpBE_Trigger_Ratio), errors, "[BE] InpBE_Trigger_Ratio non numérique");
    RequireInput(MathIsValidNumber(InpBE_Offset_SpreadMult), errors, "[BE] InpBE_Offset_SpreadMult non numérique");
    RequireInput(MathIsValidNumber(InpExit_HardSL_Multiplier), errors, "[EXIT] InpExit_HardSL_Multiplier non numérique");
    RequireInput(MathIsValidNumber(InpElastic_Max_Scale), errors, "[ELASTIC] InpElastic_Max_Scale non numérique");
    RequireInput(MathIsValidNumber(InpSess_DelevTargetPct), errors, "[SESSION] InpSess_DelevTargetPct non numérique");
    RequireInput(MathIsValidNumber(TrendScale_VolMult), errors, "[PYRA] TrendScale_VolMult non numérique");

    // [MATRIX] Enum / mode contracts
    switch (InpEntry_Strategy) {
        case STRATEGY_REACTIVE:
        case STRATEGY_PREDICTIVE:
            break;
        default:
            AddInputError(errors, "[EXEC] InpEntry_Strategy invalide");
            break;
    }
    switch (InpStrategy_Core) {
        case STRAT_CORE_SUPER_TREND:
        case STRAT_CORE_MOMENTUM:
            break;
        default:
            AddInputError(errors, "[STRAT] InpStrategy_Core invalide");
            break;
    }
    switch (InpEntry_Mode) {
        case ENTRY_MODE_MARKET:
        case ENTRY_MODE_LIMIT:
        case ENTRY_MODE_STOP:
            break;
        default:
            AddInputError(errors, "[EXEC] InpEntry_Mode invalide");
            break;
    }
    switch (InpPredictive_Offset_Mode) {
        case OFFSET_MODE_POINTS:
        case OFFSET_MODE_ATR:
            break;
        default:
            AddInputError(errors, "[PRED] InpPredictive_Offset_Mode invalide");
            break;
    }
    const bool validRiskMode =
        (RiskMode == RISK_DEFAULT) ||
        (RiskMode == RISK_EQUITY) ||
        (RiskMode == RISK_BALANCE) ||
        (RiskMode == RISK_MARGIN_FREE) ||
        (RiskMode == RISK_MARGIN_PERCENT) ||
        (RiskMode == RISK_CREDIT) ||
        (RiskMode == RISK_FIXED_VOL) ||
        (RiskMode == RISK_MIN_AMOUNT);
    RequireInput(validRiskMode, errors, "[RISK] RiskMode invalide");
    switch (InpSL_Mode) {
        case SL_MODE_DEV_POINTS:
        case SL_MODE_FIXED_POINTS:
        case SL_MODE_DYNAMIC_ATR:
        case SL_MODE_DEV_ATR:
            break;
        default:
            AddInputError(errors, "[EXIT] InpSL_Mode invalide");
            break;
    }
    switch (TrailMode) {
        case TRAIL_STANDARD:
        case TRAIL_FIXED_POINTS:
        case TRAIL_ATR:
            break;
        default:
            AddInputError(errors, "[TRAIL] TrailMode invalide");
            break;
    }
    switch (InpBE_Mode) {
        case BE_MODE_RATIO:
        case BE_MODE_POINTS:
        case BE_MODE_ATR:
            break;
        default:
            AddInputError(errors, "[BE] InpBE_Mode invalide");
            break;
    }
    switch (InpOpen_Side) {
        case DIR_LONG_ONLY:
        case DIR_SHORT_ONLY:
        case DIR_BOTH_SIDES:
            break;
        default:
            AddInputError(errors, "[EXEC] InpOpen_Side invalide");
            break;
    }
    switch (Filling) {
        case FILLING_DEFAULT:
        case FILLING_FOK:
        case FILLING_IOK:
        case FILLING_BOC:
        case FILLING_RETURN:
            break;
        default:
            AddInputError(errors, "[EXEC] Filling invalide");
            break;
    }
    switch (TrendScale_TrailMode) {
        case PYRA_TRAIL_POINTS:
        case PYRA_TRAIL_ATR:
            break;
        default:
            AddInputError(errors, "[PYRA] TrendScale_TrailMode invalide");
            break;
    }
    switch (InpSess_CloseMode) {
        case SESS_MODE_OFF:
        case SESS_MODE_FORCE_CLOSE:
        case SESS_MODE_RECOVERY:
        case SESS_MODE_SMART_EXIT:
        case SESS_MODE_DELEVERAGE:
            break;
        default:
            AddInputError(errors, "[SESSION] InpSess_CloseMode invalide");
            break;
    }
    switch (InpNews_Levels) {
        case NEWS_LEVELS_NONE:
        case NEWS_LEVELS_HIGH_ONLY:
        case NEWS_LEVELS_HIGH_MEDIUM:
        case NEWS_LEVELS_ALL:
            break;
        default:
            AddInputError(errors, "[NEWS] InpNews_Levels invalide");
            break;
    }
    switch (InpNews_Action) {
        case NEWS_ACTION_BLOCK_ENTRIES:
        case NEWS_ACTION_BLOCK_MANAGE:
        case NEWS_ACTION_BLOCK_ALL_CLOSE:
        case NEWS_ACTION_MONITOR_ONLY:
            break;
        default:
            AddInputError(errors, "[NEWS] InpNews_Action invalide");
            break;
    }
    switch (InpSignal_Source) {
        case SIGNAL_SRC_HEIKEN_ASHI:
        case SIGNAL_SRC_REAL_PRICE:
        case SIGNAL_SRC_ADAPTIVE:
            break;
        default:
            AddInputError(errors, "[SUPER] InpSignal_Source invalide");
            break;
    }
    switch (InpDash_Corner) {
        case CORNER_LEFT_UPPER:
        case CORNER_RIGHT_UPPER:
        case CORNER_LEFT_LOWER:
        case CORNER_RIGHT_LOWER:
            break;
        default:
            AddInputError(errors, "[DASH] InpDash_Corner invalide");
            break;
    }
    RequireInput(PeriodSeconds(InpHurst_Timeframe) > 0, errors, "[HURST] InpHurst_Timeframe invalide");
    RequireInput(((int)Reverse == 0 || (int)Reverse == 1), errors, "[EXEC] Reverse bool invalide");
    RequireInput(((int)InpBE_OnNewBar == 0 || (int)InpBE_OnNewBar == 1), errors, "[BE] InpBE_OnNewBar bool invalide");
    RequireInput(((int)MultipleOpenPos == 0 || (int)MultipleOpenPos == 1), errors, "[EXEC] MultipleOpenPos bool invalide");
    RequireInput(((int)TrendScale_TrailSync == 0 || (int)TrendScale_TrailSync == 1), errors, "[PYRA] TrendScale_TrailSync bool invalide");
    RequireInput(((int)InpSess_CloseRestricted == 0 || (int)InpSess_CloseRestricted == 1), errors, "[SESSION] InpSess_CloseRestricted bool invalide");
    RequireInput(((int)InpWeekend_ClosePendings == 0 || (int)InpWeekend_ClosePendings == 1), errors, "[WEEKEND] InpWeekend_ClosePendings bool invalide");
    RequireInput(((int)InpSess_RespectBrokerSessions == 0 || (int)InpSess_RespectBrokerSessions == 1), errors, "[SESSION] InpSess_RespectBrokerSessions bool invalide");
    RequireInput(((int)InpLog_General == 0 || (int)InpLog_General == 1), errors, "[LOG] InpLog_General bool invalide");
    RequireInput(((int)InpLog_Position == 0 || (int)InpLog_Position == 1), errors, "[LOG] InpLog_Position bool invalide");
    RequireInput(((int)InpLog_Risk == 0 || (int)InpLog_Risk == 1), errors, "[LOG] InpLog_Risk bool invalide");
    RequireInput(((int)InpLog_Session == 0 || (int)InpLog_Session == 1), errors, "[LOG] InpLog_Session bool invalide");
    RequireInput(((int)InpLog_News == 0 || (int)InpLog_News == 1), errors, "[LOG] InpLog_News bool invalide");
    RequireInput(((int)InpLog_Strategy == 0 || (int)InpLog_Strategy == 1), errors, "[LOG] InpLog_Strategy bool invalide");
    RequireInput(((int)InpLog_Orders == 0 || (int)InpLog_Orders == 1), errors, "[LOG] InpLog_Orders bool invalide");
    RequireInput(((int)InpLog_Diagnostic == 0 || (int)InpLog_Diagnostic == 1), errors, "[LOG] InpLog_Diagnostic bool invalide");
    RequireInput(((int)InpLog_Simulation == 0 || (int)InpLog_Simulation == 1), errors, "[LOG] InpLog_Simulation bool invalide");
    RequireInput(((int)InpLog_Dashboard == 0 || (int)InpLog_Dashboard == 1), errors, "[LOG] InpLog_Dashboard bool invalide");
    RequireInput(((int)InpLog_Invariant == 0 || (int)InpLog_Invariant == 1), errors, "[LOG] InpLog_Invariant bool invalide");
    RequireInput(((int)InpLog_IndicatorInternal == 0 || (int)InpLog_IndicatorInternal == 1), errors, "[LOG] InpLog_IndicatorInternal bool invalide");

    // [MATRIX] Core ranges
    RequireInput(MagicNumber > 0, errors, "[EXEC] MagicNumber doit être > 0");
    RequireInput(TimerInterval >= AURORA_TIMER_MIN_SEC && TimerInterval <= 3600, errors, "[EXEC] TimerInterval doit être dans [1..3600]");
    RequireInput(InpEntry_Dist_Pts >= 0, errors, "[EXEC] InpEntry_Dist_Pts doit être >= 0");
    RequireInput(InpEntry_Expiration_Sec >= 0, errors, "[EXEC] InpEntry_Expiration_Sec doit être >= 0");
    if (InpEntry_Strategy == STRATEGY_PREDICTIVE) {
        RequireInput(InpPredictive_Update_Threshold >= 0, errors, "[PRED] InpPredictive_Update_Threshold doit être >= 0");
        if (InpPredictive_Offset_Mode == OFFSET_MODE_POINTS) {
            RequireInput(InpPredictive_Offset >= 0, errors, "[PRED] InpPredictive_Offset doit être >= 0 en mode POINTS");
        } else if (InpPredictive_Offset_Mode == OFFSET_MODE_ATR) {
            RequireInput(InpPredictive_ATR_Period >= 1, errors, "[PRED] InpPredictive_ATR_Period doit être >= 1 en mode ATR");
            RequireInput(InpPredictive_ATR_Mult > 0.0, errors, "[PRED] InpPredictive_ATR_Mult doit être > 0 en mode ATR");
        }
    }
    if (InpEntry_Strategy == STRATEGY_REACTIVE && InpEntry_Mode == ENTRY_MODE_STOP) {
        RequireInput(InpEntry_Dist_Pts > 0, errors, "[EXEC] InpEntry_Dist_Pts doit être > 0 en mode REACTIVE+STOP");
    }

    // [MATRIX] Risk contract
    if (RiskMode == RISK_FIXED_VOL || RiskMode == RISK_MIN_AMOUNT) {
        RequireInput(Risk > 0, errors, "[RISK] Risk doit être > 0 en mode FIXED_VOL/MIN_AMOUNT");
    } else {
        RequireInput(Risk > 0 && Risk <= 100, errors, "[RISK] Risk (%) doit être dans ]0..100]");
    }
    RequireInput(InpMaxDailyTrades == -1 || InpMaxDailyTrades > 0, errors, "[RISK] InpMaxDailyTrades doit être -1 ou > 0");
    RequireInput(InpMaxLotSize == -1 || InpMaxLotSize > 0, errors, "[RISK] InpMaxLotSize doit être -1 ou > 0");
    RequireInput(InpMaxTotalLots == -1 || InpMaxTotalLots > 0, errors, "[RISK] InpMaxTotalLots doit être -1 ou > 0");
    RequireInput(SpreadLimit == -1 || SpreadLimit > 0, errors, "[RISK] SpreadLimit doit être -1 ou > 0");
    RequireInput(SignalMaxGapPts == -1 || SignalMaxGapPts > 0, errors, "[RISK] SignalMaxGapPts doit être -1 ou > 0");
    RequireInput(Slippage >= 0, errors, "[RISK] Slippage doit être >= 0");
    RequireInput(EquityDrawdownLimit >= 0.0 && EquityDrawdownLimit <= 100.0, errors, "[RISK] EquityDrawdownLimit doit être dans [0..100]");
    RequireInput(InpVirtualBalance == -1 || InpVirtualBalance > 0, errors, "[RISK] InpVirtualBalance doit être -1 ou > 0");
    if (InpMaxLotSize > 0 && RiskMode == RISK_FIXED_VOL) {
        RequireInput(Risk <= InpMaxLotSize, errors, "[RISK] Risk (lot fixe) ne doit pas dépasser InpMaxLotSize");
    }
    if (InpMaxLotSize > 0 && InpMaxTotalLots > 0) {
        RequireInput(InpMaxTotalLots >= InpMaxLotSize, errors, "[RISK] InpMaxTotalLots doit être >= InpMaxLotSize");
    }

    // [MATRIX] Strategy core: SuperTrend
    if (InpStrategy_Core == STRAT_CORE_SUPER_TREND) {
        RequireInput(CeAtrPeriod >= 1, errors, "[SUPER] CeAtrPeriod doit être >= 1");
        RequireInput(CeAtrMult > 0.0, errors, "[SUPER] CeAtrMult doit être > 0");
        RequireInput(ZlPeriod >= 2, errors, "[SUPER] ZlPeriod doit être >= 2");
        if (InpAdaptive_Enable) {
            RequireInput(InpAdaptive_ER_Period >= 2, errors, "[SUPER] InpAdaptive_ER_Period doit être >= 2");
            RequireInput(InpAdaptive_ZLS_MinPeriod >= 2, errors, "[SUPER] InpAdaptive_ZLS_MinPeriod doit être >= 2");
            RequireInput(InpAdaptive_ZLS_MaxPeriod >= InpAdaptive_ZLS_MinPeriod, errors, "[SUPER] InpAdaptive_ZLS_MaxPeriod doit être >= MinPeriod");
            RequireInput(InpAdaptive_ZLS_Smooth > 0.0 && InpAdaptive_ZLS_Smooth <= 1.0, errors, "[SUPER] InpAdaptive_ZLS_Smooth doit être dans ]0..1]");
            RequireInput(InpAdaptive_Vol_ShortPeriod >= 2, errors, "[SUPER] InpAdaptive_Vol_ShortPeriod doit être >= 2");
            RequireInput(InpAdaptive_Vol_LongPeriod > InpAdaptive_Vol_ShortPeriod, errors, "[SUPER] InpAdaptive_Vol_LongPeriod doit être > ShortPeriod");
            RequireInput(InpAdaptive_CE_MinMult > 0.0, errors, "[SUPER] InpAdaptive_CE_MinMult doit être > 0");
            RequireInput(InpAdaptive_CE_MaxMult >= InpAdaptive_CE_MinMult, errors, "[SUPER] InpAdaptive_CE_MaxMult doit être >= MinMult");
            RequireInput(InpAdaptive_CE_BaseMult > 0.0, errors, "[SUPER] InpAdaptive_CE_BaseMult doit être > 0");
            RequireInput(InpAdaptive_Vol_Threshold > 0.0, errors, "[SUPER] InpAdaptive_Vol_Threshold doit être > 0");
        }
    }

    // [MATRIX] Strategy core: Momentum
    if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
        RequireInput(InpKeltner_KamaPeriod >= 2, errors, "[MOM] InpKeltner_KamaPeriod doit être >= 2");
        RequireInput(InpKeltner_KamaFast >= 1, errors, "[MOM] InpKeltner_KamaFast doit être >= 1");
        RequireInput(InpKeltner_KamaSlow > InpKeltner_KamaFast, errors, "[MOM] InpKeltner_KamaSlow doit être > KamaFast");
        RequireInput(InpKeltner_AtrPeriod >= 1, errors, "[MOM] InpKeltner_AtrPeriod doit être >= 1");
        RequireInput(InpKeltner_Mult > 0.0, errors, "[MOM] InpKeltner_Mult doit être > 0");
        RequireInput(InpKeltner_Min_ER >= -1.0 && InpKeltner_Min_ER <= 1.0, errors, "[MOM] InpKeltner_Min_ER doit être dans [-1..1]");
        if (InpSmartMom_Enable) {
            RequireInput(InpSmartMom_Vol_Short >= 2, errors, "[MOM] InpSmartMom_Vol_Short doit être >= 2");
            RequireInput(InpSmartMom_Vol_Long > InpSmartMom_Vol_Short, errors, "[MOM] InpSmartMom_Vol_Long doit être > Vol_Short");
            RequireInput(InpSmartMom_MinMult > 0.0, errors, "[MOM] InpSmartMom_MinMult doit être > 0");
            RequireInput(InpSmartMom_MaxMult >= InpSmartMom_MinMult, errors, "[MOM] InpSmartMom_MaxMult doit être >= MinMult");
        }
    }

    // [MATRIX] Filters / regime
    if (InpStress_Enable) {
        RequireInput(InpStress_VR_Threshold > 0.0, errors, "[FILTER] InpStress_VR_Threshold doit être > 0");
        RequireInput(InpStress_TriggerBars >= 1, errors, "[FILTER] InpStress_TriggerBars doit être >= 1");
        RequireInput(InpStress_CooldownBars >= 0, errors, "[FILTER] InpStress_CooldownBars doit être >= 0");
    }
    if (InpHurst_Enable || InpStress_Enable) {
        RequireInput(InpHurst_Window >= 20, errors, "[HURST] InpHurst_Window doit être >= 20");
        RequireInput(InpHurst_Smoothing >= 1 && InpHurst_Smoothing < InpHurst_Window, errors, "[HURST] InpHurst_Smoothing doit être dans [1..Window-1]");
        RequireInput(InpHurst_Threshold > 0.0 && InpHurst_Threshold < 1.0, errors, "[HURST] InpHurst_Threshold doit être dans ]0..1[");
    }
    if (InpVWAP_Enable || InpStress_Enable) {
        RequireInput(InpVWAP_DevLimit > 0.0, errors, "[VWAP] InpVWAP_DevLimit doit être > 0");
    }
    if (InpKurtosis_Enable || InpRegime_FatTail_Enable || InpStress_Enable) {
        RequireInput(InpKurtosis_Period >= 20, errors, "[KURT] InpKurtosis_Period doit être >= 20");
        RequireInput(InpKurtosis_Threshold >= 0.0, errors, "[KURT] InpKurtosis_Threshold doit être >= 0");
    }
    if (InpTrap_Enable) {
        RequireInput(InpTrap_WickRatio >= 1.0, errors, "[TRAP] InpTrap_WickRatio doit être >= 1");
        RequireInput(InpTrap_MinBodyPts > 0, errors, "[TRAP] InpTrap_MinBodyPts doit être > 0");
    }
    if (InpRegime_Spike_Enable || InpStress_Enable) {
        RequireInput(InpRegime_Spike_AtrPeriod >= 2, errors, "[SPIKE] InpRegime_Spike_AtrPeriod doit être >= 2");
        RequireInput(InpRegime_Spike_MaxAtrMult > 0.0, errors, "[SPIKE] InpRegime_Spike_MaxAtrMult doit être > 0");
    }
    if (InpRegime_Smooth_Enable) {
        RequireInput(InpRegime_Smooth_Ticks >= 2, errors, "[SMOOTH] InpRegime_Smooth_Ticks doit être >= 2");
        RequireInput(InpRegime_Smooth_MaxDevPts > 0, errors, "[SMOOTH] InpRegime_Smooth_MaxDevPts doit être > 0");
    }

    // [MATRIX] Exit contract
    RequireInput(InpSL_Points > 0, errors, "[EXIT] InpSL_Points doit être > 0");
    if (InpSL_Mode == SL_MODE_DYNAMIC_ATR || InpSL_Mode == SL_MODE_DEV_ATR) {
        RequireInput(InpSL_AtrPeriod >= 2, errors, "[EXIT] InpSL_AtrPeriod doit être >= 2 pour mode ATR");
        RequireInput(InpSL_AtrMult > 0.0, errors, "[EXIT] InpSL_AtrMult doit être > 0 pour mode ATR");
    }
    if (TrailingStop) {
        if (TrailMode == TRAIL_STANDARD) {
            RequireInput(TrailingStopLevel > 0.0 && TrailingStopLevel <= 100.0, errors, "[TRAIL] TrailingStopLevel doit être dans ]0..100]");
        } else if (TrailMode == TRAIL_FIXED_POINTS) {
            RequireInput(TrailFixedPoints > 0, errors, "[TRAIL] TrailFixedPoints doit être > 0");
        } else if (TrailMode == TRAIL_ATR) {
            RequireInput(TrailAtrPeriod >= 2, errors, "[TRAIL] TrailAtrPeriod doit être >= 2");
            RequireInput(TrailAtrMult > 0.0, errors, "[TRAIL] TrailAtrMult doit être > 0");
        }
    }
    if (InpBE_Enable) {
        if (InpBE_Mode == BE_MODE_RATIO) RequireInput(InpBE_Trigger_Ratio > 0.0, errors, "[BE] InpBE_Trigger_Ratio doit être > 0");
        if (InpBE_Mode == BE_MODE_POINTS) RequireInput(InpBE_Trigger_Pts > 0, errors, "[BE] InpBE_Trigger_Pts doit être > 0");
        if (InpBE_Mode == BE_MODE_ATR) {
            RequireInput(InpBE_AtrPeriod >= 2, errors, "[BE] InpBE_AtrPeriod doit être >= 2");
            RequireInput(InpBE_AtrMultiplier > 0.0, errors, "[BE] InpBE_AtrMultiplier doit être > 0");
        }
        RequireInput(InpBE_Offset_SpreadMult >= 0.0 && InpBE_Offset_SpreadMult <= 10.0, errors, "[BE] InpBE_Offset_SpreadMult doit être dans [0..10]");
        RequireInput(InpBE_Min_Offset_Pts >= 0, errors, "[BE] InpBE_Min_Offset_Pts doit être >= 0");
    }
    if (CloseOrders) {
        RequireInput(InpClose_ConfirmBars >= 1 && InpClose_ConfirmBars < BuffSize, errors, "[CLOSE] InpClose_ConfirmBars doit être dans [1..BuffSize-1]");
    }
    if (InpExit_OnClose) {
        RequireInput(InpExit_HardSL_Multiplier >= 1.0, errors, "[EXIT-ON-CLOSE] InpExit_HardSL_Multiplier doit être >= 1.0");
    }
    //if (IgnoreSL) {
    //    RequireInput(TrailingStop || InpExit_OnClose, errors, "[EXIT] IgnoreSL exige TrailingStop ou Exit_OnClose (anti no-stop state)");
    //}

    // [MATRIX] Elastic model dependencies
    if (InpElastic_Enable) {
        RequireInput(InpElastic_ATR_Short >= 2, errors, "[ELASTIC] InpElastic_ATR_Short doit être >= 2");
        RequireInput(InpElastic_ATR_Long > InpElastic_ATR_Short, errors, "[ELASTIC] InpElastic_ATR_Long doit être > ATR_Short");
        RequireInput(InpElastic_Max_Scale >= 1.0, errors, "[ELASTIC] InpElastic_Max_Scale doit être >= 1.0");
        RequireInput(InpElastic_Apply_SL || InpElastic_Apply_Trail || InpElastic_Apply_BE, errors, "[ELASTIC] Au moins un canal d'application doit être actif");
    }

    // [MATRIX] Pyramiding dependencies
    if (TrendScale_Enable) {
        RequireInput(TrendScale_MaxLayers >= 1 && TrendScale_MaxLayers <= 20, errors, "[PYRA] TrendScale_MaxLayers doit être dans [1..20]");
        RequireInput(TrendScale_StepPts > 0.0, errors, "[PYRA] TrendScale_StepPts doit être > 0");
        RequireInput(TrendScale_VolMult > 0.0, errors, "[PYRA] TrendScale_VolMult doit être > 0");
        RequireInput(TrendScale_MinConf >= 0.0 && TrendScale_MinConf <= 1.0, errors, "[PYRA] TrendScale_MinConf doit être dans [0..1]");
        if (TrendScale_TrailMode == PYRA_TRAIL_POINTS) {
            RequireInput(TrendScale_TrailDist_2 > 0, errors, "[PYRA] TrendScale_TrailDist_2 doit être > 0");
            RequireInput(TrendScale_TrailDist_3 > 0, errors, "[PYRA] TrendScale_TrailDist_3 doit être > 0");
            RequireInput(TrendScale_TrailDist_3 <= TrendScale_TrailDist_2, errors, "[PYRA] TrailDist_3 doit être <= TrailDist_2");
        } else if (TrendScale_TrailMode == PYRA_TRAIL_ATR) {
            RequireInput(TrendScale_ATR_Period >= 2, errors, "[PYRA] TrendScale_ATR_Period doit être >= 2");
            RequireInput(TrendScale_ATR_Mult_2 > 0.0, errors, "[PYRA] TrendScale_ATR_Mult_2 doit être > 0");
            RequireInput(TrendScale_ATR_Mult_3 > 0.0, errors, "[PYRA] TrendScale_ATR_Mult_3 doit être > 0");
        }
    }

    // [MATRIX] Cross-system consistency
    if (TrendScale_Enable) {
        RequireInput(MultipleOpenPos, errors, "[PYRA] TrendScale_Enable exige MultipleOpenPos=true");
    }

    // [MATRIX] Session / calendar contract
    RequireInput(InpSess_StartHour >= 0 && InpSess_StartHour <= 23, errors, "[SESSION] InpSess_StartHour doit être dans [0..23]");
    RequireInput(InpSess_EndHour >= 0 && InpSess_EndHour <= 23, errors, "[SESSION] InpSess_EndHour doit être dans [0..23]");
    RequireInput(InpSess_StartMin >= 0 && InpSess_StartMin <= 59, errors, "[SESSION] InpSess_StartMin doit être dans [0..59]");
    RequireInput(InpSess_EndMin >= 0 && InpSess_EndMin <= 59, errors, "[SESSION] InpSess_EndMin doit être dans [0..59]");
    RequireInput(InpSess_StartHourB >= 0 && InpSess_StartHourB <= 23, errors, "[SESSION] InpSess_StartHourB doit être dans [0..23]");
    RequireInput(InpSess_EndHourB >= 0 && InpSess_EndHourB <= 23, errors, "[SESSION] InpSess_EndHourB doit être dans [0..23]");
    RequireInput(InpSess_StartMinB >= 0 && InpSess_StartMinB <= 59, errors, "[SESSION] InpSess_StartMinB doit être dans [0..59]");
    RequireInput(InpSess_EndMinB >= 0 && InpSess_EndMinB <= 59, errors, "[SESSION] InpSess_EndMinB doit être dans [0..59]");
    if (InpSess_EnableTime) {
        bool sameA = (InpSess_StartHour == InpSess_EndHour && InpSess_StartMin == InpSess_EndMin);
        RequireInput(!sameA, errors, "[SESSION] Fenêtre A invalide: start == end (fenêtre d'1 minute)");
    }
    if (InpSess_EnableTimeB) {
        bool sameB = (InpSess_StartHourB == InpSess_EndHourB && InpSess_StartMinB == InpSess_EndMinB);
        RequireInput(!sameB, errors, "[SESSION] Fenêtre B invalide: start == end (fenêtre d'1 minute)");
    }
    if (OpenNewPos) {
        bool anyDay = (InpSess_TradeMon || InpSess_TradeTue || InpSess_TradeWed || InpSess_TradeThu || InpSess_TradeFri || InpSess_TradeSat || InpSess_TradeSun);
        RequireInput(anyDay, errors, "[SESSION] Aucun jour de trading actif alors que OpenNewPos=true");
    }
    if (InpGuard_OneTradePerBar) {
        RequireInput(OpenNewPos, errors, "[EXEC] InpGuard_OneTradePerBar exige OpenNewPos=true");
    }
    RequireInput(InpSess_DelevTargetPct > 0.0 && InpSess_DelevTargetPct <= 100.0, errors, "[SESSION] InpSess_DelevTargetPct doit être dans ]0..100]");
    if (InpSess_CloseMode == SESS_MODE_DELEVERAGE) {
        RequireInput(InpSess_DelevTargetPct < 100.0, errors, "[SESSION] En mode DELEVERAGE, InpSess_DelevTargetPct doit être < 100");
    }
    if (InpWeekend_Enable) {
        RequireInput(InpWeekend_BufferMin >= 1, errors, "[WEEKEND] InpWeekend_BufferMin doit être >= 1");
        RequireInput(InpWeekend_GapMinHours >= 1, errors, "[WEEKEND] InpWeekend_GapMinHours doit être >= 1");
        RequireInput(InpWeekend_BlockNewBeforeMin >= 1, errors, "[WEEKEND] InpWeekend_BlockNewBeforeMin doit être >= 1");
        RequireInput(InpWeekend_BlockNewBeforeMin <= 24 * 60, errors, "[WEEKEND] InpWeekend_BlockNewBeforeMin doit être <= 1440");
    }

    // [MATRIX] News contract
    if (InpNews_Enable) {
        RequireInput(InpNews_BlackoutB >= 0 && InpNews_BlackoutB <= 1440, errors, "[NEWS] InpNews_BlackoutB doit être dans [0..1440]");
        RequireInput(InpNews_BlackoutA >= 0 && InpNews_BlackoutA <= 1440, errors, "[NEWS] InpNews_BlackoutA doit être dans [0..1440]");
        RequireInput(InpNews_MinCoreHighMin >= 0 && InpNews_MinCoreHighMin <= 1440, errors, "[NEWS] InpNews_MinCoreHighMin doit être dans [0..1440]");
        RequireInput(InpNews_RefreshMin >= 1 && InpNews_RefreshMin <= 1440, errors, "[NEWS] InpNews_RefreshMin doit être dans [1..1440]");
        RequireInput(InpNews_Levels != NEWS_LEVELS_NONE, errors, "[NEWS] InpNews_Levels=NONE est incohérent avec InpNews_Enable=true");
        string ccyReason = "";
        RequireInput(IsCsvCurrencyListValid(InpNews_Ccy, ccyReason), errors, "[NEWS] InpNews_Ccy invalide: " + ccyReason);
    }
    if (!InpNews_Enable) {
        RequireInput(InpNews_Action == NEWS_ACTION_MONITOR_ONLY, errors, "[NEWS] InpNews_Action doit être MONITOR_ONLY quand InpNews_Enable=false");
    }

    // [MATRIX] Dashboard contract
    if (InpDash_Enable) {
        RequireInput(InpDash_NewsRows >= 1 && InpDash_NewsRows <= 20, errors, "[DASH] InpDash_NewsRows doit être dans [1..20]");
        RequireInput(InpDash_Scale == 0 || (InpDash_Scale >= 50 && InpDash_Scale <= 300), errors, "[DASH] InpDash_Scale doit être 0 ou dans [50..300]");
    }

    // [MATRIX] Simulation contract
    if (InpSim_Enable) {
        RequireInput(InpSim_LatencyMs >= 0 && InpSim_LatencyMs <= 10000, errors, "[SIM] InpSim_LatencyMs doit être dans [0..10000]");
        RequireInput(InpSim_SpreadPad_Pts >= 0, errors, "[SIM] InpSim_SpreadPad_Pts doit être >= 0");
        RequireInput(InpSim_Comm_PerLot >= 0.0, errors, "[SIM] InpSim_Comm_PerLot doit être >= 0");
        RequireInput(InpSim_Slippage_Add >= 0, errors, "[SIM] InpSim_Slippage_Add doit être >= 0");
        RequireInput(InpSim_Rejection_Prob >= 0 && InpSim_Rejection_Prob <= 100, errors, "[SIM] InpSim_Rejection_Prob doit être dans [0..100]");
        RequireInput(InpSim_StartTicket >= VIRTUAL_TICKET_START, errors, "[SIM] InpSim_StartTicket doit être >= VIRTUAL_TICKET_START");
    }

    if (ArraySize(errors) > 0) {
        PrintFormat("[INPUT-CONTRACT] REFUS INIT: %d violation(s)", ArraySize(errors));
        for (int i = 0; i < ArraySize(errors); ++i) {
            PrintFormat("[INPUT-CONTRACT][%02d] %s", i + 1, errors[i]);
        }
        Alert(StringFormat("AURORA INIT REFUSED: %d violation(s) du contrat inputs. Voir l'onglet Experts.", ArraySize(errors)));
        return false;
    }
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

#define PATH_HA "Indicators\\Aurora\\Heiken_Ashi.ex5"
#define I_HA "::" + PATH_HA
#resource "\\" + PATH_HA
int HA_handle;
double HA_C[];

#define PATH_CE "Indicators\\Aurora\\ChandelierExit.ex5"
#define I_CE "::" + PATH_CE
#resource "\\" + PATH_CE
int CE_handle;
double CE_B[], CE_S[];

#define PATH_ZL "Indicators\\Aurora\\ZLSMA.ex5"
#define I_ZL "::" + PATH_ZL
#resource "\\" + PATH_ZL
int ZL_handle;
double ZL[];



// --- HARDENING RESOURCES ---
#resource "\\Indicators\\Aurora\\Hurst.ex5"
#resource "\\Indicators\\Aurora\\VWAP.ex5"
#define I_HURST "::Indicators\\Aurora\\Hurst.ex5"
#define I_VWAP  "::Indicators\\Aurora\\VWAP.ex5"

int Hurst_handle = INVALID_HANDLE;
double Hurst_Buffer[];
int VWAP_handle  = INVALID_HANDLE;
double VWAP_Buffer[];
double VWAP_Upper[];
double VWAP_Lower[];

// --- KURTOSIS RESOURCES ---
#resource "\\Indicators\\Aurora\\Kurtosis.ex5"
#define I_KURTOSIS "::Indicators\\Aurora\\Kurtosis.ex5"
int Kurtosis_handle = INVALID_HANDLE;
double Kurtosis_Buffer[];

// --- TRAP CANDLE RESOURCES ---
#resource "\\Indicators\\Aurora\\TrapCandle.ex5"
#define I_TRAP "::Indicators\\Aurora\\TrapCandle.ex5"
int Trap_handle = INVALID_HANDLE;
double Trap_Signal[];

#define PATH_AKKE "Indicators\\Aurora\\AuKeltnerKama.ex5"
#define I_AKKE "::" + PATH_AKKE
#resource "\\" + PATH_AKKE
int AKKE_handle = INVALID_HANDLE;
double AKKE_Kama[], AKKE_Up[], AKKE_Dn[], AKKE_Er[];


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// Global Handle for SL ATR (Dynamic Modes)
int g_hSL_ATR = INVALID_HANDLE;

// --- ADAPTIVE STATE VARIABLES ---
double g_adaptive_zlsma_period = 50.0;
double g_adaptive_noise_factor = 1.0; // Market Noise Factor (1.0 = Clean, 2.0 = Noise)
int    g_adaptive_ce_trend = 0; // 0=Init, 1=Long, -1=Short
double g_adaptive_ce_long = 0.0;
double g_adaptive_ce_short = 0.0;

// --- REGIME FILTER GLOBALS ---
double g_regime_ask_buffer[]; // Circular buffer for Smoothing
double g_regime_bid_buffer[];
int    g_regime_tick_idx = 0;   // Current Ring Index
bool   g_regime_buffers_init = false;



// --- STRESS MODE GLOBALS (Adaptive Filter Activation) ---
ENUM_STRESS_STATE g_stress_state = STRESS_STATE_NORMAL;
int      g_stress_confirm_count = 0;   // Bars with high VR
int      g_stress_cooldown_remain = 0; // Cooldown bars remaining
double   g_stress_current_vr = 1.0;    // Current Volatility Ratio
datetime g_stress_last_bar = 0;        // For once-per-bar check

// Compte le nombre de trades (entrées) effectués depuis le début de la journée courante
int GetDailyTradeCount() {
    datetime day = iTime(_Symbol, PERIOD_D1, 0);
    if (day != g_daily_trade_day) {
        g_daily_trade_day = day;
        g_daily_trade_count = 0;
    }
    return g_daily_trade_count;
}

void SeedDailyTradeCount() {
    g_daily_trade_day = iTime(_Symbol, PERIOD_D1, 0);
    g_daily_trade_count = 0;
    g_lastTradeBar = 0;
    g_lastTradeTime = 0;
    
    datetime startOfDay = g_daily_trade_day;
    datetime now = AuroraClock::Now();
    
    if(!HistorySelect(startOfDay, now + 3600)) return;
    
    int total = HistoryDealsTotal();
    datetime latest = 0;
    for(int i = 0; i < total; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != MagicNumber) continue;
        if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
        if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
        
        g_daily_trade_count++;
        datetime dt = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
        if (dt > latest) latest = dt;
    }
    
    if (latest > 0) {
        g_lastTradeTime = latest;
        g_lastTradeBar = ResolveTradeBarFromTime(latest);
        g_lastSignalBar = g_lastTradeBar;
    }
}

void SeedSnapshotCommissions() {
    int total = PositionsTotal();
    for (int i = 0; i < total; i++) {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket)) continue;
        if (PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if (PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        
        long posId = PositionGetInteger(POSITION_IDENTIFIER);
        double comm = 0.0;
        if (HistorySelectByPosition(posId)) {
            int deals = HistoryDealsTotal();
            for (int d = 0; d < deals; d++) {
                ulong dealTicket = HistoryDealGetTicket(d);
                if (dealTicket == 0) continue;
                comm += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                comm += HistoryDealGetDouble(dealTicket, DEAL_FEE);
            }
        }
        g_snapshot.SetCommission(ticket, comm);
    }
}

// Détermine l'exposition actuelle (achats/ventes) de l'EA pour filtrer la suspension Grid
void GetPositionExposure(bool &hasBuys, bool &hasSells) {
    // Optimization: Use Global Snapshot (O(1))
    hasBuys = (g_snapshot.CountBuys() > 0);
    hasSells = (g_snapshot.CountSells() > 0);
}

//+------------------------------------------------------------------+
//| STRESS MODE: State Machine Update                                 |
//| Called once per new bar to check volatility and transition states |
//+------------------------------------------------------------------+
void UpdateStressMode() {
    if (!InpStress_Enable) return;
    
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    if (currentBar == g_stress_last_bar) return; // Once per bar
    g_stress_last_bar = currentBar;
    
    // Calculate Volatility Ratio (VR) = Recent range / Historical range.
    // Recent: bars [1..5], Historical: bars [10..60].
    double atr_recent = 0.0, atr_historical = 0.0;
    double highs[], lows[];
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    const int needBars = 61; // shifts 1..61 available after start=1
    if (CopyHigh(_Symbol, PERIOD_CURRENT, 1, needBars, highs) < needBars ||
        CopyLow(_Symbol, PERIOD_CURRENT, 1, needBars, lows) < needBars) {
        return;
    }

    // Recent window (5 bars): shifts 1..5 -> indices 0..4
    for (int i = 0; i < 5; i++) {
        atr_recent += highs[i] - lows[i];
    }
    atr_recent /= 5.0;

    // Historical window (51 bars): shifts 10..60 -> indices 9..59
    int histCount = 0;
    for (int i = 9; i <= 59; i++) {
        atr_historical += highs[i] - lows[i];
        histCount++;
    }
    if (histCount > 0) atr_historical /= (double)histCount;
    
    // Calculate VR
    g_stress_current_vr = (atr_historical > 0) ? atr_recent / atr_historical : 1.0;
    
    bool vrHigh = (g_stress_current_vr > InpStress_VR_Threshold);
    
    // State Machine
    switch (g_stress_state) {
        case STRESS_STATE_NORMAL:
            if (vrHigh) {
                g_stress_confirm_count = 1;
                g_stress_state = STRESS_STATE_WARNING;
            }
            break;
            
        case STRESS_STATE_WARNING:
            if (vrHigh) {
                g_stress_confirm_count++;
                if (g_stress_confirm_count >= InpStress_TriggerBars) {
                    g_stress_state = STRESS_STATE_ACTIVE;
                    if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                        CAuroraLogger::WarnStrategy(StringFormat("[STRESS MODE] ACTIVÉ! VR=%.2f > %.2f (x%d bars). Filtres forcés.", 
                            g_stress_current_vr, InpStress_VR_Threshold, InpStress_TriggerBars));
                }
            } else {
                // VR normalized, return to normal
                g_stress_confirm_count = 0;
                g_stress_state = STRESS_STATE_NORMAL;
            }
            break;
            
        case STRESS_STATE_ACTIVE:
            if (!vrHigh) {
                g_stress_state = STRESS_STATE_COOLDOWN;
                g_stress_cooldown_remain = InpStress_CooldownBars;
                if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                    CAuroraLogger::InfoStrategy(StringFormat("[STRESS MODE] VR normalisé (%.2f). Cooldown: %d barres.", 
                        g_stress_current_vr, InpStress_CooldownBars));
            }
            break;
            
        case STRESS_STATE_COOLDOWN:
            g_stress_cooldown_remain--;
            if (g_stress_cooldown_remain <= 0) {
                g_stress_state = STRESS_STATE_NORMAL;
                if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                    CAuroraLogger::InfoStrategy("[STRESS MODE] Cooldown terminé. Mode normal rétabli.");
            }
            break;
    }
}

//+------------------------------------------------------------------+
//| Universal Filter Active Check                                     |
//| Returns true if filter is ACTIVE (either by input or Stress Mode) |
//+------------------------------------------------------------------+
bool IsFilterActive(ENUM_FILTER_TYPE filter) {
    // If Stress Mode is ACTIVE, force-enable critical filters
    bool stressForce = (g_stress_state == STRESS_STATE_ACTIVE || g_stress_state == STRESS_STATE_COOLDOWN);
    
    switch (filter) {

        case FILTER_HURST:
            // Stress Mode forces Hurst ON if available
            return (InpHurst_Enable || (stressForce && Hurst_handle != INVALID_HANDLE));
        case FILTER_VWAP:
            // Stress Mode forces VWAP ON if available
            return (InpVWAP_Enable || (stressForce && VWAP_handle != INVALID_HANDLE));
        case FILTER_KURTOSIS:
            // Stress Mode forces Kurtosis ON if available
            return (InpKurtosis_Enable || InpRegime_FatTail_Enable || (stressForce && Kurtosis_handle != INVALID_HANDLE));
        case FILTER_SPIKE:
            // Stress Mode forces Spike Guard ON
            return (InpRegime_Spike_Enable || stressForce);
        case FILTER_TRAP:
            // Trap handled by strategy, not affected by Stress Mode
            return InpTrap_Enable;
        default:
            return false;
    }
}

// Check if we already traded on this bar (Institutional Grade)
// Uses in-memory trade counters updated via OnTradeTransaction
bool HasTradedOnBar(string symbol, ulong magic, datetime barTime) {
    // 1. Fast Cache Check
    if (g_lastSignalBar == barTime) return true;
    if (g_lastTradeBar == barTime) return true;
    return false;
}

// Helpers Phase 1
SSessionInputs MakeSessionInputs() {
    SSessionInputs sess;
    sess.trade_mon = InpSess_TradeMon;
    sess.trade_tue = InpSess_TradeTue;
    sess.trade_wed = InpSess_TradeWed;
    sess.trade_thu = InpSess_TradeThu;
    sess.trade_fri = InpSess_TradeFri;
    sess.trade_sat = InpSess_TradeSat;
    sess.trade_sun = InpSess_TradeSun;
    sess.enable_time_window   = InpSess_EnableTime;
    sess.start_hour           = InpSess_StartHour;
    sess.start_min            = InpSess_StartMin;
    sess.end_hour             = InpSess_EndHour;
    sess.end_min              = InpSess_EndMin;
    sess.enable_time_window_b = InpSess_EnableTimeB;
    sess.start_hour_b         = InpSess_StartHourB;
    sess.start_min_b          = InpSess_StartMinB;
    sess.end_hour_b           = InpSess_EndHourB;
    sess.end_min_b            = InpSess_EndMinB;
    sess.close_mode           = InpSess_CloseMode;
    sess.deleverage_target_pct= InpSess_DelevTargetPct;
    sess.close_restricted_days= InpSess_CloseRestricted;
    sess.respect_broker_sessions = InpSess_RespectBrokerSessions;
    return sess;
}

// --- REGIME HELPERS ---

void UpdateTickBuffer() {
    if (!InpRegime_Smooth_Enable) return;
    
    // Safety Init
    if (!g_regime_buffers_init || ArraySize(g_regime_ask_buffer) != InpRegime_Smooth_Ticks) {
        if (InpRegime_Smooth_Ticks < 1) return;
        ArrayResize(g_regime_ask_buffer, InpRegime_Smooth_Ticks);
        ArrayResize(g_regime_bid_buffer, InpRegime_Smooth_Ticks);
        ArrayInitialize(g_regime_ask_buffer, 0.0);
        ArrayInitialize(g_regime_bid_buffer, 0.0);
        g_regime_buffers_init = true;
        g_regime_tick_idx = 0;
    }
    
    // Circular Push
    double ask = Ask();
    double bid = Bid();
    
    g_regime_ask_buffer[g_regime_tick_idx] = ask;
    g_regime_bid_buffer[g_regime_tick_idx] = bid;
    
    g_regime_tick_idx++;
    if (g_regime_tick_idx >= InpRegime_Smooth_Ticks) g_regime_tick_idx = 0;
}

double GetSmoothedPrice(ENUM_ORDER_TYPE type) {
    // Fallback if disabled or not filled
    double raw = (type == ORDER_TYPE_BUY ? Ask() : Bid());
    
    if (!InpRegime_Smooth_Enable || !g_regime_buffers_init) return raw;
    
    // Calculate Average
    double sum = 0.0;
    int count = 0;
    
    // Use the global buffer directly (no copy needed if we iterate safely)
    for(int i=0; i<InpRegime_Smooth_Ticks; i++) {
        double val = (type == ORDER_TYPE_BUY ? g_regime_ask_buffer[i] : g_regime_bid_buffer[i]);
        if (val > 0) {
            sum += val;
            count++;
        }
    }
    
    if (count == 0) return raw; // Buffer empty (init)
    
    double avg = sum / (double)count;
    
    // Safety Deviation Check (Circuit Breaker)
    // If Smoothing is lagging TOO much behind Real Price (Flash Crash), use Real Price
    if (InpRegime_Smooth_MaxDevPts > 0) {
        double dev = MathAbs(raw - avg);
        if (dev > InpRegime_Smooth_MaxDevPts * _Point) {
            return raw; // Deviation too high, unsafe to use lagged price
        }
    }
    
    return NormalizePrice(avg);
}

SWeekendInputs MakeWeekendInputs() {
    SWeekendInputs w;
    w.enable = InpWeekend_Enable;
    w.buffer_min = InpWeekend_BufferMin;
    w.gap_min_hours = InpWeekend_GapMinHours;
    w.block_before_min = InpWeekend_BlockNewBeforeMin;
    w.close_pendings = InpWeekend_ClosePendings;
    return w;
}

SNewsInputs MakeNewsInputs() {
    SNewsInputs newsParams;
    newsParams.enable = InpNews_Enable;
    newsParams.levels = InpNews_Levels;
    newsParams.currencies = InpNews_Ccy;
    newsParams.blackout_before = MathMax(InpNews_BlackoutB, 0);
    newsParams.blackout_after = MathMax(InpNews_BlackoutA, 0);
    newsParams.min_core_high_min = MathMax(InpNews_MinCoreHighMin, 0);
    newsParams.action = InpNews_Action;
    newsParams.refresh_minutes = (InpNews_RefreshMin <= 0 ? 1 : InpNews_RefreshMin);
    newsParams.log_news = InpLog_News;
    return newsParams;
}



STrendScaleInputs MakeTrendScaleInputs() {
    STrendScaleInputs t;
    t.enable = TrendScale_Enable;
    t.max_layers = TrendScale_MaxLayers;
    t.scaling_step_pts = TrendScale_StepPts;
    t.volume_mult = TrendScale_VolMult;
    t.min_confidence = TrendScale_MinConf;
    t.trailing_sync = TrendScale_TrailSync;
    t.trail_dist_2layers = TrendScale_TrailDist_2;
    t.trail_dist_3layers = TrendScale_TrailDist_3;
    t.trail_mode         = TrendScale_TrailMode;
    t.atr_period         = TrendScale_ATR_Period;
    t.atr_mult_2layers   = TrendScale_ATR_Mult_2;
    t.atr_mult_3layers   = TrendScale_ATR_Mult_3;
    return t;
}



SIndicatorInputs MakeIndicatorInputs() {
    SIndicatorInputs s;
    s.ce_atr_period = CeAtrPeriod;
    s.ce_atr_mult = CeAtrMult;
    s.zl_period = ZlPeriod;
    s.adaptive_vol_threshold = InpAdaptive_Vol_Threshold;
    return s;
}

SRiskInputs MakeRiskInputs() {
    SRiskInputs r;
    r.risk = Risk;
    r.risk_mode = RiskMode;
    r.ignore_sl = IgnoreSL;
    r.trail = TrailingStop;
    r.trailing_stop_level = TrailingStopLevel;
    r.trail_mode = TrailMode;
    r.trail_atr_period = TrailAtrPeriod;
    r.trail_atr_mult = TrailAtrMult;
    r.equity_dd_limit = EquityDrawdownLimit;
    r.max_total_lots = InpMaxTotalLots;
    r.max_lot_size = InpMaxLotSize;
    return r;
}

SOpenInputs MakeOpenInputs() {
    SOpenInputs o;
    o.sl_dev_pts = InpSL_Points; // Utilisé comme fallback ou base pour certains calculs internes
    o.close_orders = CloseOrders;
    o.reverse = Reverse;
    o.open_side = (int)InpOpen_Side;
    o.open_new_pos = OpenNewPos;
    o.multiple_open_pos = MultipleOpenPos;

    o.spread_limit = SpreadLimit;
    o.slippage = Slippage;
    o.timer_interval = TimerInterval;
    o.magic_number = MagicNumber;
    o.filling = Filling;
    o.entry_mode = InpEntry_Mode;
    o.entry_dist_pts = InpEntry_Dist_Pts;
    o.entry_expiration_sec = InpEntry_Expiration_Sec;
    return o;
}

void ConfigureEAFromInputs(const SRiskInputs &rin, const SOpenInputs &oin, const SIndicatorInputs &iin) {
    // 6.7 Exit On Close
    ea.exitOnClose    = InpExit_OnClose;
    ea.exitHardSLMult = InpExit_HardSL_Multiplier;

    ea.Init();
    
    // Safety Checks log
    if (InpExit_OnClose && InpExit_HardSL_Multiplier < 1.0) {
        CAuroraLogger::WarnGeneral("[WARNING] Exit On Close: Hard SL Multiplier < 1.0. Hard SL will be tighter than Virtual SL!");
    }
    ea.SetMagic(oin.magic_number);
    ea.risk = ((rin.risk_mode==RISK_FIXED_VOL || rin.risk_mode==RISK_MIN_AMOUNT) ? rin.risk : rin.risk*0.01);
    ea.reverse = oin.reverse;
    ea.trailingStopLevel = rin.trailing_stop_level * 0.01;
    
    // Configuration Entrées
    ea.entryMode = oin.entry_mode;
    ea.entryDistPts = oin.entry_dist_pts;
    ea.entryExpirationSec = oin.entry_expiration_sec;
    
    ea.maxSpreadLimit = oin.spread_limit;
    
    ea.beMinOffsetPts = InpBE_Min_Offset_Pts;

    ea.equityDrawdownLimit = rin.equity_dd_limit * 0.01;
    ea.slippage = oin.slippage;
    ea.filling = oin.filling;
    ea.riskMode = rin.risk_mode;
    ea.trailMode = TrailMode;
    ea.trailAtrPeriod = TrailAtrPeriod;
    ea.trailAtrMult = TrailAtrMult;
    ea.riskMaxTotalLots = rin.max_total_lots;
    ea.riskMaxLotSize = rin.max_lot_size;
    
    // Config Advanced BE
    ea.beAtrPeriod = InpBE_AtrPeriod;
    ea.beAtrMultiplier = InpBE_AtrMultiplier;
    ea.beMode = InpBE_Mode; // Pass mode to init correct handle

	    // Initialize optimized ATR handle if needed
	    ea.InitATR();
	}

	// Forward declaration (Momentum helpers are defined below)
	bool GetSmartMomentumBands(double &up, double &dn, const int index = 1);

	double ComputeStop(const bool isBuy, const double entry) {
	    // 0. Base Stop Value (Depends on mode)
	    double stop = 0.0;
	    const double dir = (isBuy ? -1.0 : 1.0);
    const int minPts = MinBrokerPoints(_Symbol);
    const double minDist = MathMax((double)minPts, 1.0) * _Point;

	    // Determine "Structure" line (CE or Keltner) for Deviation Modes
	    double structurePrice = 0.0;
	    if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
	        // Never trust indicator buffers blindly (can become INF/NaN); derive bands via unified helper.
	        double up = 0.0, dn = 0.0;
	        if (!GetSmartMomentumBands(up, dn, 1)) return 0.0;
	        structurePrice = (isBuy ? dn : up);
	    } else {
	        structurePrice = (isBuy ? CE_B[1] : CE_S[1]);
	    }

    // --- MODE: DEVIATION FROM STRUCTURE (Points) ---
    if (InpSL_Mode == SL_MODE_DEV_POINTS) {
        if (structurePrice == 0.0 || structurePrice == EMPTY_VALUE) return 0.0;
        stop = structurePrice + dir * InpSL_Points * _Point;
    }
    // --- MODE: DEVIATION FROM STRUCTURE (ATR) ---
    else if (InpSL_Mode == SL_MODE_DEV_ATR) {
        if (structurePrice == 0.0 || structurePrice == EMPTY_VALUE || g_hSL_ATR == INVALID_HANDLE) return 0.0;
        double atrBuf[];
        if(CopyBuffer(g_hSL_ATR, 0, 0, 1, atrBuf) <= 0) return 0.0;
        double dist = atrBuf[0] * InpSL_AtrMult;
        stop = structurePrice + dir * dist;
    }
    // --- MODE: FIXED POINTS FROM ENTRY ---
    else if (InpSL_Mode == SL_MODE_FIXED_POINTS) {
        if (entry <= 0) return 0.0;
        stop = entry + dir * InpSL_Points * _Point;
    }
    // --- MODE: DYNAMIC ATR FROM ENTRY ---
    else if (InpSL_Mode == SL_MODE_DYNAMIC_ATR) {
        if (entry <= 0 || g_hSL_ATR == INVALID_HANDLE) return 0.0;
        double atrBuf[];
        if(CopyBuffer(g_hSL_ATR, 0, 0, 1, atrBuf) <= 0) return 0.0;
        double dist = atrBuf[0] * InpSL_AtrMult;
        stop = entry + dir * dist;
    }

    // --- SAFETY CHECKS ---
    // 1. Min Distance Check
    // 1. Min Distance Check
    double dist = MathAbs(entry - stop);
    if (dist < minDist) stop = entry + (isBuy ? -minDist : minDist);
    
    // 2. Logic Check (Don't allow SL beyond entry for initial stop)
    if (isBuy && stop >= entry) stop = entry - minDist;
    if (!isBuy && stop <= entry) stop = entry + minDist;
    
    return stop;
}

	bool BuildSignalPrices(const bool isBuy, double &entry, double &stop) {
	    entry = (isBuy ? GetSmoothedPrice(ORDER_TYPE_BUY) : GetSmoothedPrice(ORDER_TYPE_SELL));
	    if (entry <= 0) return false;
    
    // Pour les modes basés sur CE, vérifier que CE est valide
	    if (InpStrategy_Core == STRAT_CORE_SUPER_TREND) {
	        if (InpSL_Mode == SL_MODE_DEV_POINTS || InpSL_Mode == SL_MODE_DEV_ATR) {
	            const double ce = (isBuy ? CE_B[1] : CE_S[1]);
	            if (ce == 0.0) return false;
	        }
	    } else {
	        // Momentum: Validate bands (avoid INF/NaN / empty values)
	        double up = 0.0, dn = 0.0;
	        if (!GetSmartMomentumBands(up, dn, 1)) return false;
	        const double oppBand = (isBuy ? dn : up);
	        if (!MathIsValidNumber(oppBand) || oppBand <= 0.0 || oppBand == EMPTY_VALUE) return false;
	    }
	    
	    stop = ComputeStop(isBuy, entry);
	    if (stop <= 0.0) return false;
	    return true;
	}

	// Helper: Calculate Smart Momentum Bands (Unified Logic)
	// Returns true if calculation succeeded
	bool GetSmartMomentumBands(double &up, double &dn, const int index = 1) {
	    // 1. Base KAMA (Center)
	    // Ensure buffer has data
	    if (index >= ArraySize(AKKE_Kama)) return false;
	    double kama = AKKE_Kama[index];
	    if (!MathIsValidNumber(kama) || kama <= 0.0 || kama == EMPTY_VALUE) return false;
	    
	    // 2. Determine Multiplier
	    double mult = InpKeltner_Mult; // Default Static
	    
	    if (InpSmartMom_Enable) {
	        // Dynamic Calculation
	        // Dynamic Calculation (Cached)
	        double vr = g_barCache.volRatio;
	        if (!MathIsValidNumber(vr) || vr <= 0.0) vr = 1.0;
	        
	        // Linear Scaling
	        mult = InpSmartMom_MinMult * vr;
	        if (mult > InpSmartMom_MaxMult) mult = InpSmartMom_MaxMult;
	        if (mult < InpSmartMom_MinMult) mult = InpSmartMom_MinMult;
	    }
	    
	    // 3. Compute Bands
	    // Best practice: never rely on 3rd-party/buffered band outputs for trading decisions.
	    // Compute bands from KAMA + ATR here to guarantee finite values and keep Smart/Static consistent.
	    double atr = CalculateATR(_Symbol, InpKeltner_AtrPeriod, index);
	    if (!MathIsValidNumber(atr) || atr <= 0.0) return false;
	    
	    double dist = atr * mult;
	    if (!MathIsValidNumber(dist) || dist <= 0.0) return false;
	    
	    up = kama + dist;
	    dn = kama - dist;
	    if (!MathIsValidNumber(up) || !MathIsValidNumber(dn) || up <= 0.0 || dn <= 0.0) return false;
	    if (dn > up) { double tmp = dn; dn = up; up = tmp; }
	    return true;
	}


//+------------------------------------------------------------------+
//|       Buy Setup                                                  |
//+------------------------------------------------------------------+



bool BuySetup() {
    if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
        // --- MOMENTUM LOGIC ---
        double close = iClose(_Symbol, PERIOD_CURRENT, 1);
        double er    = AKKE_Er[1];
        
        double upper = 0.0, lower = 0.0;
        if (!GetSmartMomentumBands(upper, lower, 1)) return false; // Calc Failed
        
        // Signal: Close > Upper Band
        bool signal = (close > upper);
        bool filter = (InpKeltner_Min_ER < 0 || er > InpKeltner_Min_ER);
        
        if (signal && !filter) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) 
                 CAuroraLogger::InfoStrategy(StringFormat("BUY Signal Ignored (ER Too Low: %.2f < %.2f)", er, InpKeltner_Min_ER));
        }
        
        return (signal && filter);
    }

    // --- SUPER TREND LOGIC ---
    // 1. Determine Signal Price Source
    double sigPrice;
    
    if (InpSignal_Source == SIGNAL_SRC_REAL_PRICE) {
        // FAST MODE: Compare Real Close[1] (Locked) to ZLSMA[1]
        sigPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
    }
    else if (InpSignal_Source == SIGNAL_SRC_ADAPTIVE) {
        // ADAPTIVE MODE: Check structural volatility AND market cleanliness
        // If VR > Threshold (Crisis) AND ER > 0.6 (Clean Trend) -> Use Real Price for speed
        // If VR > Threshold BUT ER < 0.6 (Choppy) -> Stay Smoothed (HA) to avoid whipsaws
        // If VR <= Threshold (Calm) -> Use HA for smoothing
        // ADAPTIVE MODE: Check structural volatility AND market cleanliness
        // Use Cached Metrics (Index 1) for Stability
        double vr = g_barCache.volRatio;
        double er = g_barCache.effRatio;
        
        bool isVolatile = (vr > InpAdaptive_Vol_Threshold);
        bool isClean = (er > 0.6); // Clean trend threshold
        
        // [ADAPTIVE INVERSION] Only switch to Real Price if BOTH volatile AND clean
        if (isVolatile && isClean) sigPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
        else                       sigPrice = HA_C[1];
    }
    else {
        // CLASSIC MODE (Default): Heiken Ashi
        sigPrice = HA_C[1];
    }

    // 2. Perform Check
    // Signal: Price > ZLSMA
    // Setup Valid if CE is Green (Buy Zone) AND Price > ZLSMA
    
    // Note: CE_B[1] != 0 means Chandelier is in Buy Mode (Long Stop exists)
    return (CE_B[1] != 0 && sigPrice > ZL[1]);
}

bool BuySignal() {
    if (!BuySetup()) return false;
    
    // SAFETY: GAP FILTER
    if (SignalMaxGapPts > 0) {
        double sigPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
        double currentPrice = Ask();
        double gap = MathAbs(currentPrice - sigPrice);
        if (gap > SignalMaxGapPts * _Point) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                CAuroraLogger::WarnStrategy(StringFormat("Signal GAP trop grand: %.0f pts > %d. Entrée annulée.", gap/_Point, SignalMaxGapPts));
            return false;
        }
    }

    // SAFETY: TRAP CANDLE FILTER (Institutional Optimization: Using Cache)
    if (InpTrap_Enable && g_barCache.trapSignal) {
        if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
            CAuroraLogger::WarnStrategy("[TRAP CANDLE] BUY blocked: Previous bar was a wick trap (Cache)");
        return false;
    }

    double entry=0.0, stop=0.0;
    if (!BuildSignalPrices(true, entry, stop)) return false;
    
    // --- DYNAMIC RISK HOOK ---
    // Fix: Dynamic Risk Removed - defaulting to 1.0 (Neutral)
    double multiplier = 1.0;
    double originalRisk = ea.risk;
    ea.risk *= multiplier; // Apply Mod
    
    // Modification: Use overload without 'entry' to respect InpEntry_Mode logic (Limit/Stop/Market)
    bool res = ea.BuyOpen(stop, 0.0, IgnoreSL, true);
    
    ea.risk = originalRisk; // Restore
    // -------------------------
    
    return res;
}


//+------------------------------------------------------------------+
//|         Sell Setup                                               |
//+------------------------------------------------------------------+

bool SellSetup() {
    if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
        // --- MOMENTUM LOGIC ---
        double close = iClose(_Symbol, PERIOD_CURRENT, 1);
        double er    = AKKE_Er[1];
        
        double upper = 0.0, lower = 0.0;
        if (!GetSmartMomentumBands(upper, lower, 1)) return false;
        
        // Signal: Close < Lower Band
        bool signal = (close < lower);

        bool filter = (InpKeltner_Min_ER < 0 || er > InpKeltner_Min_ER);
        
        if (signal && !filter) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) 
                 CAuroraLogger::InfoStrategy(StringFormat("SELL Signal Ignored (ER Too Low: %.2f < %.2f)", er, InpKeltner_Min_ER));
        }
        
        return (signal && filter);
    }


    // --- SUPER TREND LOGIC ---
    // 1. Determine Signal Price Source
    double sigPrice;
    
    if (InpSignal_Source == SIGNAL_SRC_REAL_PRICE) {
        // FAST MODE: Compare Real Close[1] (Locked) to ZLSMA[1]
        sigPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
    }
    else if (InpSignal_Source == SIGNAL_SRC_ADAPTIVE) {
        // ADAPTIVE MODE: Check structural volatility AND market cleanliness
        // ADAPTIVE MODE: Check structural volatility AND market cleanliness
        double vr = g_barCache.volRatio;
        double er = g_barCache.effRatio;
        
        bool isVolatile = (vr > InpAdaptive_Vol_Threshold);
        bool isClean = (er > 0.6); // Clean trend threshold
        
        // [ADAPTIVE INVERSION] Only switch to Real Price if BOTH volatile AND clean
        if (isVolatile && isClean) sigPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
        else                       sigPrice = HA_C[1];
    }
    else {
        // CLASSIC MODE (Default): Heiken Ashi
        sigPrice = HA_C[1];
    }

    // 2. Perform Check
    // Signal: Price < ZLSMA
    // Setup Valid if CE is Red (Sell Zone) AND Price < ZLSMA
    
    // Note: CE_S[1] != 0 means Chandelier is in Sell Mode (Short Stop exists)
    return (CE_S[1] != 0 && sigPrice < ZL[1]);
}

bool SellSignal() {
    if (!SellSetup()) return false;

    // SAFETY: GAP FILTER
    if (SignalMaxGapPts > 0) {
        double sigPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
        double currentPrice = Bid();
        double gap = MathAbs(currentPrice - sigPrice);
        if (gap > SignalMaxGapPts * _Point) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                CAuroraLogger::WarnStrategy(StringFormat("Signal GAP trop grand: %.0f pts > %d. Entrée annulée.", gap/_Point, SignalMaxGapPts));
            return false;
        }
    }

    // SAFETY: TRAP CANDLE FILTER (Institutional Optimization: Using Cache)
    if (InpTrap_Enable && g_barCache.trapSignal) {
        if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
            CAuroraLogger::WarnStrategy("[TRAP CANDLE] SELL blocked: Previous bar was a wick trap (Cache)");
        return false;
    }

    double entry=0.0, stop=0.0;
    if (!BuildSignalPrices(false, entry, stop)) return false;

    // --- DYNAMIC RISK HOOK ---
    // Fix: Dynamic Risk Removed - defaulting to 1.0 (Neutral)
    double multiplier = 1.0;
    double originalRisk = ea.risk;
    ea.risk *= multiplier; // Apply Mod
    
    // Modification: Use overload without 'entry' to respect InpEntry_Mode logic (Limit/Stop/Market)
    bool res = ea.SellOpen(stop, 0.0, IgnoreSL, true);
    
    ea.risk = originalRisk; // Restore
    // -------------------------

    return res;
}

//+------------------------------------------------------------------+
//| Helper: Immediate Execution (Breakout)                           |
//+------------------------------------------------------------------+
bool ExecuteImmediateOrder(bool isBuy, double price, double sl, double vol, string comment, const bool allowEntryGate) {
    if (!IsNewExposureAllowed(allowEntryGate, "PREDICTIVE_IMMEDIATE")) {
        return false;
    }

    // 1. Trap Filter (Cached)
    if (InpTrap_Enable && g_barCache.trapSignal) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) 
            CAuroraLogger::WarnStrategy("[TRAP CANDLE] Immediate Entry blocked: Trap Detected in Cache");
        return false;
    }
    
    // 2. Gap Filter (Check Gap between Target and Current Price)
    // If price gapped WAAAAY past target, risky?
    if (SignalMaxGapPts > 0) {
         double currentPrice = (isBuy ? Ask() : Bid());
         double gap = MathAbs(currentPrice - price);
         if (gap > SignalMaxGapPts * _Point) {
              if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) 
                  CAuroraLogger::WarnStrategy(StringFormat("Gap too large: %.1f > %d. Entry Cancelled.", gap/_Point, SignalMaxGapPts));
              return false;
         }
    }
    
    // 3. Close & Execute
    ENUM_ORDER_TYPE pendingType = (isBuy ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP);
    closePendingOrders(pendingType, MagicNumber);

    // Async de-dup: prevent duplicate market sends while same-side deal is still in-flight.
    if (g_asyncManager.HasPending(MagicNumber, _Symbol, TRADE_ACTION_DEAL, (isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL))) {
        return false;
    }
    
    // Check Positions (Snapshot O(1))
    bool hasPos = (g_snapshot.CountBuys() + g_snapshot.CountSells() > 0);
    
    if (!hasPos || MultipleOpenPos) {
        bool res = false;
        
        if (isBuy) {
            // Signature: BuyOpen(price, sl, tp, isl, itp, name, vol, comment)
            res = ea.BuyOpen(price, sl, 0.0, false, false, _Symbol, vol, comment);
        } else {
            res = ea.SellOpen(price, sl, 0.0, false, false, _Symbol, vol, comment);
        }
        
        if (res) {
             g_lastSignalBar = iTime(_Symbol, PERIOD_CURRENT, 0);
             return true;
        }
    }
    return false;
}


//+------------------------------------------------------------------+
//| AURORA PREDICTIVE EXECUTION (APE)                                |
//+------------------------------------------------------------------+

bool ShouldUpdatePredictivePending(ulong ticket, double targetPrice, int thresholdPts) {
    if (ticket == 0) return false;
    if (thresholdPts <= 0) return true;
    double point = _Point;
    if (point <= 0) return true;
    double currentPrice = OrderOpenPriceSafe(ticket);
    if (currentPrice <= 0) return true;
    double diffPts = MathAbs(targetPrice - currentPrice) / point;
    return (diffPts >= thresholdPts);
}

bool HasPendingUnified(ENUM_ORDER_TYPE type) {
    if (getPendingTicket(MagicNumber, type, _Symbol) > 0) return true;
    if (g_asyncManager.HasPending(MagicNumber, _Symbol, TRADE_ACTION_PENDING, type)) return true;
    return false;
}

bool PendingAsyncBusy(ENUM_ORDER_TYPE type, ulong ticket) {
    if (g_asyncManager.HasPending(MagicNumber, _Symbol, TRADE_ACTION_PENDING, type)) return true;
    if (ticket > 0 && g_asyncManager.HasPending(MagicNumber, _Symbol, TRADE_ACTION_MODIFY, type, 0, ticket)) return true;
    if (ticket > 0 && g_asyncManager.HasPending(MagicNumber, _Symbol, TRADE_ACTION_REMOVE, (ENUM_ORDER_TYPE)-1, 0, ticket)) return true;
    return false;
}

bool IsPredictiveSLGeometryValid(const bool isBuy, const double entry, const double sl) {
    if (!MathIsValidNumber(entry) || !MathIsValidNumber(sl)) return false;
    if (entry <= 0.0 || sl <= 0.0) return false;
    if (entry == EMPTY_VALUE || sl == EMPTY_VALUE) return false;

    double point = _Point;
    if (point <= 0.0) point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if (point <= 0.0) return false;

    double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    if (tick <= 0.0) tick = point;

    const int minPts = MinBrokerPoints(_Symbol);
    const double minDist = MathMax((double)minPts, 1.0) * point;
    const double dist = MathAbs(entry - sl);
    if ((dist + (tick * 0.5)) < minDist) return false;

    if (isBuy && sl >= (entry - (tick * 0.5))) return false;
    if (!isBuy && sl <= (entry + (tick * 0.5))) return false;
    return true;
}

bool IsPredictiveLegValid(const bool isBuy, const double entry, const double sl, const double vol) {
    if (!IsPredictiveSLGeometryValid(isBuy, entry, sl)) return false;
    if (!MathIsValidNumber(vol) || vol <= 0.0) return false;
    return true;
}

bool BuildPredictiveRiskLeg(const bool isBuy, const double entry, const double risk, double &outSl, double &outVol) {
    outSl = 0.0;
    outVol = 0.0;
    if (!MathIsValidNumber(entry) || entry <= 0.0 || entry == EMPTY_VALUE) return false;

    const double stop = ComputeStop(isBuy, entry);
    if (!MathIsValidNumber(stop) || stop <= 0.0 || stop == EMPTY_VALUE) return false;
    if (!IsPredictiveSLGeometryValid(isBuy, entry, stop)) return false;

    outSl = NormalizePrice(stop, _Symbol);
    if (!IsPredictiveSLGeometryValid(isBuy, entry, outSl)) return false;

    outVol = calcVolume(entry, outSl, risk, 0, MagicNumber, _Symbol, -1, ea.riskMode, ea.riskMaxLotSize);
    return IsPredictiveLegValid(isBuy, entry, outSl, outVol);
}

void ManagePredictiveOrders(bool vwapBlockBuy, bool vwapBlockSell, bool allowEntry) {
    if (!IsNewExposureAllowed(allowEntry, "PREDICTIVE")) {
        ea.ClosePendingsForSymbol(_Symbol);
        return;
    }
    // --- REGIME AUTO-KILL ---
    if (g_barCache.regimeToxic) {
        closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
        closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
        return;
    }

    // --- TRAP CANDLE FILTER (APE) ---
    if (InpTrap_Enable && g_barCache.trapSignal) {
        closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
        closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
        return;
    }
    // -------------------------

    // 1. Basic Filters Reuse (Duplicate of OnTick but necessary for standalone logic)
    if (InpMaxDailyTrades != -1 && GetDailyTradeCount() >= InpMaxDailyTrades) {
         closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
         closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
         return;
    }
    
    // --- EXECUTION GUARD (Predictive) ---
    // Prevent placing new orders if we already executed a trade on this bar (Stop Loss hit? Don't re-enter)
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if (InpGuard_OneTradePerBar && HasTradedOnBar(_Symbol, MagicNumber, currentBar)) {
         closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
         closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
         return;
    }
    // ------------------------------------
    if (SpreadLimit != -1 && Spread() > SpreadLimit) return; // Don't touch orders during spread spike

    if (!g_barCache.predictiveLevelsReady) {
        closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
        closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
        return;
    }

    // Safety: never place predictive orders with invalid cached levels (INF/NaN/0/wrong-side/no-volume).
    if (!MathIsValidNumber(g_barCache.predBuyPrice) ||
        !MathIsValidNumber(g_barCache.predSellPrice) ||
        g_barCache.predBuyPrice <= 0.0 ||
        g_barCache.predSellPrice <= 0.0 ||
        g_barCache.predSellPrice >= g_barCache.predBuyPrice ||
        !IsPredictiveLegValid(true, g_barCache.predBuyPrice, g_barCache.predSL_Buy, g_barCache.predVolBuy) ||
        !IsPredictiveLegValid(false, g_barCache.predSellPrice, g_barCache.predSL_Sell, g_barCache.predVolSell)) {
        closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
        closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
        if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
            CAuroraLogger::WarnDiag(StringFormat("[APE] Invalid predictive levels: buy=%.5f sell=%.5f slB=%.5f slS=%.5f volB=%.4f volS=%.4f",
                g_barCache.predBuyPrice, g_barCache.predSellPrice, g_barCache.predSL_Buy, g_barCache.predSL_Sell, g_barCache.predVolBuy, g_barCache.predVolSell));
        return;
    }

    datetime predExpiry = 0;
    if (InpEntry_Expiration_Sec > 0) {
        datetime now = AuroraClock::Now();
        predExpiry = now + InpEntry_Expiration_Sec;
    }
    ENUM_ORDER_TYPE_TIME predTimeType = (predExpiry > 0 ? ORDER_TIME_SPECIFIED : ORDER_TIME_GTC);
    


    // 2. Logic Check
    bool hasPos = (positionsTotalMagic(MagicNumber, _Symbol) > 0);
    
    if (hasPos && !MultipleOpenPos) {
         // Cleanup any residual pending logic if we are already in position
         // (Unless we want to stack, but strict scalping usually one entry stream)
         closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
         closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
         return;
    }

    // 3. Directions
    bool buyAllowed = (InpOpen_Side != DIR_SHORT_ONLY) && !vwapBlockBuy;
    bool sellAllowed = (InpOpen_Side != DIR_LONG_ONLY) && !vwapBlockSell;
    if (Reverse) {
         bool tmp = buyAllowed;
         buyAllowed = sellAllowed;
         sellAllowed = tmp;
    }
    
    // --- STRATEGY BRANCHING ---
     if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
         // --- MOMENTUM PREDICTIVE MODE ---
         // Place STOP Orders at the Bands (Instant Breakout)
         // Only if ER is good? Or do we place them anyway and let OnTick filters kill positions? 
         // Pending orders are dumb. If market starts vibrating, we might get filled.
         // Better: Check ER now. If ER bad, delete orders.
         
         // Use Pre-calculated levels from Cache for speed and stability
         double target_up = g_barCache.predBuyPrice;
         double target_dn = g_barCache.predSellPrice;
         
         // ER Filter for Pendings (Cached)
         if (InpKeltner_Min_ER > 0 && AKKE_Er[1] < InpKeltner_Min_ER) {
             closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
             closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
             return;
         }
         
         double adjustedRisk = ea.risk;
         
         // BUY STOP @ UPPER BAND
         if (buyAllowed) {
             double target = NormalizePrice(target_up);
             double ask = GetSmoothedPrice(ORDER_TYPE_BUY);
             double minStopDist = MinBrokerPoints(_Symbol) * _Point;
             
             if (target > ask + minStopDist) {
                 ulong pending = getPendingTicket(MagicNumber, ORDER_TYPE_BUY_STOP, _Symbol);
                 double sl = g_barCache.predSL_Buy;
                 double vol = g_barCache.predVolBuy;
                 
                 if (pending > 0) {
                     if (!PendingAsyncBusy(ORDER_TYPE_BUY_STOP, pending) &&
                         ShouldUpdatePredictivePending(pending, target, InpPredictive_Update_Threshold)) {
                         ea.SyncPendingOrder(pending, ORDER_TYPE_BUY_STOP, target, sl, 0, vol, "APE-Mom", _Symbol, predExpiry);
                     }
                 } else if (!HasPendingUnified(ORDER_TYPE_BUY_STOP)) {
                     pendingOrder(ORDER_TYPE_BUY_STOP, MagicNumber, target, sl, 0, vol, 0, predExpiry, predTimeType, _Symbol, "APE-Mom", ea.filling, ea.riskMode, adjustedRisk, ea.slippage, ea.riskMaxTotalLots);
                 }
             } else if (ask >= target) {
                 ExecuteImmediateOrder(true, target, g_barCache.predSL_Buy, g_barCache.predVolBuy, "APE-Mom", allowEntry);
             }
         } else {
             closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
         }
         
         // SELL STOP @ LOWER BAND
         if (sellAllowed) {
             double target = NormalizePrice(target_dn);
             double bid = GetSmoothedPrice(ORDER_TYPE_SELL);
             double minStopDist = MinBrokerPoints(_Symbol) * _Point;
 
             if (target < bid - minStopDist) {
                 ulong pending = getPendingTicket(MagicNumber, ORDER_TYPE_SELL_STOP, _Symbol);
                 double sl = g_barCache.predSL_Sell;
                 double vol = g_barCache.predVolSell;
                 
                 if (pending > 0) {
                     if (!PendingAsyncBusy(ORDER_TYPE_SELL_STOP, pending) &&
                         ShouldUpdatePredictivePending(pending, target, InpPredictive_Update_Threshold)) {
                         ea.SyncPendingOrder(pending, ORDER_TYPE_SELL_STOP, target, sl, 0, vol, "APE-Mom", _Symbol, predExpiry);
                     }
                 } else if (!HasPendingUnified(ORDER_TYPE_SELL_STOP)) {
                     pendingOrder(ORDER_TYPE_SELL_STOP, MagicNumber, target, sl, 0, vol, 0, predExpiry, predTimeType, _Symbol, "APE-Mom", ea.filling, ea.riskMode, adjustedRisk, ea.slippage, ea.riskMaxTotalLots);
                 }
             } else if (bid <= target) {
                 ExecuteImmediateOrder(false, target, g_barCache.predSL_Sell, g_barCache.predVolSell, "APE-Mom", allowEntry);
             }
         } else {
             closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
         }
         
         return; // End Momentum Path
     }

    // --- SUPER TREND LOGIC (Legacy) ---
    
    // 4. Trend Context (Using Index 1 purely for Trend Color Stability)
    bool trendBuy = (CE_B[1] != 0 && CE_B[1] != EMPTY_VALUE);
    bool trendSell = (CE_S[1] != 0 && CE_S[1] != EMPTY_VALUE);
    
    // 5. Projected levels are PRE-CALCULATED in g_barCache for speed
    double adjustedRisk = ea.risk;

    // --- BUY LOGIC ---
    if (buyAllowed && trendBuy) {
        // Cleanup Opposite
        closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
        
        double target = NormalizePrice(g_barCache.predBuyPrice);
        
        double ask = GetSmoothedPrice(ORDER_TYPE_BUY);
        double minStop = ask + MinBrokerPoints(_Symbol) * _Point;
        
        // Scenario A: Future Signal (Price below Target)
        // We place a Buy Stop at the Target.
        if (target > minStop) {
            ulong pending = getPendingTicket(MagicNumber, ORDER_TYPE_BUY_STOP, _Symbol);
            double sl = g_barCache.predSL_Buy;
            double vol = g_barCache.predVolBuy;
            
            if (pending > 0) {
                if (!PendingAsyncBusy(ORDER_TYPE_BUY_STOP, pending) &&
                    ShouldUpdatePredictivePending(pending, target, InpPredictive_Update_Threshold)) {
                    ea.SyncPendingOrder(pending, ORDER_TYPE_BUY_STOP, target, sl, 0, vol, "APE", _Symbol, predExpiry);
                }
            } else if (!HasPendingUnified(ORDER_TYPE_BUY_STOP)) {
                pendingOrder(ORDER_TYPE_BUY_STOP, MagicNumber, target, sl, 0, vol, 0, predExpiry, predTimeType, _Symbol, "APE", ea.filling, ea.riskMode, adjustedRisk, ea.slippage, ea.riskMaxTotalLots);
            }
        } 
        // Scenario B: Signal Triggered (Price crossed Target)
        else if (ask >= target) {
            ExecuteImmediateOrder(true, target, g_barCache.predSL_Buy, g_barCache.predVolBuy, "APE", allowEntry);
        }
        else {
             // Scenario C: "No Man's Land"
        }
    } else {
        closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
    }

    // --- SELL LOGIC ---
    if (sellAllowed && trendSell) {
        // Cleanup Opposite
        closePendingOrders(ORDER_TYPE_BUY_STOP, MagicNumber);
 
        double target = NormalizePrice(g_barCache.predSellPrice);
        
        double bid = GetSmoothedPrice(ORDER_TYPE_SELL);
        double minStop = bid - MinBrokerPoints(_Symbol) * _Point;
        
        // Scenario A: Future Signal (Price above Target)
        if (target < minStop) {
             ulong pending = getPendingTicket(MagicNumber, ORDER_TYPE_SELL_STOP, _Symbol);
             double sl = g_barCache.predSL_Sell;
             double vol = g_barCache.predVolSell;
             
             if (pending > 0) {
                 if (!PendingAsyncBusy(ORDER_TYPE_SELL_STOP, pending) &&
                     ShouldUpdatePredictivePending(pending, target, InpPredictive_Update_Threshold)) {
                     ea.SyncPendingOrder(pending, ORDER_TYPE_SELL_STOP, target, sl, 0, vol, "APE", _Symbol, predExpiry);
                 }
             } else if (!HasPendingUnified(ORDER_TYPE_SELL_STOP)) {
                 pendingOrder(ORDER_TYPE_SELL_STOP, MagicNumber, target, sl, 0, vol, 0, predExpiry, predTimeType, _Symbol, "APE", ea.filling, ea.riskMode, adjustedRisk, ea.slippage, ea.riskMaxTotalLots);
             }
        }
        else if (bid <= target) {
             ExecuteImmediateOrder(false, target, g_barCache.predSL_Sell, g_barCache.predVolSell, "APE", allowEntry);
        }
    } else {
        closePendingOrders(ORDER_TYPE_SELL_STOP, MagicNumber);
    }
}

void CheckClose() {
    if (!CloseOrders) return;
    int n = InpClose_ConfirmBars;
    if (n < 1) n = 1;
    if (n >= BuffSize) n = BuffSize - 1; // borné par la taille des buffers

    bool buyExitConf = false;
    bool sellExitConf = false;

    if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
        // Momentum inverse-close: reuse opposite signal geometry over N closed bars.
        // Buy exits on bearish confirmation; Sell exits on bullish confirmation.
        if (ArraySize(AKKE_Kama) <= n || ArraySize(AKKE_Er) <= n) return;

        bool bearishAll = true;
        bool bullishAll = true;
        for (int s = 1; s <= n; ++s) {
            double upper = 0.0, lower = 0.0;
            if (!GetSmartMomentumBands(upper, lower, s)) return;

            double close = iClose(_Symbol, PERIOD_CURRENT, s);
            if (!MathIsValidNumber(close)) return;

            bool erFilter = (InpKeltner_Min_ER < 0.0 || (MathIsValidNumber(AKKE_Er[s]) && AKKE_Er[s] > InpKeltner_Min_ER));
            if (!(close < lower && erFilter)) bearishAll = false;
            if (!(close > upper && erFilter)) bullishAll = false;
        }
        buyExitConf = bearishAll;
        sellExitConf = bullishAll;
    } else {
        if (ArraySize(HA_C) <= n || ArraySize(ZL) <= n) return;

        bool belowAll = true; // HA<ZL sur n barres
        bool aboveAll = true; // HA>ZL sur n barres
        for (int s = 1; s <= n; ++s) {
            if (!(HA_C[s] < ZL[s])) belowAll = false;
            if (!(HA_C[s] > ZL[s])) aboveAll = false;
        }
        buyExitConf  = belowAll; // conf. baissière
        sellExitConf = aboveAll; // conf. haussière
    }

    if (buyExitConf && InpOpen_Side != DIR_SHORT_ONLY)
        ea.BuyClose();
    if (sellExitConf && InpOpen_Side != DIR_LONG_ONLY)
        ea.SellClose();
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

int OnInit() {
    SIndicatorInputs iin = MakeIndicatorInputs();
    SRiskInputs rin = MakeRiskInputs();
    SOpenInputs oin = MakeOpenInputs();
    if (!ValidateInputs()) return INIT_FAILED;

    CAuroraLogger::Configure(
        InpLog_General,
        InpLog_Position,
        InpLog_Risk,
        InpLog_Session,
        InpLog_News,
        InpLog_Simulation,
        InpLog_Strategy,
        InpLog_Orders,
        InpLog_Diagnostic,
        InpLog_Invariant
    );
    CAuroraLogger::SetPrefix(_Symbol);

    LogInputScope();
    
    // Explicit Cache Init (Sets Defaults like VolRatio=1.0)
    g_barCache.Reset();

    ConfigureEAFromInputs(rin, oin, iin);

    // Initialisation Dashboard
    if (InpDash_Enable) {
        // Scaling Logic
        double scale = 1.0;
        if(InpDash_Scale > 0) {
            scale = (double)InpDash_Scale / 100.0;
        } else {
            int dpi = TerminalInfoInteger(TERMINAL_SCREEN_DPI);
            int screen_h = TerminalInfoInteger(TERMINAL_SCREEN_HEIGHT);
            
            scale = (double)dpi / 96.0;
            
            // Heuristic Fallback: If DPI reports 96 (default) but resolution is high
            // Windows often reports 96 even on 4K unless "System Enhanced" scaling is used.
            if (dpi == 96) {
                if (screen_h > 2100) scale = 2.0;      // ~4K
                else if (screen_h > 1400) scale = 1.5; // ~1440p
                else if (screen_h > 1000) scale = 1.25;// ~1080p+
            }
            
            if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) 
               PrintFormat("[DASH] Auto-DPI Detected: DPI=%d, H=%d -> Scale %.2f", dpi, screen_h, scale);
        }
    
        g_dashboard.SetScale(scale);
        g_dashboard.SetVersion("v" + AURORA_VERSION); // Dynamic Version
        g_dashboard.Init(ChartID(), "AuroraDash", InpDash_Corner); 
        g_dashboard.SetLogDebug(InpLog_Dashboard);
        
        // Init Stats baselines
        g_max_dd_alltime = 0.0;
        
        // --- Persistence Init ---
        g_gv_dd_name = StringFormat("Aurora_MaxDD_%I64d_%s", MagicNumber, _Symbol);
        if(GlobalVariableCheck(g_gv_dd_name)) {
            g_max_dd_alltime = GlobalVariableGet(g_gv_dd_name);
            if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
                CAuroraLogger::InfoGeneral(StringFormat("Restored MaxDD History: %.2f%%", g_max_dd_alltime));
        }
        // ------------------------
        g_max_dd_daily = 0.0;
        g_last_stat_day = iTime(_Symbol, PERIOD_D1, 0);
    } else {
        g_dashboard.Destroy();
    }

    // One-time broker capability diagnostics (helps explain "Unsupported filling mode"/"Invalid expiration")
    if (CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) {
        const long exeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_EXEMODE);
        const long fillMask = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
        const long expMask = SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);

        string fillFlags = "";
        if ((fillMask & SYMBOL_FILLING_FOK) != 0) fillFlags += "FOK ";
        if ((fillMask & SYMBOL_FILLING_IOC) != 0) fillFlags += "IOC ";
	        if ((fillMask & SYMBOL_FILLING_BOC) != 0) fillFlags += "BOC ";
	        if (fillFlags == "") fillFlags = "(none flagged; RETURN implied)";
	        else StringTrimRight(fillFlags);

        string expFlags = "";
        if ((expMask & SYMBOL_EXPIRATION_GTC) != 0) expFlags += "GTC ";
        if ((expMask & SYMBOL_EXPIRATION_DAY) != 0) expFlags += "DAY ";
        if ((expMask & SYMBOL_EXPIRATION_SPECIFIED) != 0) expFlags += "SPECIFIED ";
	        if ((expMask & SYMBOL_EXPIRATION_SPECIFIED_DAY) != 0) expFlags += "SPECIFIED_DAY ";
	        if (expFlags == "") expFlags = "(mode=0/unknown)";
	        else StringTrimRight(expFlags);

        CAuroraLogger::InfoOrders(StringFormat(
            "[BROKER] EXE=%s fillMask=%I64d [%s] expMask=%I64d [%s] input.Filling=%s",
            EnumToString((ENUM_SYMBOL_TRADE_EXECUTION)exeMode),
            fillMask,
            fillFlags,
            expMask,
            expFlags,
            EnumToString(Filling)
        ));
    }
    
    // [DIAGNOSTIC CHECK]
    if ( (InpHurst_Enable || InpVWAP_Enable || InpKurtosis_Enable || InpRegime_FatTail_Enable) && !InpLog_Diagnostic) {
         CAuroraLogger::WarnGeneral("[WARNING] Regime Filters Enabled but Diagnostic Logging DISABLED. Enable InpLog_Diagnostic to see internal values.");
    }
    
    // --- SIMULATION INIT ---
    SSimulationInputs sim;
    sim.enable = InpSim_Enable;
    sim.latency_ms = InpSim_LatencyMs;
    sim.spread_pad_pts = InpSim_SpreadPad_Pts;
    sim.comm_per_lot = InpSim_Comm_PerLot;
    sim.slippage_add_pts = InpSim_Slippage_Add;
    sim.rejection_prob = InpSim_Rejection_Prob;
    sim.start_ticket = InpSim_StartTicket;
    g_simulation.Init(sim);
    // -----------------------

    g_asyncManager.Configure(MagicNumber, _Symbol);

    // Configurer le Session Manager
    SSessionInputs sess = MakeSessionInputs();
    g_session.Configure(sess);

    // Weekend guard (Generic)
    SWeekendInputs w = MakeWeekendInputs();
    g_weekend.Configure(w);

    SNewsInputs newsParams = MakeNewsInputs();
    newsFilter.Configure(newsParams);



    // Init Pyramiding
    STrendScaleInputs trendParams = MakeTrendScaleInputs();
    g_pyramiding.Configure(trendParams);

    // --- STRATEGY INITIALIZATION ---
    if (InpStrategy_Core == STRAT_CORE_SUPER_TREND) {
        // LEGACY MODE: Load HA, CE, ZL
        HA_handle = iCustom(NULL, 0, I_HA);
        CE_handle = iCustom(NULL, 0, I_CE, CeAtrPeriod, CeAtrMult, InpLog_IndicatorInternal);
        ZL_handle = iCustom(NULL, 0, I_ZL, ZlPeriod, true);
        
        if (HA_handle == INVALID_HANDLE || CE_handle == INVALID_HANDLE || ZL_handle == INVALID_HANDLE) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
                CAuroraLogger::ErrorGeneral("Failed to init Super Trend handles");
            return(INIT_FAILED);
        }
    } 
    else if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
        // MOMENTUM MODE: Load AU_KELTNER_KAMA only
        // Inputs: Per, Fast, Slow, AtrPer, AtrMult
        AKKE_handle = iCustom(NULL, 0, I_AKKE, 
            InpKeltner_KamaPeriod, 
            InpKeltner_KamaFast, 
            InpKeltner_KamaSlow, 
            InpKeltner_AtrPeriod, 
            InpKeltner_Mult,
            InpLog_IndicatorInternal
        );
        
        if (AKKE_handle == INVALID_HANDLE) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
                CAuroraLogger::ErrorGeneral("Failed to init Momentum (AKKE) handle");
            return(INIT_FAILED);
        }
        
        // Optimisation: HA non utilisé par Momentum Core (Logic on Real Price)
        // HA_handle = iCustom(NULL, 0, I_HA); 
        
        // MOMENTUM FIX: Ensure buffers are handled as Series (Newest = 0)
        ArraySetAsSeries(AKKE_Kama, true);
        ArraySetAsSeries(AKKE_Dn, true);
        ArraySetAsSeries(AKKE_Up, true);
        ArraySetAsSeries(AKKE_Er, true); 
    }
    // -------------------------------

    // Initialisation ATR pour SL Dynamique
    if (InpSL_Mode == SL_MODE_DYNAMIC_ATR || InpSL_Mode == SL_MODE_DEV_ATR) {
        g_hSL_ATR = iATR(NULL, 0, InpSL_AtrPeriod);
        if (g_hSL_ATR == INVALID_HANDLE) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
                CAuroraLogger::ErrorGeneral("Failed to init SL ATR handle");
            return(INIT_FAILED);
        }
    }
    


    // Initialisation HURST Handle (Also needed for Stress Mode force-activation)
    if (InpHurst_Enable || InpStress_Enable) {
        Hurst_handle = iCustom(_Symbol, InpHurst_Timeframe, I_HURST, InpHurst_Window, InpHurst_Smoothing, InpHurst_Threshold);
        if (Hurst_handle == INVALID_HANDLE) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral("Failed to init HURST handle");
             return(INIT_FAILED);
        }
        ArraySetAsSeries(Hurst_Buffer, true);
    }

    // Initialisation VWAP Handle (Also needed for Stress Mode force-activation)
    if (InpVWAP_Enable || InpStress_Enable) {
        VWAP_handle = iCustom(_Symbol, PERIOD_CURRENT, I_VWAP, InpVWAP_DevLimit);
        if (VWAP_handle == INVALID_HANDLE) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral("Failed to init VWAP handle");
             return(INIT_FAILED);
        }
        ArraySetAsSeries(VWAP_Buffer, true);
        ArraySetAsSeries(VWAP_Upper, true);
        ArraySetAsSeries(VWAP_Lower, true);
    }

    // Initialisation KURTOSIS Handle (Also needed for Stress Mode force-activation)
    if (InpKurtosis_Enable || InpRegime_FatTail_Enable || InpStress_Enable) {
        Kurtosis_handle = iCustom(_Symbol, PERIOD_CURRENT, I_KURTOSIS, InpKurtosis_Period, InpKurtosis_Threshold, InpLog_IndicatorInternal);
        if (Kurtosis_handle == INVALID_HANDLE) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral("Failed to init KURTOSIS handle");
             return(INIT_FAILED);
        }
        ArraySetAsSeries(Kurtosis_Buffer, true);
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::InfoGeneral(StringFormat("[KURTOSIS] Filter Active. Threshold=%.2f, Period=%d", InpKurtosis_Threshold, InpKurtosis_Period));
    }

    // Initialisation TRAP CANDLE Handle
    if (InpTrap_Enable) {
        Trap_handle = iCustom(_Symbol, PERIOD_CURRENT, I_TRAP, InpTrap_WickRatio, InpTrap_MinBodyPts, 0.4, true, 3);
        if (Trap_handle == INVALID_HANDLE) {
             if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) CAuroraLogger::ErrorGeneral("Failed to init TRAP CANDLE handle");
             return(INIT_FAILED);
        }
        ArraySetAsSeries(Trap_Signal, true);
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::InfoGeneral(StringFormat("[TRAP CANDLE] Filter Active. WickRatio=%.1f, MinBody=%d", InpTrap_WickRatio, InpTrap_MinBodyPts));
    }

    // Check Handles Validity based on Strategy
    bool handlesOk = true;
    if (InpStrategy_Core == STRAT_CORE_SUPER_TREND) {
        if (HA_handle == INVALID_HANDLE || CE_handle == INVALID_HANDLE || ZL_handle == INVALID_HANDLE) handlesOk = false;
    } else {
         if (AKKE_handle == INVALID_HANDLE) handlesOk = false;
    }

    if (!handlesOk) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::ErrorGeneral(StringFormat("Runtime error (Handles) = %d", GetLastError()));
        return(INIT_FAILED);
    }

    // Timer: Use Main TimerInterval directly
    int timerSec = TimerInterval;
    if(timerSec < AURORA_TIMER_MIN_SEC) timerSec = AURORA_TIMER_MIN_SEC;
    EventSetTimer(timerSec);
    // Info stratégie: côté d'ouverture
    if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
        string sideTxt = (InpOpen_Side==DIR_LONG_ONLY?"LONG":(InpOpen_Side==DIR_SHORT_ONLY?"SHORT":"BIDIRECTIONNEL"));
        CAuroraLogger::InfoStrategy(StringFormat("Type de positions autorisées: %s", sideTxt));
    }
    
    // Caching TickValue
    InitTickValue(_Symbol);

    SeedDailyTradeCount();
    SeedSnapshotCommissions();
    
    // [EXIT-ON-CLOSE] Configuration
    ea.ConfigExitOnClose(InpExit_OnClose, InpExit_HardSL_Multiplier);
    
    // [ELASTIC VOLATILITY] Configuration
    ea.ConfigElasticParams(InpElastic_Enable, InpElastic_Apply_SL, InpElastic_Apply_Trail, InpElastic_Apply_BE, InpElastic_ATR_Short, InpElastic_ATR_Long, InpElastic_Max_Scale);

    // [TRAILING STOP] Configuration
    if (TrailMode == TRAIL_FIXED_POINTS) {
        ea.trailingStopLevel = (double)TrailFixedPoints;
    } else {
        ea.trailingStopLevel = TrailingStopLevel * 0.01;
    }
    ea.trailMode = TrailMode;
    ea.trailAtrPeriod = TrailAtrPeriod;
    ea.trailAtrMult = TrailAtrMult;

    // [BREAK-EVEN] Configuration
    ea.beMinOffsetPts = InpBE_Min_Offset_Pts;
    ea.beAtrPeriod = InpBE_AtrPeriod;
    ea.beAtrMultiplier = InpBE_AtrMultiplier;
    
    // Ensure ZL buffer is handled as Series (Index 0 = Newest)
    ArraySetAsSeries(ZL, true);
    // Note: buffers CE_B/CE_S/HA_C are handled in OnTick but ZL is passed to Engine which expects Series.

    // Initialize Series flags once
    ArraySetAsSeries(HA_C, true);
    ArraySetAsSeries(CE_B, true);
    ArraySetAsSeries(CE_S, true);
    ArraySetAsSeries(ZL, true);

    // Apply Virtual Balance to EA core (must be done after inputs config)
    ea.virtualBalance = InpVirtualBalance;
    
    // Log info if active
    if (InpVirtualBalance > 0 && CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL)) {
        CAuroraLogger::InfoGeneral(StringFormat("[VIRTUAL BALANCE] ACTIVÉ: %.2f (Les calculs de risque, grille et drawdown se basent sur ce montant fixe)", InpVirtualBalance));
    }
    
    // Force immediate update to prevent latency
    if (InpDash_Enable) {
        newsFilter.OnTimer();
        UpdateDashboardState();
    }

    // --- RECOVERY STATE LOGGING ---
    if (InpLog_General) {
        int dailyTrades = GetDailyTradeCount();
        int pendingBuys = 0, pendingSells = 0;
        int total = OrdersTotal();
        for(int i=0; i<total; i++) {
             ulong t = OrderGetTicket(i);
             if(OrderGetInteger(ORDER_MAGIC)==MagicNumber) {
                 ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                 if(type==ORDER_TYPE_BUY_STOP || type==ORDER_TYPE_BUY_LIMIT) pendingBuys++;
                 if(type==ORDER_TYPE_SELL_STOP || type==ORDER_TYPE_SELL_LIMIT) pendingSells++;
             }
        }
        
        CAuroraLogger::InfoGeneral(StringFormat("[INIT] RECOVERY STATE :: DailyTrades=%d, ActivePendings=L%d/S%d, MaxDD=%.2f%%", 
            dailyTrades, pendingBuys, pendingSells, g_max_dd_alltime));
            
        if (g_lastSignalBar != 0) {
             CAuroraLogger::InfoGeneral(StringFormat("[INIT] Guard State :: LastSignalBar=%s", TimeToString(g_lastSignalBar)));
        } else {
             CAuroraLogger::InfoGeneral("[INIT] Guard State :: Clean / Reset (Trade counters active)");
        }
    }

    return INIT_SUCCEEDED;
}


//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason) {
    EventKillTimer();
    g_asyncManager.FlushState(true);
    newsFilter.FlushDiagnostics();
    ea.Deinit();
    // Libération des handles indicateurs (sécurité ressources)
    if (HA_handle != INVALID_HANDLE) {
        IndicatorRelease(HA_handle);
        HA_handle = INVALID_HANDLE;
    }
    if (CE_handle != INVALID_HANDLE) {
        IndicatorRelease(CE_handle);
        CE_handle = INVALID_HANDLE;
    }
    if (ZL_handle != INVALID_HANDLE) {
        IndicatorRelease(ZL_handle);
        ZL_handle = INVALID_HANDLE;
    }
    if (g_hSL_ATR != INVALID_HANDLE) {
        IndicatorRelease(g_hSL_ATR);
        g_hSL_ATR = INVALID_HANDLE;
    }

    if (AKKE_handle != INVALID_HANDLE) {
        IndicatorRelease(AKKE_handle);
        AKKE_handle = INVALID_HANDLE;
    }
    if (Hurst_handle != INVALID_HANDLE) {
        IndicatorRelease(Hurst_handle);
        Hurst_handle = INVALID_HANDLE;
    }
    if (VWAP_handle != INVALID_HANDLE) {
        IndicatorRelease(VWAP_handle);
        VWAP_handle = INVALID_HANDLE;
    }
    if (Kurtosis_handle != INVALID_HANDLE) {
        IndicatorRelease(Kurtosis_handle);
        Kurtosis_handle = INVALID_HANDLE;
    }
    if (Trap_handle != INVALID_HANDLE) {
        IndicatorRelease(Trap_handle);
        Trap_handle = INVALID_HANDLE;
    }
    g_dashboard.Destroy();
}


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime oldTc = tc;
    tc = AuroraClock::Now();
    if (tc == oldTc) return;
    
    bool guardsOk = AuroraGuards::ProcessTimer(
            g_session,
            g_weekend,
            newsFilter,
            ea,
            _Symbol,
            tc,
            InpNews_Action,
            Slippage);
    g_asyncManager.FlushState();

    // Soft-expire pending orders even if the broker does not support server-side expirations.
    // Runs once per second (server time tick) via OnTimer.
    ea.CleanExpiredPendingOrders();

    if (!guardsOk) return;

    UpdateDashboardState();
    

}

//+------------------------------------------------------------------+
//| Dashboard Update Helper                                          |
//+------------------------------------------------------------------+

void UpdateDashboardState() {
    if (!InpDash_Enable) return;

    // 1. Basic Account Info
    g_state.account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    g_state.account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    g_state.profit_current = AccountInfoDouble(ACCOUNT_PROFIT); // Floating PnL
    
    // 2. Drawdown Stats
    double dd = 0.0;
    if(g_state.account_balance > 0) 
        dd = ((g_state.account_balance - g_state.account_equity) / g_state.account_balance) * 100.0;
    if(dd < 0) dd = 0;
    
    g_state.dd_current = dd;
    
    // Update Max DD All Time
    if(dd > g_max_dd_alltime) {
        g_max_dd_alltime = dd;
        // Persistence Update
        if(g_gv_dd_name != "") GlobalVariableSet(g_gv_dd_name, g_max_dd_alltime);
    }
    g_state.dd_max_alltime = g_max_dd_alltime;
    
    // Update Max DD Daily
    datetime day = iTime(_Symbol, PERIOD_D1, 0);
    if(day != g_last_stat_day) {
        g_max_dd_daily = 0.0; // Reset new day
        g_last_stat_day = day;
    }
    if(dd > g_max_dd_daily) g_max_dd_daily = dd;
    g_state.dd_daily = g_max_dd_daily;

    // 3. Profit Stats (Total)
    if(g_history_dirty) { 
        double pnl_total_hist = 0.0;
        
        // Total Profit (Since inception) - End date future to be sure
        if(HistorySelect(0, AuroraClock::Now() + 86400)) {
                int deals = HistoryDealsTotal();
                for(int i=0; i<deals; i++) {
                ulong ticket = HistoryDealGetTicket(i);
                // Filter by Magic to strictly track EA performance
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber) {
                    pnl_total_hist += HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    pnl_total_hist += HistoryDealGetDouble(ticket, DEAL_SWAP);
                    pnl_total_hist += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                }
                }
        }
        g_cache_profit_total = pnl_total_hist;
        g_history_dirty = false;
        // if(InpLog_Dashboard) Print("[EA_DEBUG] History Scan Performed. Total=", g_cache_profit_total);
    }
    g_state.profit_total = g_cache_profit_total;
    
    // 4. News
    // Fetch upcoming events
    newsFilter.GetUpcomingEvents(InpDash_NewsRows, g_state.news);
    
    // DEBUG: Trace data flow
    if(InpDash_Enable && InpLog_Dashboard && ArraySize(g_state.news) > 0) {
        PrintFormat("[EA_DEBUG] OnTimer: Scraped %d news items for dashboard", ArraySize(g_state.news));
    }

    // 5. Update UI
    // 5. Update UI
    g_dashboard.Update(g_state);
}


//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (InpDash_Enable) {
        // Si le dashboard consomme l'événement (ex: clic bouton), on s'arrête là
        if (g_dashboard.OnEvent(id, lparam, dparam, sparam)) return;
    }
}


//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick() {
    bool allowEntry = true;
    bool allowManage = true;
    bool guardAllowEntry = true;
    bool guardPurgePending = false;

    UpdateTickCache(_Symbol);

    // =============================================
    
    // 0. Update Tick Buffers (Regime Smoothing)
    UpdateTickBuffer();
    
    // 0.5. Update Stress Mode State Machine (Once per Bar)
    UpdateStressMode();

    // --- REGIME FILTER: SPIKE GUARD (Circuit Breaker) ---
    // Protections against Flash Crash / Exhaustion Candles
    // Global Guard: Protects BOTH Reactive and Predictive strategies
    // Now uses IsFilterActive for Stress Mode support
    if (IsFilterActive(FILTER_SPIKE)) {
        // Calculate current range
        double high = iHigh(_Symbol, PERIOD_CURRENT, 0);
        double low  = iLow(_Symbol, PERIOD_CURRENT, 0);
        double range = high - low;
        
        // Calculate ATR (Safety: use iATR logic or Engine helper)
        double atr = CalculateATR(_Symbol, InpRegime_Spike_AtrPeriod, 1); // Index 1 (Closed) for reference
        
        if (atr > 0 && range > (atr * InpRegime_Spike_MaxAtrMult)) {
             // CANDLE EXPLOSION -> BLOCK NEW ENTRIES ONLY
             // We engage "Safety Mode". Do not touch orders. Do not enter.
             if(CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) { 
                  // Log throttled?
                  // CAuroraLogger::InfoStrategy("SPIKE EXTREME - TRADING SUSPENDU");
             }
             allowEntry = false; // Block Entry Logic downstream
             // return; // REMOVED: Do NOT return here, let management logic (Trailing/BE) run
        }
    }
    // ----------------------------------------------------

    // Check global stop logic (Weekend, News...)
    // if (g_weekend.BlockEntriesNow(AuroraClock::Now(), _Symbol)) return; // REMOVED: Redundant and blocks Trailing Stop!
    
    // --- SIMULATION TICK ---
    g_simulation.OnTick();
    // -----------------------
    
    // --- SNAPSHOT ARCHITECTURE (Speed of Light) ---
    // Capture state once per tick to avoid redundant API calls
    g_snapshot.Update(ea.GetMagic(), _Symbol);
    // ----------------------------------------------
    
    // --- ELASTIC VOLATILITY ---
    // Update the Hybrid Factor (VR * Noise) for dynamic SL/Trail scaling
    ea.UpdateElasticFactor();
    // --------------------------

    // Real-time Equity Check (Critical Security)
    if (EquityDrawdownLimit) ea.CheckForEquity(g_snapshot);

    // Real-time Margin Deleverage (Critical Security)

    
    // Real-time Guards (News & Weekend)
    // Run on EVERY tick to ensure immediate response
    datetime now = AuroraClock::Now();
    AuroraGuards::ProcessTick(
        g_session,
        g_weekend,
        newsFilter,
        ea,
        _Symbol,
        now,
        InpNews_Action,
        guardAllowEntry,
        allowManage,
        guardPurgePending);
    allowEntry = (allowEntry && guardAllowEntry);

    if (guardPurgePending) {
        ea.ClosePendingsForSymbol(_Symbol);
    }

    if (allowManage) {
        // Break‑Even (avant trailing)
        if (InpBE_Enable) {
            ea.CheckForBE(InpBE_Mode, InpBE_Trigger_Ratio, InpBE_Trigger_Pts, InpBE_Offset_SpreadMult, InpSL_Points, InpBE_OnNewBar, g_snapshot);
        }

        // Trailing statique (niveau issu des inputs)
        if (TrailingStop) {
            ea.CheckForTrailAndVirtual(g_snapshot);
        }

        // [EXIT-ON-CLOSE] Check Virtual Exits (On Bar Close)
        if (InpExit_OnClose) {
            // Only run on New Bar logic? 
            // The requirement was: "Sortie sur Clôture". So strictly inside `if (lastCandle != Time(0))`?
            // Wait, CheckVirtualExits does `iClose(..., 1)`. The candle 1 is closed.
            // So checking it on every tick is redundant but safe.
            // However, checking EXACTLY on bar open is cleaner.
            // BUT: If EA restarts mid-candle, we want to check immediately.
            // So calling it every tick is safer for robustness, unless perf issue.
            // Given it iterates <100 positions, it's fine.
            // BUT: Logic says "If Close[1] < SL". This condition is true for the WHOLE duration of the current bar.
            // So if we check every tick, we risk multiple attempts to close (which is fine).
            // Let's put it inside OnTick root to ensure we never miss a close.
            ea.CheckVirtualExits(g_snapshot);
        }
    }

    // --- HARDENING: REGIME FILTERS & GUARD (GLOBAL) ---
    // Placed here to protect BOTH Reactive and Predictive strategies
    // Now uses PRE-CALCULATED CACHE (Institutional Optimization)
    // Only Spike Guard remains real-time for immediate safety.
    
    // Update Dashboard State from Cache
    if (InpDash_Enable) g_state.regime_status = g_barCache.regimeStatus;
    
    if (g_barCache.regimeToxic) allowEntry = false; // KILL SWITCH ACTIVE (Blocks Strategy)
    
    // Use cached VWAP blocks
    bool blockBuy = g_barCache.vwapBlockBuy;
    bool blockSell = g_barCache.vwapBlockSell;
    
    // --------------------------------------------------

    // Trend Sniper Scaling (Pyramiding)
    if (TrendScale_Enable && allowManage) {
        double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        
        // Note: The Pyramiding module now expects a double score, not the whole Engine
        double currentConfidence = g_trendScaleConfidence;
        const bool exposureAllowed = IsNewExposureAllowed(allowEntry, "PYRAMIDING");
        
        g_pyramiding.Process(ea.GetMagic(), _Symbol, spread, currentConfidence, g_snapshot, exposureAllowed, ea.exitOnClose, ea.exitHardSLMult, ea.riskMaxTotalLots);
    }

    // --- Dashboard Update REMOVED from OnTick ---
    // Optimisation #1: Déplacé dans OnTimer pour alléger le tick critical path
    
    // New Bar Check: Only for Indicators and Entry Signals
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);
        
        // 0. Reset On-Bar Cache
        g_barCache.Reset();

        // Guards: buffers calculés (seulement si trade autorisé)
        if (HA_handle == INVALID_HANDLE || (!InpAdaptive_Enable && (CE_handle == INVALID_HANDLE || ZL_handle == INVALID_HANDLE))) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                CAuroraLogger::WarnDiag("Handle indicateur invalide (HA/CE/ZL)");
            return;
        }

        // --- ADAPTIVE VARIABLES SCOPE (Promoted) ---
        double er = 0.0;
        double volRatio = 1.0;
        double ceMult = 1.0; // Default Multiplier
        bool superTrendPredictiveInputReady = true;
        g_trendScaleConfidence = 0.0;

        if (InpStrategy_Core == STRAT_CORE_SUPER_TREND) {
            // Always Copy HA (Heiken Ashi used in both modes but strict in Momentum we might skip? 
            // Plan said force real price. But let's keep HA for potential dashboard use if needed)
            if (CopyBuffer(HA_handle, 3, 0, BuffSize, HA_C) <= 0) {
                if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                    CAuroraLogger::WarnDiag("CopyBuffer HA_C a échoué");
            }

            if (InpAdaptive_Enable) {
                // --- ADAPTIVE DYNAMIC LOGIC (OPTIMIZED & CACHED) ---
                
                // 1. Efficiency Ratio (Cached - Index 1 for Stability)
                er = CalculateEfficiencyRatio(_Symbol, InpAdaptive_ER_Period, PERIOD_CURRENT, 1);
                g_barCache.effRatio = er;
                
                // ... (Noise Logic) ...
                double rawNoiseFactor = CalculateNoiseFactor(er);
                g_adaptive_noise_factor = SmoothValue(g_adaptive_noise_factor, rawNoiseFactor, InpAdaptive_ZLS_Smooth);
                g_barCache.noiseFactor = g_adaptive_noise_factor;
                ea.SetNoiseFactor(g_adaptive_noise_factor);

                // ZLSMA Adaptation
                double targetPeriod = CalculateDynamicPeriodFromER(er, InpAdaptive_ZLS_MinPeriod, InpAdaptive_ZLS_MaxPeriod);
                g_adaptive_zlsma_period = SmoothValue(g_adaptive_zlsma_period, targetPeriod, InpAdaptive_ZLS_Smooth);
                
                // 2. Vectorized ZLSMA Calculation
                int zlsmaPeriod = (int)MathRound(g_adaptive_zlsma_period);
                if(zlsmaPeriod < 1) zlsmaPeriod = 1;
                
                int historyNeeded = MathMax(3, InpClose_ConfirmBars + 1);
                if (historyNeeded > BuffSize) historyNeeded = BuffSize;
                if (ArraySize(ZL) < historyNeeded) ArrayResize(ZL, historyNeeded);
                
                int reqHistory = (historyNeeded - 1) + 2 * zlsmaPeriod + 5; 
                double priceBuffer[];
                ArraySetAsSeries(priceBuffer, true);
                if(CopyClose(_Symbol, PERIOD_CURRENT, 0, reqHistory, priceBuffer) >= reqHistory) {
                    for(int i=0; i<historyNeeded; i++) {
                         ZL[i] = CalculateZLSMA_Manual(priceBuffer, zlsmaPeriod, i);
                    }
                } else {
                     superTrendPredictiveInputReady = false;
                     if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC)) CAuroraLogger::WarnDiag("Not enough history for ZLSMA Vectorized");
                }
                
                // 3. Volatility Ratio (Cached - Index 1)
                double atrShort = CalculateATR(_Symbol, InpAdaptive_Vol_ShortPeriod, 1);
                double atrLong = CalculateATR(_Symbol, InpAdaptive_Vol_LongPeriod, 1);
                if (atrLong > 0) volRatio = atrShort / atrLong;
                else volRatio = 1.0;
                
                g_barCache.volRatio = volRatio;
                
                // Update CE Mult
                ceMult = CalculateDynamicMultiplierFromVolRatio(volRatio, InpAdaptive_CE_BaseMult, InpAdaptive_CE_MinMult, InpAdaptive_CE_MaxMult);

                // 4. Update CE Trend State (Logic on Index 1 vs Index 2)
                // Calculate Stops for Index 1 (Completed Bar)
                // Reuse CeAtrPeriod for the ATR Lookback part
                double longStop1, shortStop1;
                CalculateChandelierExit_Manual(_Symbol, CeAtrPeriod, CeAtrPeriod, ceMult, 1, longStop1, shortStop1);
                
                double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
                
                if (g_adaptive_ce_trend == 0) {
                     // Init: Check where price is relative to potential stops
                     if (close1 > longStop1) {
                        g_adaptive_ce_trend = 1; 
                        g_adaptive_ce_long = longStop1;
                     } else {
                        g_adaptive_ce_trend = -1;
                        g_adaptive_ce_short = shortStop1;
                     }
                } else {
                     if (g_adaptive_ce_trend == 1) { // LONG
                         // Exit condition: Close < LongStop
                         if (close1 < g_adaptive_ce_long) {
                             g_adaptive_ce_trend = -1;
                             g_adaptive_ce_short = shortStop1; // Init Short Stop
                         } else {
                             // Trailing: Max(Prev, New)
                             g_adaptive_ce_long = MathMax(g_adaptive_ce_long, longStop1);
                         }
                     } else { // SHORT
                         // Exit condition: Close > ShortStop
                         if (close1 > g_adaptive_ce_short) {
                             g_adaptive_ce_trend = 1;
                             g_adaptive_ce_long = longStop1; // Init Long Stop
                         } else {
                             // Trailing: Min(Prev, New)
                             g_adaptive_ce_short = MathMin(g_adaptive_ce_short, shortStop1);
                         }
                     }
                }
                
                // Fill Buffers for Strategy
                // Strategy only checks index 1 for Setup, but might check history for Close
                // CE Arrays generally used at index 1 in BuySetup/SellSetup.
                // Reset buffer to clean state
                if (ArraySize(CE_B) < 2) ArrayResize(CE_B, BuffSize); // Safe size
                if (ArraySize(CE_S) < 2) ArrayResize(CE_S, BuffSize);
                
                ArrayInitialize(CE_B, 0.0);
                ArrayInitialize(CE_S, 0.0);
                
                CE_B[1] = (g_adaptive_ce_trend == 1) ? g_adaptive_ce_long : 0.0;
                CE_S[1] = (g_adaptive_ce_trend == -1) ? g_adaptive_ce_short : 0.0;
                
                // Debug / Visual Feedback via Comments (Optional, or explicit Log)
                if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC)) {
                    CAuroraLogger::InfoDiag(StringFormat("[ADAPT] ER=%.2f ZL_Per=%.1f | VolRat=%.2f CE_Mult=%.2f | Trend=%d", 
                        er, g_adaptive_zlsma_period, volRatio, ceMult, (g_adaptive_ce_trend==1?"LONG":(g_adaptive_ce_trend==-1?"SHORT":"INIT"))));
                }
                g_trendScaleConfidence = (MathIsValidNumber(er) ? MathMax(0.0, MathMin(1.0, er)) : 0.0);
                
                // VISUAL DEBUGGING (Backtest)
                if (MQLInfoInteger(MQL_VISUAL_MODE) && InpLog_Diagnostic) {
                   Comment(StringFormat(
                       "=== ADAPTIVE INDICATORS ===\n"
                       "Efficiency Ratio : %.2f\n"
                       "Noise Factor     : %.2f\n"
                       "ZLSMA Period     : %.1f\n"
                       "Volatility Ratio : %.2f\n"
                       "CE Multiplier    : %.2f\n"
                       "CE Trend         : %s",
                       er, g_adaptive_noise_factor, g_adaptive_zlsma_period, volRatio, ceMult, (g_adaptive_ce_trend==1?"LONG":(g_adaptive_ce_trend==-1?"SHORT":"INIT"))
                   ));
                }
            } else {
                 // --- FIXED MODE (NON-ADAPTIVE) ---
                 // Copy Buffers from Handles (Legacy)
                 if (CopyBuffer(ZL_handle, 0, 0, BuffSize, ZL) <= 0 ||
                     CopyBuffer(CE_handle, 0, 0, BuffSize, CE_B) <= 0 ||
                     CopyBuffer(CE_handle, 1, 0, BuffSize, CE_S) <= 0) 
	                 {
	                     if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC)) CAuroraLogger::WarnDiag("CopyBuffer Fixed SuperTrend Failed");
	                     return;
	                 }
                     double atrConf = CalculateATR(_Symbol, MathMax(2, InpSL_AtrPeriod), 1);
                     double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
                     if (atrConf > 0.0 && MathIsValidNumber(close1) && MathIsValidNumber(ZL[1]))
                         g_trendScaleConfidence = MathMax(0.0, MathMin(1.0, MathAbs(close1 - ZL[1]) / (atrConf * 2.0)));
                     else
                         g_trendScaleConfidence = 0.0;
	            }

                if (ArraySize(ZL) <= 1 || !MathIsValidNumber(ZL[1]) || ZL[1] <= 0.0 || ZL[1] == EMPTY_VALUE) {
                    superTrendPredictiveInputReady = false;
                }
	        }

        // MOMENTUM Handling (Independent Block now)
        if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
             if (InpSmartMom_Enable) {
                 // --- MOMENTUM DYNAMIC LOGIC ---
                 double atrShort = CalculateATR(_Symbol, InpSmartMom_Vol_Short, 1);
                 double atrLong = CalculateATR(_Symbol, InpSmartMom_Vol_Long, 1);
                 if (atrLong > 0) volRatio = atrShort / atrLong;
                 g_barCache.volRatio = volRatio;
             }
             
             // Always Copy AKKE for Momentum
	             if (CopyBuffer(AKKE_handle, 0, 0, BuffSize, AKKE_Kama) <= 0 ||
                 CopyBuffer(AKKE_handle, 1, 0, BuffSize, AKKE_Dn) <= 0 ||
                 CopyBuffer(AKKE_handle, 2, 0, BuffSize, AKKE_Up) <= 0 ||
                 CopyBuffer(AKKE_handle, 3, 0, BuffSize, AKKE_Er) <= 0) 
	             {
	                 if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC)) CAuroraLogger::WarnDiag("CopyBuffer AKKE Failed");
	                 return;
	             }
                 if (ArraySize(AKKE_Er) > 1 && MathIsValidNumber(AKKE_Er[1]))
                     g_trendScaleConfidence = MathMax(0.0, MathMin(1.0, AKKE_Er[1]));
                 else
                     g_trendScaleConfidence = 0.0;
	        }
        
        // --- 5. REGIME ANALYSIS (NEW BAR) ---
        // Analyze Market Health once per bar for stability
        
        // A. Hurst Exponent
        if (IsFilterActive(FILTER_HURST) && Hurst_handle != INVALID_HANDLE) {
            if (CopyBuffer(Hurst_handle, 0, 1, 1, Hurst_Buffer) > 0) { // Ref index 1 for confirmed structure
                double h = Hurst_Buffer[0];
                if (h > 0.0 && h < InpHurst_Threshold) {
                   g_barCache.regimeToxic = true;
                   g_barCache.regimeStatus = StringFormat("TOXIC (H=%.2f)", h);
                }
            }
        }
        
        // B. Kurtosis (Fat Tails)
        if (!g_barCache.regimeToxic && IsFilterActive(FILTER_KURTOSIS) && Kurtosis_handle != INVALID_HANDLE) {
            if (CopyBuffer(Kurtosis_handle, 0, 1, 1, Kurtosis_Buffer) > 0) {
                double k = Kurtosis_Buffer[0];
                if (k > InpKurtosis_Threshold) {
                    g_barCache.regimeToxic = true;
                    g_barCache.regimeStatus = StringFormat("FAT TAIL (K=%.2f)", k);
                }
            }
        }
        
        // C. VWAP Gravity (Snapshot at Bar Open)
        if (!g_barCache.regimeToxic && IsFilterActive(FILTER_VWAP) && VWAP_handle != INVALID_HANDLE) {
            double price = iClose(_Symbol, PERIOD_CURRENT, 0); // Open of new bar ~ Close of prev
            if (CopyBuffer(VWAP_handle, 1, 1, 1, VWAP_Upper) > 0 && CopyBuffer(VWAP_handle, 2, 1, 1, VWAP_Lower) > 0) {
                if (price > VWAP_Upper[0]) {
                    g_barCache.vwapBlockBuy = true;
                    g_barCache.regimeStatus = "GRAVITY (HIGH)";
                }
                if (price < VWAP_Lower[0]) {
                    g_barCache.vwapBlockSell = true;
                    g_barCache.regimeStatus = "GRAVITY (LOW)";
                }
            }
        }
        
        // D. Trap Candle (Cached for both Reactive and Predictive)
        if (InpTrap_Enable && Trap_handle != INVALID_HANDLE) {
            if (CopyBuffer(Trap_handle, 2, 1, 1, Trap_Signal) > 0) {
                g_barCache.trapSignal = (Trap_Signal[0] == 1.0);
            }
        }
        
	        // --- 6. PREDICTIVE (APE) TARGET SETUP ---
	        // Pre-calculate entry/SL/volume once per bar to keep OnTick lightweight and deterministic.
	        if (InpEntry_Strategy == STRATEGY_PREDICTIVE) {
                g_barCache.predictiveLevelsReady = false;
	            double risk = ea.risk;

	            if (InpStrategy_Core == STRAT_CORE_MOMENTUM) {
	                // Pre-calculate from KAMA bands (never trust raw buffers directly).
	                double up = 0.0, dn = 0.0;
	                if (!GetSmartMomentumBands(up, dn, 1)) {
	                    g_barCache.predBuyPrice = 0.0;
	                    g_barCache.predSellPrice = 0.0;
	                    g_barCache.predSL_Buy = 0.0;
	                    g_barCache.predSL_Sell = 0.0;
	                    g_barCache.predVolBuy = 0.0;
	                    g_barCache.predVolSell = 0.0;
                        g_barCache.predictiveLevelsReady = false;
	                    if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
	                        CAuroraLogger::WarnDiag("[APE] Momentum bands invalid (KAMA/ATR). Predictive levels disabled for this bar.");
	                } else {
	                    g_barCache.predBuyPrice = NormalizePrice(up, _Symbol);
	                    g_barCache.predSellPrice = NormalizePrice(dn, _Symbol);
	                }
	            } else {
                    if (!superTrendPredictiveInputReady) {
                        g_barCache.predBuyPrice = 0.0;
                        g_barCache.predSellPrice = 0.0;
                        g_barCache.predSL_Buy = 0.0;
                        g_barCache.predSL_Sell = 0.0;
                        g_barCache.predVolBuy = 0.0;
                        g_barCache.predVolSell = 0.0;
                        if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                            CAuroraLogger::WarnDiag("[APE] SuperTrend predictive inputs invalid. Levels disabled for this bar.");
                    } else {
	                // Pre-calculate from ZLSMA / CE.
	                double offsetPts = 0.0;
	                if (InpPredictive_Offset_Mode == OFFSET_MODE_ATR) {
	                    double atr_pred = CalculateATR(_Symbol, InpPredictive_ATR_Period, 1);
	                    offsetPts = atr_pred * InpPredictive_ATR_Mult;
	                } else {
	                    offsetPts = InpPredictive_Offset * _Point;
	                }
	                
	                g_barCache.predBuyPrice = NormalizePrice(ZL[1] + offsetPts, _Symbol);
	                g_barCache.predSellPrice = NormalizePrice(ZL[1] - offsetPts, _Symbol);
                    }
	            }

	            if (!MathIsValidNumber(g_barCache.predBuyPrice) ||
	                !MathIsValidNumber(g_barCache.predSellPrice) ||
	                g_barCache.predBuyPrice <= 0.0 ||
	                g_barCache.predSellPrice <= 0.0 ||
	                g_barCache.predSellPrice >= g_barCache.predBuyPrice ||
	                !BuildPredictiveRiskLeg(true, g_barCache.predBuyPrice, risk, g_barCache.predSL_Buy, g_barCache.predVolBuy) ||
	                !BuildPredictiveRiskLeg(false, g_barCache.predSellPrice, risk, g_barCache.predSL_Sell, g_barCache.predVolSell)) {
	                g_barCache.predBuyPrice = 0.0;
	                g_barCache.predSellPrice = 0.0;
	                g_barCache.predSL_Buy = 0.0;
	                g_barCache.predSL_Sell = 0.0;
	                g_barCache.predVolBuy = 0.0;
	                g_barCache.predVolSell = 0.0;
                    g_barCache.predictiveLevelsReady = false;
	                if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
	                    CAuroraLogger::WarnDiag("[APE] Predictive SL/volume invalid for selected InpSL_Mode. Levels disabled for this bar.");
	            } else {
                    g_barCache.predictiveLevelsReady = true;
	            }
	        }

        if (CloseOrders) CheckClose();




        // --- Entry Logic (Signaux d'entrée seulement à la clôture de bougie) ---
        if (InpEntry_Strategy == STRATEGY_REACTIVE) {
        if (!IsNewExposureAllowed(allowEntry, "REACTIVE")) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;

        

        

        
        // Filtre Limite Journalière
        if (InpMaxDailyTrades != -1) {
             int dailyTrades = GetDailyTradeCount();
             if (dailyTrades >= InpMaxDailyTrades) {
                 if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
                     // Log once per bar to avoid spam (implicitly handled by bar close event here)
                     CAuroraLogger::InfoStrategy(StringFormat("Limite journalière atteinte (%d/%d). Entrée bloquée.", dailyTrades, InpMaxDailyTrades));
                 }
                 return;
             }
        }
        
        // Filtres Regime (Moved to Global)

        
        // -----------------------------------------
        
        if (!MultipleOpenPos && ea.OPTotal() > 0) return;

        // Filtre côté — appliquer après inversion éventuelle (Reverse)
        const bool buySetupNow  = (!blockBuy && BuySetup());
        const bool sellSetupNow = (!blockSell && SellSetup());

        // Après inversion: quel setup produit quel type d'ordre final ?
        const bool finalBuySetup  = (!Reverse ? buySetupNow  : sellSetupNow);
        const bool finalSellSetup = (!Reverse ? sellSetupNow : buySetupNow);
        
        // --- EXECUTION GUARD (1 Trade Per Bar) ---
        datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
        
        bool alreadyTraded = (InpGuard_OneTradePerBar && HasTradedOnBar(_Symbol, MagicNumber, currentBar));
        
        if (alreadyTraded) return; // Déjà traité cette bougie
        // -----------------------------------------

        if (InpOpen_Side == DIR_LONG_ONLY) {
            if (finalSellSetup && CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                CAuroraLogger::InfoStrategy("Signal VENTE bloqué par filtre côté (LONG seulement)");
            // Ouvrir uniquement des BUY finaux
            if (!Reverse) { if (buySetupNow) { if(BuySignal()) g_lastSignalBar = currentBar; return; } }
            else          { if (sellSetupNow){ if(SellSignal()) g_lastSignalBar = currentBar; return; } }
        }
        else if (InpOpen_Side == DIR_SHORT_ONLY) {
            if (finalBuySetup && CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                CAuroraLogger::InfoStrategy("Signal ACHAT bloqué par filtre côté (SHORT seulement)");
            // Ouvrir uniquement des SELL finaux
            if (!Reverse) { if (sellSetupNow){ if(SellSignal()) g_lastSignalBar = currentBar; return; } }
            else          { if (buySetupNow) { if(BuySignal()) g_lastSignalBar = currentBar; return; } }
        }
        else { // ACHATS+VENTES
            // Prioriser BUY final, puis SELL final
            if (!Reverse) {
                if (buySetupNow) { if(BuySignal()) { g_lastSignalBar=currentBar; return; } }
                if (sellSetupNow) { if(SellSignal()) { g_lastSignalBar=currentBar; return; } }
            } else {
                if (sellSetupNow) { if(SellSignal()) { g_lastSignalBar=currentBar; return; } }
                if (buySetupNow) { if(BuySignal()) { g_lastSignalBar=currentBar; return; } }
            }
        } // Close ACHATS+VENTES

    } // Close Reactive
    } // Close New Bar Logic

    // --- PREDICTIVE STRATEGY (EVERY TICK) ---
    // Safe Execution: Buffers are guaranteed to be populated by New Bar logic above, 
    // BUT we must check the buffers RELEVANT to the active strategy.
    if (InpEntry_Strategy == STRATEGY_PREDICTIVE) {
        bool ready = false;
        if (InpStrategy_Core == STRAT_CORE_SUPER_TREND) {
             ready = (ArraySize(ZL)>0 && ArraySize(CE_B)>1 && ArraySize(CE_S)>1);
        } else {
             // Momentum
             ready = (ArraySize(AKKE_Up)>0 && ArraySize(AKKE_Dn)>0 && ArraySize(AKKE_Kama)>0 && ArraySize(AKKE_Er)>0);
        }
        
        if (ready) {
            ManagePredictiveOrders(blockBuy, blockSell, allowEntry);
        }
    }
    // ----------------------------------------
}


//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result) {
    g_asyncManager.OnTradeTransaction(trans, request, result);

    if (trans.type == TRADE_TRANSACTION_REQUEST) {
        // Log request result (Async acknowledgement or failure)
        bool ok = (result.retcode == TRADE_RETCODE_DONE ||
                   result.retcode == TRADE_RETCODE_DONE_PARTIAL ||
                   result.retcode == TRADE_RETCODE_PLACED ||
                   result.retcode == TRADE_RETCODE_NO_CHANGES);
        if (!ok) {
             if (CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) {
                string action = EnumToString(request.action);
                CAuroraLogger::ErrorOrders(StringFormat("[ASYNC] Request Failed: %s, Retcode=%u (%s), Comment=%s", 
                    action, result.retcode, TradeServerReturnCodeDescription(result.retcode), result.comment));
             }
        }
    } else if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        // Flag history as dirty to trigger update on next timer
        g_history_dirty = true;
        g_snapshot.Invalidate(); // Force Snapshot Refresh (Commission Cache)
        
        datetime dealTime = AuroraClock::Now();
        
        if (trans.deal > 0) {
            // Narrow history window for this deal
            bool historyReady = HistorySelect(0, AuroraClock::Now() + 60);
            if (historyReady) {
                long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
                string dealSymbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
                long dealEntry = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
                datetime dealTimeRaw = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
                if (dealTimeRaw > 0) dealTime = dealTimeRaw;
                
                double comm = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
                double fee = HistoryDealGetDouble(trans.deal, DEAL_FEE);
                if (trans.position > 0) g_snapshot.AddCommission(trans.position, comm + fee);
                
                if (dealMagic == (long)MagicNumber && dealSymbol == _Symbol && dealEntry == DEAL_ENTRY_IN) {
                    datetime day = iTime(_Symbol, PERIOD_D1, 0);
                    if (day != g_daily_trade_day) {
                        g_daily_trade_day = day;
                        g_daily_trade_count = 0;
                    }
                    g_daily_trade_count++;
                    g_lastTradeTime = dealTime;
                    g_lastTradeBar = ResolveTradeBarFromTime(dealTime);
                    g_lastSignalBar = g_lastTradeBar;
                }
            }
        }
        
        if (trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL) {
             if (CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) {
                CAuroraLogger::InfoOrders(StringFormat("[ASYNC] Deal Executed: Ticket=%I64u, Vol=%.2f, Price=%.5f", 
                    trans.deal, trans.volume, trans.price));
             }

             // [LOGIC-3] Init Virtual Stop immediately on fill
             if (PositionSelectByTicket(trans.position)) {
                 if (PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
                     double sl = PositionGetDouble(POSITION_SL);
                     ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                     ea.InitVirtualStopIfNeeded(trans.position, sl, ptype);
                 }
             }
        }
    }
}

double OnTester()
{
    return 0.0;
}

//+------------------------------------------------------------------+
