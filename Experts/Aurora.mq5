//+------------------------------------------------------------------+
//|                                                       Aurora.mq5 |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright     "Copyright 2026, Tommy Suzanne"
#property link          " https://github.com/tommysuzanne"
#property version       "2.20"
#property description   "L'avenir appartient à ceux qui comprennent que la vraie économie est solaire : donner sans s'appauvrir."
#property icon          "\\Images\\Aurora_Icon.ico"
#property strict

#include <aurora_async_manager.mqh>
CAsyncOrderManager g_asyncManager; // Instance globale
#include <aurora_engine.mqh>
#include <aurora_constants.mqh>
#include <aurora_session_manager.mqh>
#include <aurora_weekend_guard.mqh>
#include <aurora_newsfilter.mqh>
#include <aurora_guard_pipeline.mqh>
#include <aurora_inputs_structs.mqh>
#include <aurora_confidence_engine.mqh>
#include <aurora_pyramiding.mqh>
#include <aurora_dashboard.mqh>
#include <aurora_state_structs.mqh> // Ajout State

input group "1.1 - Indicateurs"
input int               CeAtrPeriod = 1; // Période ATR du Chandelier (barres)
input double            CeAtrMult = 0.75; // Multiplicateur ATR du Chandelier (×)
input int               ZlPeriod = 50; // Période ZLSMA (barres)

input group "1.2 - Grille"
input bool              Grid = true; // Activer la MartinGale
input double            GridVolMult = 1.5; // Multiplicateur de volume de la grille
input double            GridTrailingStopLevel = 0; // Niveau de trailing de la grille (%) (0 = désactivé)
input int               GridMaxLvl = 50; // Niveaux max de grille

input group "1.3 - Grille Dynamique"
input bool                      GridDynamic      = false; // Activer la grille dynamique (ATR)
input int                       GridAtrPeriod    = 14;    // Période ATR Grille
input double                    GridAtrMult      = 1.0;   // Multiplicateur ATR Grille
input double                    GridMaxATR       = 0.0;   // Max ATR pour ajout Grille (0 = désactivé)
input ENUM_GRID_PROFIT_MODE     GridProfitMode   = GRID_PROFIT_CURRENCY; // Mode de Profit Grille
input double                    GridMinProfit    = 0.0;   // Profit Min Grille (Valeur selon le mode)

input group "1.4 - Grille Infinie"
input bool                      Grid_Infinity_Enable = false;         // Activer le trailing sur panier
input double                    Grid_Infinity_Trigger = 90.0;         // Déclencheur Infinity (% de l'Objectif)
input ENUM_INFINITY_STEP_MODE   Grid_Infinity_StepMode = INF_STEP_POINTS; // Mode de Trailing Infinity
input double                    Grid_Infinity_TrailingStep = 40.0;    // Pas du Trailing Infinity (points/%)
input int                       Grid_Infinity_AtrPeriod    = 14;      // Période ATR (Mode ATR)
input double                    Grid_Infinity_AtrMult      = 1.5;     // Multiplicateur ATR (Mode ATR)
input int                       InpInfinity_TP_Distance = 50000;      // Distance TP Infinity (points)

input group "1.5 - Grille Intelligente"
input bool                      SmartGrid_Reduction_Enable = false;    // Activer  la réduction active de drawdown
input int                       SmartGrid_Reduction_StartLvl = 2;     // Niveau pour commencer la réduction
input double                    SmartGrid_Reduction_ProfitRatio = 90.0;// Ratio profit gain/perte (%) 
input double                    SmartGrid_Reduction_MinVol = 0.10;    // Volume min à fermer partiel
input double                    SmartGrid_Reduction_WinnerClosePercent = 50.0; // % Clôture Position Gagnante

input group "2.1 - Gestion du risque"
input ENUM_RISK                 RiskMode = RISK_DEFAULT; // Mode de risque
input double                    Risk = 3; // Risque par trade (%/lot selon le mode)
input double                    EquityDrawdownLimit = 0; // Limite de drawdown sur l’équity (%) (0 = désactivé)
input bool                      IgnoreSL = true; // Stop Loss - Ignorer
input int                       SLDev = 650; // Stop Loss - Déviation (points)
input bool                      TrailingStop       = true;  // Trailing Stop - Activer
input ENUM_TRAIL_MODE           TrailMode          = TRAIL_STANDARD; // Trailing Stop - Mode de Trailing
input double                    TrailingStopLevel  = 50.0;  // Trailing Stop - Niveau de trailing (% du SL)
input int                       TrailAtrPeriod     = 14;    // Trailing Stop - Période ATR (Mode ATR)
input double                    TrailAtrMult       = 2.5;   // Trailing Stop - Multiplicateur ATR (Mode ATR)
input bool                      InpBE_Enable             = false; // Break‑Even — Activer
input ENUM_BE_MODE              InpBE_Mode               = BE_MODE_RATIO; // Break‑Even - Mode de déclenchement
input double                    InpBE_Trigger_Ratio      = 1.0;   // Break‑Even — Déclencheur (Ratio du SL)
input int                       InpBE_Trigger_Pts        = 100;   // Break‑Even — Déclencheur (Points fixes)
input double                    InpBE_Offset_SpreadMult  = 1.5;   // Break‑Even — Offset (spread×k) [0–5]
input int                       InpBE_Min_Offset_Pts     = 10;    // Break‑Even — Offset minimum (points)
input bool                      InpBE_OnNewBar           = true;  // Break‑Even — Appliquer à la nouvelle bougie uniquement

input group "2.2 - Gestion du risque dynamique"
input bool                      DynRisk_Enable = false; // Activer le calcul de lot dynamique
input double                    DynRisk_MinFactor = 0.5; // Facteur de risque Minimum (0.5 = -50%)
input double                    DynRisk_MaxFactor = 1.5; // Facteur de risque Maximum (1.5 = +50%)
input double                    DynRisk_W_ER = 40.0;    // Poids de l'Efficacité Kaufman (%)
input double                    DynRisk_W_Slope = 40.0; // Poids de la stabilité ZLSMA (%)
input double                    DynRisk_W_Vol = 20.0;   // Poids de la volatilité (%)
input int                       DynRisk_ER_Period = 10; // Période Efficiency Ratio
input int                       DynRisk_Slope_Period = 5;// Période calcul pente (ZLSMA)

input group "2.3 - Pyramidage"
input bool                      TrendScale_Enable = false; // Activer le pyramidage
input int                       TrendScale_MaxLayers = 3;  // Nombre max d'ajouts
input double                    TrendScale_StepPts = 500;  // Distance en points pour déclencher un ajout (points)
input double                    TrendScale_VolMult = 1.0;  // Multiplicateur de volume pour l'ajout [0.5-2.0]
input double                    TrendScale_MinConf = 0.8;  // Score de confiance min requis [0.0-1.0]
input bool                      TrendScale_TrailSync = true;// Activer la syncronisation du SL (Trailing de groupe)
input ENUM_PYRA_TRAIL_MODE      TrendScale_TrailMode   = PYRA_TRAIL_POINTS; // Mode de Trailing (Points/ATR)
input int                       TrendScale_TrailDist_2 = 300;      // Distance Trailing (2 couches) (points)
input int                       TrendScale_TrailDist_3 = 150;      // Distance Trailing (3+ couches) (points)
input int                       TrendScale_ATR_Period  = 14;       // Période ATR
input double                    TrendScale_ATR_Mult_2  = 2.0;      // Multiplicateur ATR (2 couches)
input double                    TrendScale_ATR_Mult_3  = 1.0;      // Multiplicateur ATR (3+ couches)

input group "2.4 - Gestion des marges"
input double                    MarginLimit = 0; // Entrée - Limite de Marge Min (%) (0 = désactivé)
input bool                      MarginGuard_Enable = true; // Activer la protection de marge
input double                    MarginGuard_Stretch_Level = 2000.0; // Stretch - Niveau Marge pour écarter la grille (%)
input double                    MarginGuard_Stretch_MaxMult = 5.0;  // Stretch - Multiplicateur Max d'écartement (x)
input double                    MarginGuard_Delev_Level = 150.0; // Deleverage - Niveau Critique pour couper les positions (%)
input bool                      MarginGuard_Delev_Worst = true;  // Deleverage - Fermer le pire trade (True) ou le plus vieux (False)
input bool                      MarginGuard_Damping_Enable = true; // Damping - Activer - Réduire le volume
input double                    MarginGuard_Damping_Start = 1500.0; // Damping - Niveau de marge pour démarrer (%)
input double                    MarginGuard_Damping_MinMult = 0.8;  // Damping - Multiplicateur Min (x)
input double                    InpMarginGuard_Damping_Floor = 500.0; // Damping - Niveau plancher (%)

input group "3.1 - Ouverture & Système"
enum AURORA_OPEN_SIDE { ACHATS=0, VENTES=1, ACHATS_VENTES=2 };
input AURORA_OPEN_SIDE          InpOpen_Side = ACHATS_VENTES; // Type de positions (Achat / Vente / Les deux)
input double                    InpMaxTotalLots = -1; // Volume total maximum autorisé (-1 = illimité)
input int                       SpreadLimit = -1; // Limite de spread (points) (-1 = désactivé)
input int                       Slippage = 30; // Slippage (points)
input int                       SignalMaxGapPts = 200; // Max écart prix/signal (points) (-1 = désactivé)
input int                       TimerInterval = 1; // Intervalle du timer (secondes)

input group "3.2 - Gestion des sessions"
input bool                      InpSess_EnableTime = false; // Activer la session horaire
input int                       InpSess_StartHour = 0;     // Heure de début [0–23]
input int                       InpSess_StartMin  = 0;     // Minutes de début [0–59]
input int                       InpSess_EndHour   = 23;    // Heure de fin [0–23]
input int                       InpSess_EndMin    = 59;    // Minutes de fin [0–59]
input ENUM_SESSION_CLOSE_MODE   InpSess_CloseMode = SESS_MODE_OFF; // Mode de clôture de la session horaire
input double                    InpSess_DelevTargetPct = 50.0;     // Allègement - % Volume à conserver
input bool                      InpSess_TradeMon = true;   // Trader le lundi
input bool                      InpSess_TradeTue = true;   // Trader le mardi
input bool                      InpSess_TradeWed = true;   // Trader le mercredi
input bool                      InpSess_TradeThu = true;   // Trader le jeudi
input bool                      InpSess_TradeFri = true;   // Trader le vendredi
input bool                      InpSess_TradeSat = false;  // Trader le samedi
input bool                      InpSess_TradeSun = false;  // Trader le dimanche
input bool                      InpSess_CloseRestricted = false; // Fermer positions jours non autorisés
input bool                      InpWeekend_Enable    = false; // Fermer positions avant le week‑end
input int                       InpWeekend_BufferMin = 30;    // Marge avant fermeture (minutes) [5–120]
input int                       InpWeekend_GapMinHours = 2;   // Gap min. week‑end (heures) [2–6]
input int                       InpWeekend_BlockNewBeforeMin = 30; // Bloquer nouvelles entrées avant close (minutes)
input bool                      InpWeekend_ClosePendings = true;   // Fermer ordres en attente avant close
input bool                      InpSess_RespectBrokerSessions = true; // Respecter les sessions broker

input group "3.3 Gestion des actualités"
input bool                      InpNews_Enable = true; // Activer le filtre d'actualités
input ENUM_NEWS_LEVELS          InpNews_Levels = NEWS_LEVELS_HIGH_MEDIUM; // Niveaux bloqués (Aucune/Fortes/Fortes+Moyennes/Toutes)
input string                    InpNews_Ccy = "USD"; // Devises surveillées (vide = auto)
input int                       InpNews_BlackoutB = 30; // Fenêtre avant news (minutes) [0–240]
input int                       InpNews_BlackoutA = 15; // Fenêtre après news (minutes) [0–240]
input int                       InpNews_MinCoreHighMin = 2; // Noyau minimal news fortes (minutes ≥0)
input ENUM_NEWS_ACTION          InpNews_Action = NEWS_ACTION_MONITOR_ONLY; // Action pendant la fenêtre (Bloquer entrées/gestion/Tout et fermer)
input int                       InpNews_RefreshMin = 15; // Rafraîchissement calendrier (minutes ≥1)

input group "3.4 - Options supplémentaires"
input ulong                     MagicNumber = 336633; // Numéro magique
input bool                      OpenNewPos = true; // Autoriser l’ouverture de nouvelles positions
input ENUM_FILLING              Filling = FILLING_DEFAULT; // Type de remplissage des ordres (Auto/FOK/IOC/RETURN)
input bool                      CloseOrders = false; // Clôturer sur signal inverse (HA/ZLSMA)
input int                       InpClose_ConfirmBars     = 2;   // Clôture inverse — Barres de confirmation [1–4]
input bool                      InpGrid_SuspendOnInverse = true; // Suspendre l'ajout de niveaux Grid si inversion non confirmée
input bool                      Reverse = false; // Inverser la direction des signaux (Buy↔Sell)
input bool                      MultipleOpenPos = false; // Autoriser plusieurs positions simultanées
input double                    InpVirtualBalance = -1; // Solde Virtuel (0 ou -1 = Désactivé)

input group "3.5 - Interface Graphique"
input bool                      InpDash_Enable   = false;  // Activer le Dashboard
input int                       InpDash_NewsRows = 5;     // Nombre de lignes de News à afficher
input int                       InpDash_Scale    = 0;     // Echelle % (0 = Auto DPI)
input ENUM_BASE_CORNER          InpDash_Corner   = CORNER_LEFT_UPPER; // Coin d'ancrage du dashboard

input group "3.6 - Logs"
input bool                      InpLog_General   = false;  // Journaux généraux (init, erreurs)
input bool                      InpLog_Position  = false; // Positions (ouvertures/fermetures auto)
input bool                      InpLog_Risk      = false; // Gestion du risque (equity/DD/volumes)
input bool                      InpLog_Session   = false; // Sessions (hors news)
input bool                      InpLog_News      = false; // News & calendrier économique
input bool                      InpLog_Strategy  = false; // Stratégie/Signaux
input bool                      InpLog_Orders    = false; // Trading/ordres (retcodes)
input bool                      InpLog_Diagnostic= false; // Diagnostic technique (buffers, indicateurs)
input bool                      InpLog_Dashboard = false; // Dashboard (Interface/Rendu)

const int BuffSize = AURORA_BUFF_SIZE;

GerEA ea;
datetime lastCandle;
datetime tc;
CAuroraSessionManager g_session;
CAuroraWeekendGuard   g_weekend;
CAuroraNewsFilter newsFilter;
CAuroraConfidenceEngine g_confidence;
CAuroraPyramiding       g_pyramiding;
CAuroraDashboard        g_dashboard;
SAuroraState            g_state; // State Global

// Stats Globals
double g_max_dd_alltime = 0.0;
double g_max_dd_daily = 0.0;
datetime g_last_stat_day = 0;
// Note: Profit Total calculated on the fly or via history
double g_cache_profit_total = 0.0;
bool   g_history_dirty = true;

bool                  g_suspend_grid = false;
string                g_gv_dd_name = ""; // Persistence Key

#define PATH_HA "Indicators\\Examples\\Heiken_Ashi.ex5"
#define I_HA "::" + PATH_HA
#resource "\\" + PATH_HA
int HA_handle;
double HA_C[];

#define PATH_CE "Indicators\\ChandelierExit.ex5"
#define I_CE "::" + PATH_CE
#resource "\\" + PATH_CE
int CE_handle;
double CE_B[], CE_S[];

#define PATH_ZL "Indicators\\ZLSMA.ex5"
#define I_ZL "::" + PATH_ZL
#resource "\\" + PATH_ZL
int ZL_handle;
double ZL[];

// Détermine l'exposition actuelle (achats/ventes) de l'EA pour filtrer la suspension Grid
void GetPositionExposure(bool &hasBuys, bool &hasSells) {
    hasBuys = false;
    hasSells = false;
    const ulong magic = ea.GetMagic();
    const int total = PositionsTotal();
    for (int i = 0; i < total; ++i) {
        const ulong ticket = PositionGetTicket(i);
        if (ticket == 0) continue;
        if (!PositionSelectByTicket(ticket)) continue;
        if ((ulong)PositionGetInteger(POSITION_MAGIC) != magic) continue;
        const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        if (type == POSITION_TYPE_BUY) hasBuys = true;
        else if (type == POSITION_TYPE_SELL) hasSells = true;
        if (hasBuys && hasSells) break;
    }
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
    sess.close_mode           = InpSess_CloseMode;
    sess.deleverage_target_pct= InpSess_DelevTargetPct;
    sess.close_restricted_days= InpSess_CloseRestricted;
    sess.respect_broker_sessions = InpSess_RespectBrokerSessions;
    return sess;
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

SDynamicRiskInputs MakeDynamicRiskInputs() {
    SDynamicRiskInputs d;
    d.enable = DynRisk_Enable;
    d.min_risk_factor = DynRisk_MinFactor;
    d.max_risk_factor = DynRisk_MaxFactor;
    d.weight_efficiency = DynRisk_W_ER;
    d.weight_trend_stability = DynRisk_W_Slope;
    d.weight_volatility = DynRisk_W_Vol;
    d.er_period = DynRisk_ER_Period;
    d.zlsma_slope_period = DynRisk_Slope_Period;
    return d;
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
    s.grid = Grid;
    s.grid_vol_mult = GridVolMult;
    s.grid_trail_level = GridTrailingStopLevel;
    s.grid_max_lvl = GridMaxLvl;
    
    // Nouveaux paramètres Grid (v1.31+)
    s.grid_dynamic = GridDynamic;
    s.grid_atr_period = GridAtrPeriod;
    s.grid_atr_mult = GridAtrMult;
    s.grid_min_profit = GridMinProfit;
    s.grid_profit_mode = (int)GridProfitMode;
    s.grid_max_atr = GridMaxATR;
    return s;
}

SMarginGuardInputs MakeMarginGuardInputs() {
    SMarginGuardInputs m;
    m.enable = MarginGuard_Enable;
    m.stretch_level = MarginGuard_Stretch_Level;
    m.stretch_max_mult = MarginGuard_Stretch_MaxMult;
    m.delev_level = MarginGuard_Delev_Level;
    m.delev_worst = MarginGuard_Delev_Worst;
    m.damping_enable = MarginGuard_Damping_Enable;
    m.damping_start = MarginGuard_Damping_Start;
    m.damping_min_mult = MarginGuard_Damping_MinMult;
    m.damping_low_bound = InpMarginGuard_Damping_Floor;
    return m;
}

SSmartGridInputs MakeSmartGridInputs() {
    SSmartGridInputs s;
    s.reduction_enable = SmartGrid_Reduction_Enable;
    s.reduction_start_lvl = SmartGrid_Reduction_StartLvl;
    s.reduction_profit_ratio = SmartGrid_Reduction_ProfitRatio;
    s.reduction_min_vol = SmartGrid_Reduction_MinVol;
    s.reduction_winner_close_percent = SmartGrid_Reduction_WinnerClosePercent;
    return s;
}

SInfinityInputs MakeInfinityInputs() {
    SInfinityInputs i;
    i.enable = Grid_Infinity_Enable;
    i.trigger_pct = Grid_Infinity_Trigger;
    i.step_mode = Grid_Infinity_StepMode;
    i.trailing_step = Grid_Infinity_TrailingStep;
    i.atr_period = Grid_Infinity_AtrPeriod;
    i.atr_mult = Grid_Infinity_AtrMult;
    i.tp_distance = InpInfinity_TP_Distance;
    return i;
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
    return r;
}

SOpenInputs MakeOpenInputs() {
    SOpenInputs o;
    o.sl_dev_pts = SLDev;
    o.close_orders = CloseOrders;
    o.reverse = Reverse;
    o.open_side = (int)InpOpen_Side;
    o.open_new_pos = OpenNewPos;
    o.multiple_open_pos = MultipleOpenPos;
    o.margin_limit = MarginLimit;
    o.spread_limit = SpreadLimit;
    o.slippage = Slippage;
    o.timer_interval = TimerInterval;
    o.magic_number = MagicNumber;
    o.filling = Filling;
    return o;
}

void ConfigureEAFromInputs(const SRiskInputs &rin, const SOpenInputs &oin, const SIndicatorInputs &iin, const SMarginGuardInputs &min, const SSmartGridInputs &sin, const SInfinityInputs &inf) {
    ea.Init();
    ea.SetMagic(oin.magic_number);
    ea.risk = ((rin.risk_mode==RISK_FIXED_VOL || rin.risk_mode==RISK_MIN_AMOUNT) ? rin.risk : rin.risk*0.01);
    ea.reverse = oin.reverse;
    ea.trailingStopLevel = rin.trailing_stop_level * 0.01;
    ea.grid = iin.grid;
    ea.gridVolMult = iin.grid_vol_mult;
    ea.gridTrailingStopLevel = iin.grid_trail_level * 0.01;
    ea.gridMaxLvl = iin.grid_max_lvl;
    
    // Configuration Grid Avancé
    ea.gridDynamic = iin.grid_dynamic;
    ea.gridAtrPeriod = iin.grid_atr_period;
    ea.gridAtrMult = iin.grid_atr_mult;
    ea.gridMinProfit = iin.grid_min_profit;
    ea.gridProfitMode = (ENUM_GRID_PROFIT_MODE)iin.grid_profit_mode;
    ea.gridMaxATR = iin.grid_max_atr;

    // Configuration Margin Guard
    ea.mgEnable = min.enable;
    ea.mgStretchLvl = min.stretch_level;
    ea.mgMaxMult = min.stretch_max_mult;
    ea.mgDelevLvl = min.delev_level;
    ea.mgDelevWorst = min.delev_worst;
    
    ea.mgDampingEnable = min.damping_enable;
    ea.mgDampingStart = min.damping_start;
    ea.mgDampingMin = min.damping_min_mult;
    ea.mgDampingLowBound = min.damping_low_bound;
    
    // Configuration Smart Grid Reduction
    ea.sgReductionEnable = sin.reduction_enable;
    ea.sgReductionStartLvl = sin.reduction_start_lvl;
    ea.sgReductionProfitRatio = sin.reduction_profit_ratio * 0.01;
    ea.sgReductionMinVol = sin.reduction_min_vol;
    ea.sgReductionWinnerClosePercent = sin.reduction_winner_close_percent * 0.01; // Convert percent to ratio
    
    // Configuration Infinity
    ea.infEnable = inf.enable;
    ea.infTriggerPct = inf.trigger_pct;
    ea.infStepMode = inf.step_mode;
    ea.infAtrPeriod = inf.atr_period;
    ea.infAtrMult = inf.atr_mult;
    
    // Si mode pourcentage, conversion. Si mode points, valeur brute.
    if(ea.infStepMode == INF_STEP_PERCENT)
        ea.infTrailingStep = inf.trailing_step * 0.01;
    else
        ea.infTrailingStep = inf.trailing_step;

    ea.infTpDistance = inf.tp_distance;
    
    ea.maxSpreadLimit = oin.spread_limit;
    
    ea.beMinOffsetPts = InpBE_Min_Offset_Pts;

    ea.equityDrawdownLimit = rin.equity_dd_limit * 0.01;
    ea.slippage = oin.slippage;
    ea.filling = oin.filling;
    ea.riskMode = rin.risk_mode;
    ea.trailMode = rin.trail_mode;
    ea.trailAtrPeriod = rin.trail_atr_period;
    ea.trailAtrMult = rin.trail_atr_mult;
    ea.riskMaxTotalLots = rin.max_total_lots;
    
    // Initialize optimized ATR handle if needed
    ea.InitATR();
}

double ComputeStop(const bool isBuy, const double entry) {
    const double ce = (isBuy ? CE_B[1] : CE_S[1]);
    if (ce == 0.0 || entry <= 0.0) return 0.0;
    const double dir = (isBuy ? -1.0 : 1.0);
    double candidate = ce + dir * SLDev * _Point;
    const int minPts = MinBrokerPoints(_Symbol);
    const double minDist = MathMax((double)minPts, 1.0) * _Point;
    const double dist = MathAbs(entry - candidate);
    double stop = candidate;
    if (dist < minDist) stop = entry + (isBuy ? -minDist : minDist);
    if (isBuy && stop >= entry) stop = entry - minDist;
    if (!isBuy && stop <= entry) stop = entry + minDist;
    return stop;
}

bool BuildSignalPrices(const bool isBuy, double &entry, double &stop) {
    entry = (isBuy ? Ask() : Bid());
    if (entry <= 0) return false;
    const double ce = (isBuy ? CE_B[1] : CE_S[1]);
    if (ce == 0.0) return false;
    stop = ComputeStop(isBuy, entry);
    if (stop <= 0.0) return false;
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySetup() {
    return (CE_B[1] != 0 && HA_C[1] > ZL[1]);
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

    double entry=0.0, stop=0.0;
    if (!BuildSignalPrices(true, entry, stop)) return false;
    
    // --- DYNAMIC RISK HOOK ---
    double multiplier = g_confidence.GetConfidenceMultiplier(_Symbol, PERIOD_CURRENT, ZL);
    double originalRisk = ea.risk;
    ea.risk *= multiplier; // Apply Mod
    
    bool res = ea.BuyOpen(entry, stop, 0.0, IgnoreSL, true);
    
    ea.risk = originalRisk; // Restore
    // -------------------------
    
    return res;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSetup() {
    return (CE_S[1] != 0 && HA_C[1] < ZL[1]);
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

    double entry=0.0, stop=0.0;
    if (!BuildSignalPrices(false, entry, stop)) return false;

    // --- DYNAMIC RISK HOOK ---
    double multiplier = g_confidence.GetConfidenceMultiplier(_Symbol, PERIOD_CURRENT, ZL);
    double originalRisk = ea.risk;
    ea.risk *= multiplier; // Apply Mod
    
    bool res = ea.SellOpen(entry, stop, 0.0, IgnoreSL, true);
    
    ea.risk = originalRisk; // Restore
    // -------------------------

    return res;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckClose() {
    if (!CloseOrders) return;
    int n = InpClose_ConfirmBars;
    if (n < 1) n = 1;
    if (n >= BuffSize) n = BuffSize - 1; // borné par la taille des buffers

    bool belowAll = true; // HA<ZL sur n barres
    bool aboveAll = true; // HA>ZL sur n barres
    for (int s = 1; s <= n; ++s) {
        if (!(HA_C[s] < ZL[s])) belowAll = false;
        if (!(HA_C[s] > ZL[s])) aboveAll = false;
    }
    const bool buyExitConf  = belowAll; // conf. baissière
    const bool sellExitConf = aboveAll; // conf. haussière

    if (buyExitConf && InpOpen_Side != VENTES)
        ea.BuyClose();
    if (sellExitConf && InpOpen_Side != ACHATS)
        ea.SellClose();
}


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    SIndicatorInputs iin = MakeIndicatorInputs();
    SRiskInputs rin = MakeRiskInputs();
    SOpenInputs oin = MakeOpenInputs();
    SMarginGuardInputs min = MakeMarginGuardInputs();
    SSmartGridInputs sin = MakeSmartGridInputs();
    SInfinityInputs inf = MakeInfinityInputs();
    ConfigureEAFromInputs(rin, oin, iin, min, sin, inf);

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

    CAuroraLogger::Configure(
        InpLog_General,
        InpLog_Position,
        InpLog_Risk,
        InpLog_Session,
        InpLog_News,
        false, // InpLog_FTMO removed
        InpLog_Strategy,
        InpLog_Orders,
        InpLog_Diagnostic
    );
    CAuroraLogger::SetPrefix(_Symbol);
    
    // Configurer le Session Manager
    SSessionInputs sess = MakeSessionInputs();
    g_session.Configure(sess);

    // Weekend guard (Generic)
    SWeekendInputs w = MakeWeekendInputs();
    g_weekend.Configure(w);

    SNewsInputs newsParams = MakeNewsInputs();
    newsFilter.Configure(newsParams);

    // Init Confidence Engine
    SDynamicRiskInputs dynRisk = MakeDynamicRiskInputs();
    g_confidence.Configure(dynRisk);
    g_confidence.InitIndicators(_Symbol, PERIOD_CURRENT);

    // Init Pyramiding
    STrendScaleInputs trendParams = MakeTrendScaleInputs();
    g_pyramiding.Configure(trendParams);

    HA_handle = iCustom(NULL, 0, I_HA);
    CE_handle = iCustom(NULL, 0, I_CE, CeAtrPeriod, CeAtrMult);
    ZL_handle = iCustom(NULL, 0, I_ZL, ZlPeriod, true);

    if (HA_handle == INVALID_HANDLE || CE_handle == INVALID_HANDLE || ZL_handle == INVALID_HANDLE) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::ErrorGeneral(StringFormat("Runtime error = %d", GetLastError()));
        return(INIT_FAILED);
    }

    // Timer: Use Main TimerInterval directly
    int timerSec = TimerInterval;
    if(timerSec < AURORA_TIMER_MIN_SEC) timerSec = AURORA_TIMER_MIN_SEC;
    EventSetTimer(timerSec);
    // Info stratégie: côté d'ouverture
    if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
        string sideTxt = (InpOpen_Side==ACHATS?"ACHATS":(InpOpen_Side==VENTES?"VENTES":"ACHATS+VENTES"));
        CAuroraLogger::InfoStrategy(StringFormat("Type de positions autorisées: %s", sideTxt));
    }
    
    // Caching TickValue
    InitTickValue(_Symbol);
    
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

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
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
    g_dashboard.Destroy();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime oldTc = tc;
    tc = TimeTradeServer();
    if (tc == oldTc) return;
    
    if (!AuroraGuards::ProcessTimer(
            g_session,
            g_weekend,
            newsFilter,
            ea,
            _Symbol,
            tc,
            InpNews_Action,
            Slippage)) {
        return;
    }

    UpdateDashboardState();
    
    // Grid logic moved to OnTick
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
        if(HistorySelect(0, TimeTradeServer() + 86400)) {
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
    // Check global stop logic (Weekend, News...)
    if (g_weekend.BlockEntriesNow(TimeTradeServer(), _Symbol)) return;
    // Real-time Equity Check (Critical Security)
    if (EquityDrawdownLimit) ea.CheckForEquity();

    // Real-time Margin Deleverage (Critical Security)
    if (MarginGuard_Enable && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < (ea.mgDelevLvl + 50.0)) {
         ea.CheckMarginDeleverage();
    }
    
    // Break‑Even (avant trailing)
    if (InpBE_Enable) {
        ea.CheckForBE(InpBE_Mode, InpBE_Trigger_Ratio, InpBE_Trigger_Pts, InpBE_Offset_SpreadMult, SLDev, InpBE_OnNewBar);
    }

    // Trailing statique (niveau issu des inputs)
    if (TrailingStop) {
        ea.CheckForTrail();
    }

    // Real-time Guards (News & Weekend)
    // Run on EVERY tick to ensure immediate response
    datetime now = TimeTradeServer();
    bool allowEntry = true;
    if (!AuroraGuards::ProcessTick(
            g_session,
            g_weekend,
            newsFilter,
            ea,
            _Symbol,
            now,
            InpNews_Action,
            allowEntry)) {
        return; // Trading interdit ou fermeture d'urgence
    }

    // --- Grid Logic (Moved from OnTimer) ---
    if (Grid) {
        int sideFilter = -1;
        if (InpOpen_Side == ACHATS) sideFilter = 0;
        else if (InpOpen_Side == VENTES) sideFilter = 1;
        if (!g_suspend_grid)
            ea.CheckForGridSide(sideFilter);
        else if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
            CAuroraLogger::InfoStrategy("[GRID] Ajout suspendu (inversion non confirmée)");
    }

    // Smart Grid Reduction (Scrubbing)
    if (SmartGrid_Reduction_Enable) {
         ea.CheckSmartGridReduction();
    }

    // Trend Sniper Scaling (Pyramiding)
    if (TrendScale_Enable) {
        double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
        
        // Calculate Confidence Score here based on "Secure First" architecture
        // Note: The Pyramiding module now expects a double score, not the whole Engine
        double currentConfidence = g_confidence.GetConfidenceMultiplier(_Symbol, (ENUM_TIMEFRAMES)_Period, ZL);
        
        g_pyramiding.Process(ea.GetMagic(), _Symbol, currentConfidence, spread);
        g_pyramiding.Process(ea.GetMagic(), _Symbol, currentConfidence, spread);
    }

    // --- Dashboard Update REMOVED from OnTick ---
    // Optimisation #1: Déplacé dans OnTimer pour alléger le tick critical path
    
    // New Bar Check: Only for Indicators and Entry Signals
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);

        // Guards: buffers calculés (seulement si trade autorisé)
        if (HA_handle == INVALID_HANDLE || CE_handle == INVALID_HANDLE || ZL_handle == INVALID_HANDLE) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                CAuroraLogger::WarnDiag("Handle indicateur invalide (HA/CE/ZL)");
            return;
        }
        if (BarsCalculated(HA_handle) <= 0 || BarsCalculated(CE_handle) <= 0 || BarsCalculated(ZL_handle) <= 0) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                CAuroraLogger::WarnDiag("Buffers indicateurs non prêts (BarsCalculated<=0)");
            return;
        }

        // Standardiser les séries AVANT CopyBuffer
        // ZL is set as series in OnInit
        // ArraySetAsSeries(HA_C, true);
        // ArraySetAsSeries(CE_B, true);
        // ArraySetAsSeries(CE_S, true);

        if (CopyBuffer(HA_handle, 3, 0, BuffSize, HA_C) <= 0) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                CAuroraLogger::WarnDiag("CopyBuffer HA_C a échoué");
            return;
        }
        if (CopyBuffer(CE_handle, 0, 0, BuffSize, CE_B) <= 0) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                CAuroraLogger::WarnDiag("CopyBuffer CE_B a échoué");
            return;
        }
        if (CopyBuffer(CE_handle, 1, 0, BuffSize, CE_S) <= 0) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                CAuroraLogger::WarnDiag("CopyBuffer CE_S a échoué");
            return;
        }
        if (CopyBuffer(ZL_handle, 0, 0, BuffSize, ZL) <= 0) {
            if (CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
                CAuroraLogger::WarnDiag("CopyBuffer ZL a échoué");
            return;
        }

        if (CloseOrders) CheckClose();

        // Suspension Grid si inversion non confirmée (Option C)
        if (InpGrid_SuspendOnInverse) {
            int n = InpClose_ConfirmBars;
            if (n < 1) n = 1;
            if (n >= BuffSize) n = BuffSize - 1;
            bool belowAll = true, aboveAll = true;
            for (int s = 1; s <= n; ++s) {
                if (!(HA_C[s] < ZL[s])) belowAll = false;
                if (!(HA_C[s] > ZL[s])) aboveAll = false;
            }
            const bool belowNow = (HA_C[1] < ZL[1]);
            const bool aboveNow = (HA_C[1] > ZL[1]);
            bool hasBuys = false, hasSells = false;
            GetPositionExposure(hasBuys, hasSells);
            const bool buyPending = hasBuys && belowNow && !belowAll;
            const bool sellPending = hasSells && aboveNow && !aboveAll;
            g_suspend_grid = (buyPending || sellPending);
            if (g_suspend_grid && CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
                string scope = buyPending && sellPending ? "ACHATS+VENTES" : (buyPending ? "ACHATS" : "VENTES");
                CAuroraLogger::InfoStrategy(StringFormat("[GRID] Suspension temporaire (%s inversion non confirmée, N=%d)", scope, n));
            }
        } else {
            g_suspend_grid = false;
        }


        // --- Entry Logic (Signaux d'entrée seulement à la clôture de bougie) ---
        if (!OpenNewPos || !allowEntry) return;
        if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
        if ((Grid || !MultipleOpenPos) && ea.OPTotal() > 0) return;

        // Filtre côté — appliquer après inversion éventuelle (Reverse)
        const bool buySetupNow  = BuySetup();
        const bool sellSetupNow = SellSetup();

        // Après inversion: quel setup produit quel type d'ordre final ?
        const bool finalBuySetup  = (!Reverse ? buySetupNow  : sellSetupNow);
        const bool finalSellSetup = (!Reverse ? sellSetupNow : buySetupNow);

        if (InpOpen_Side == ACHATS) {
            if (finalSellSetup && CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                CAuroraLogger::InfoStrategy("Signal VENTE bloqué par filtre côté (ACHATS seulement)");
            // Ouvrir uniquement des BUY finaux
            if (!Reverse) { if (buySetupNow) { BuySignal(); return; } }
            else          { if (sellSetupNow){ SellSignal(); return; } }
        }
        else if (InpOpen_Side == VENTES) {
            if (finalBuySetup && CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
                CAuroraLogger::InfoStrategy("Signal ACHAT bloqué par filtre côté (VENTES seulement)");
            // Ouvrir uniquement des SELL finaux
            if (!Reverse) { if (sellSetupNow){ SellSignal(); return; } }
            else          { if (buySetupNow) { BuySignal(); return; } }
        }
        else { // ACHATS+VENTES
            // Prioriser BUY final, puis SELL final
            if (!Reverse) {
                if (BuySignal()) return;
                SellSignal();
            } else {
                if (SellSignal()) return;
                BuySignal();
            }
        }
    }
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
        if (result.retcode != TRADE_RETCODE_DONE) {
             if (CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) {
                string action = EnumToString(request.action);
                CAuroraLogger::ErrorOrders(StringFormat("[ASYNC] Request Failed: %s, Retcode=%u, Comment=%s", 
                    action, result.retcode, result.comment));
             }
        }
    } else if (trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        // Flag history as dirty to trigger update on next timer
        g_history_dirty = true;
        
        if (trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL) {
             if (CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS)) {
                CAuroraLogger::InfoOrders(StringFormat("[ASYNC] Deal Executed: Ticket=%I64u, Vol=%.2f, Price=%.5f", 
                    trans.deal, trans.volume, trans.price));
             }
        }
    }
}

double OnTester()
{
    return 0.0;
}

//+------------------------------------------------------------------+