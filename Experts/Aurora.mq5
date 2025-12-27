//+------------------------------------------------------------------+
//|                                                       Aurora.mq5 |
//|                                           Copyright 2025, Aurora |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Aurora"
#property link      " https://github.com/tommysuzanne"
#property version     "1.73"
#property description "A Strategy Using Chandelier Exit and ZLSMA Indicators Based on the Heikin Ashi Candles"
#property description "US30-15M"

#include <EAUtils.mqh>
#include "..\\Include\\aurora_constants.mqh"
#include "..\\Include\\aurora_ftmo_clock.mqh"
#include "..\\Include\\aurora_ftmo_guard.mqh"
#include "..\\Include\\aurora_ftmo_news_strict.mqh"
#include "..\\Include\\aurora_session_manager.mqh"
#include "..\\Include\\aurora_weekend_guard.mqh"
#include "..\\Include\\aurora_newsfilter.mqh"
#include "..\\Include\\aurora_guard_pipeline.mqh"
#include "..\\Include\\aurora_diagnostics.mqh"
#include "..\\Include\\aurora_inputs_structs.mqh"

input group "Indicateurs & Grid"
input int CeAtrPeriod = 1; // Période ATR du Chandelier (barres)
input double CeAtrMult = 0.75; // Multiplicateur ATR du Chandelier (×)
input int ZlPeriod = 50; // Période ZLSMA (barres)

// Paramètres de grille
input bool Grid = true; // Activer la grille
input double GridVolMult = 1.5; // Multiplicateur de volume de la grille
input double GridTrailingStopLevel = 0; // Niveau de trailing de la grille (%) (0 = désactivé)
input int GridMaxLvl = 50; // Niveaux max de grille

// Paramètres Grid Avancés (Dynamique & Profit)
input bool   GridDynamic      = false; // Grille Dynamique (ATR) [ON/OFF]
input int    GridAtrPeriod    = 14;    // Période ATR Grille (si dyn.)
input double GridAtrMult      = 1.0;   // Multiplicateur ATR Grille (si dyn.)
input double GridMinProfit    = 0.0;   // Profit Min Grille (0 = Break-Even seul)
input bool   GridMinProfitPct = false; // Profit en % du solde [ON/OFF]

// (Groupe "Générale" fusionné dans "Ouverture & Système")

input group "Risk Management"
input double Risk = 3; // Risque par trade (%/lot selon le mode)
input ENUM_RISK RiskMode = RISK_DEFAULT; // Mode de risque (Défaut=% dispo, Volume fixe (lots), % equity/solde/marge libre/crédit)
input bool IgnoreSL = true; // Ignorer le SL (ne pas placer au broker)
input bool Trail = true; // Activer le stop suiveur
input double TrailingStopLevel = 50; // Niveau de trailing (%) (0 = désactivé)
input double EquityDrawdownLimit = 0; // Limite de drawdown sur l’équity (%) (0 = désactivé)

// Break‑Even (déplaçe le SL au prix d'entrée après un gain en R)
input bool   InpBE_Enable             = false; // Break‑Even — Activer [ON/OFF]
input double InpBE_TriggerR           = 1.0;   // Break‑Even — Déclencheur (+R) [0.5–3.0]
input double InpBE_Offset_SpreadMult  = 1.5;   // Break‑Even — Offset (spread×k) [0–5]
input bool   InpBE_OnNewBar           = true;  // Break‑Even — Appliquer à la nouvelle bougie uniquement


input group "Ouverture & Système"
// Paramètres généraux (au début de la catégorie)
input int SLDev = 650; // Déviation du SL (points)
input bool CloseOrders = false; // Clôturer sur signal inverse (HA/ZLSMA)
// Sécurité Grid vs Clôture inverse
input int  InpClose_ConfirmBars     = 2;   // Clôture inverse — Barres de confirmation [1–4]
input bool InpGrid_SuspendOnInverse = true; // Suspendre l'ajout de niveaux Grid si inversion non confirmée [ON/OFF]
input bool Reverse = false; // Inverser la direction des signaux (Buy↔Sell)
// Type de positions autorisées (Achat/Vente/Les deux)
// Valeurs en français pour l'UI MT5 (noms simples affichés dans l'input)
enum AURORA_OPEN_SIDE { ACHATS=0, VENTES=1, ACHATS_VENTES=2 };
input AURORA_OPEN_SIDE InpOpen_Side = ACHATS_VENTES; // Type de positions (Achat / Vente / Les deux)
input bool OpenNewPos = true; // Autoriser l’ouverture de nouvelles positions
input bool MultipleOpenPos = false; // Autoriser plusieurs positions simultanées
input double MarginLimit = 300; // Limite de marge (%) (0 = désactivé)
input int SpreadLimit = -1; // Limite de spread (points) (-1 = désactivé)
// Paramètres système (ex-Auxiliary)
input int Slippage = 30; // Slippage (points)
input int TimerInterval = 30; // Intervalle du timer (secondes)
input ulong MagicNumber = 2000; // Numéro magique
input ENUM_FILLING Filling = FILLING_DEFAULT; // Type de remplissage des ordres (Auto/FOK/IOC/RETURN)

// (Paramètres FTMO déplacés dans la catégorie dédiée en bas)

// Groupes de gestion calendrier/horaires juste au‑dessus des logs
// Session Management au‑dessus du News Management
input group "Session Management"
input bool   InpSess_TradeMon = true;   // Trader le lundi [ON/OFF]
input bool   InpSess_TradeTue = true;   // Trader le mardi [ON/OFF]
input bool   InpSess_TradeWed = true;   // Trader le mercredi [ON/OFF]
input bool   InpSess_TradeThu = true;   // Trader le jeudi [ON/OFF]
input bool   InpSess_TradeFri = true;   // Trader le vendredi [ON/OFF]
input bool   InpSess_TradeSat = false;  // Trader le samedi [ON/OFF]
input bool   InpSess_TradeSun = false;  // Trader le dimanche [ON/OFF]
input bool   InpSess_EnableTime = false; // Activer la session horaire [ON/OFF]
input int    InpSess_StartHour = 0;     // Heure de début [0–23]
input int    InpSess_StartMin  = 0;     // Minutes de début [0–59]
input int    InpSess_EndHour   = 23;    // Heure de fin [0–23]
input int    InpSess_EndMin    = 59;    // Minutes de fin [0–59]
input bool   InpSess_CloseOutside   = false; // Fermer positions hors session
input bool   InpSess_CloseRestricted = false; // Fermer positions jours non autorisés
input bool   InpSess_RespectBrokerSessions = true; // Respecter les sessions broker [ON/OFF]
input int    InpSess_TimerSec = 15;     // Fréquence contrôle session (secondes) [5–60]

// (Paramètres FTMO déplacés dans la catégorie dédiée en bas)

input group "News Management"
input bool   InpNews_Enable = false; // Activer le filtre News
input ENUM_NEWS_LEVELS InpNews_Levels = NEWS_LEVELS_HIGH_MEDIUM; // Niveaux bloqués (Aucune/Fortes/Fortes+Moyennes/Toutes)
input string InpNews_Ccy = ""; // Devises surveillées (vide = auto)
input int    InpNews_BlackoutB = 30; // Fenêtre avant news (minutes) [0–240]
input int    InpNews_BlackoutA = 15; // Fenêtre après news (minutes) [0–240]
input int    InpNews_MinCoreHighMin = 2; // Noyau minimal news fortes (minutes ≥0)
input ENUM_NEWS_ACTION InpNews_Action = NEWS_ACTION_BLOCK_ALL_CLOSE; // Action pendant la fenêtre (Bloquer entrées/gestion/Tout et fermer)
input int    InpNews_RefreshMin = 15; // Rafraîchissement calendrier (minutes ≥1)

// (Paramètres FTMO déplacés dans la catégorie dédiée en bas)

// Place la catégorie Logs en toute fin
// Catégorie FTMO — juste au‑dessus des logs
input group "FTMO"
// Mode & reset (Prague)
input ENUM_FTMO_MODE InpFTMO_Mode = FTMO_OFF; // Mode FTMO (OFF/Challenge/Verification/Account/Swing)
input bool   InpFTMO_ResetPragueAuto = true;  // Reset MDL à minuit Prague (auto) [ON/OFF]
input int    InpFTMO_ResetHour = 0;          // Fallback heure serveur [0–23]
input int    InpFTMO_ResetMin  = 0;          // Fallback minute [0–59]

// Maximum Daily Loss & Maximum Loss (Total)
input double InpFTMO_DailyMaxPercent = 4.0;     // Perte journalière max (%) [1–10]
input bool   InpFTMO_DailyIncludeFloating = true; // Inclure le flottant dans MDL [ON/OFF]
input int    InpFTMO_DailyWarnPct = 80;         // Alerte MDL (%) [50–95]
input ENUM_FTMO_HARD InpFTMO_DailyHardAction = FTMO_BLOCK_ENTRIES; // Action dure MDL (Bloquer/Clore tout)
input double InpFTMO_TotalMaxPercent = 9.0;     // Perte totale max (%) [2–20]
input int    InpFTMO_TotalWarnPct = 80;         // Alerte perte totale (%) [50–95]
input ENUM_FTMO_HARD InpFTMO_TotalHardAction = FTMO_BLOCK_ENTRIES; // Action dure Max Loss

// Pré‑Trade & caps opérationnels
input bool   InpFTMO_PreTradeCheckEnable = false; // Vérifier le respect FTMO avant chaque ordre
input int    InpFTMO_PreTradeBufferPct   = 5;    // Marge de sécurité (%) sous les seuils
input double InpFTMO_MaxLotsPerOrder     = 5.0;  // Cap lots par ordre
input double InpFTMO_MaxNetLotsPerSymbol = 10.0; // Cap net de lots par symbole
input int    InpFTMO_MaxOpenPositions    = 10;   // Nombre max de positions ouvertes

// Weekend guard (gap≥2h)
input bool   InpFTMO_WeekendClose    = false; // Fermer positions avant le week‑end [ON/OFF]
input int    InpFTMO_WeekendBufferMin= 30;    // Marge avant fermeture (minutes) [5–120]
input int    InpFTMO_WeekendGapMinHours = 2;  // Gap min. week‑end (heures) [2–6]
input int    InpFTMO_WeekendBlockNewBeforeMin = 30; // Bloquer nouvelles entrées avant close (minutes)
input bool   InpFTMO_WeekendClosePendings = true;   // Fermer ordres en attente avant close

// News strict 2/2 ciblé
input bool   InpFTMO_NewsStrict_Enable       = false; // Activer l’overlay strict 2/2
input int    InpFTMO_NewsStrict_BeforeSec    = 120;   // Fenêtre stricte avant (secondes)
input int    InpFTMO_NewsStrict_AfterSec     = 120;   // Fenêtre stricte après (secondes)
input bool   InpFTMO_NewsStrict_TargetedOnly = true;  // Ciblé devise du symbole uniquement
input bool   InpFTMO_NewsStrict_HoldAllowed  = true;  // Conserver positions anciennes (>2min) dans la fenêtre
input bool   InpFTMO_NewsStrict_CloseBefore  = false; // Fermer avant l’événement
input int    InpFTMO_NewsStrict_CloseBufferSec = 15;  // Buffer de fermeture avant (secondes)
input bool   InpFTMO_NewsStrict_SuspendManage  = true; // Suspendre la gestion (SL/TP/Trailing) pendant la fenêtre

// Place la catégorie Logs en toute fin
input group "Logs"
input bool   InpLog_General   = true;  // Journaux généraux (init, erreurs) [ON/OFF]
input bool   InpLog_Position  = false; // Positions (ouvertures/fermetures auto) [ON/OFF]
input bool   InpLog_Risk      = false; // Gestion du risque (equity/DD/volumes) [ON/OFF]
input bool   InpLog_Session   = false; // Sessions (hors news) [ON/OFF]
input bool   InpLog_News      = false; // News & calendrier économique [ON/OFF]
input bool   InpLog_Strategy  = false; // Stratégie/Signaux [ON/OFF]
input bool   InpLog_Orders    = false; // Trading/ordres (retcodes) [ON/OFF]
input bool   InpLog_Diagnostic= false; // Diagnostic technique (buffers, indicateurs) [ON/OFF]
input bool   InpLog_FTMO      = false; // Journaux FTMO (horloge, MDL/Total, Pré‑trade) [ON/OFF]

const int BuffSize = AURORA_BUFF_SIZE;

GerEA ea;
datetime lastCandle;
datetime tc;
CAuroraSessionManager g_session;
CAuroraWeekendGuard   g_weekend;
CAuroraNewsFilter newsFilter;
CAuroraFtmoClock      g_ftmo_clock;
CAuroraFtmoGuard      g_ftmo_guard;
CAuroraFtmoNewsStrict g_ftmo_news;
int                   g_ctr_weekend_preclose = 0;
int                   g_ctr_news_suspend = 0;
bool                  g_suspend_grid = false;

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
    sess.close_outside        = InpSess_CloseOutside;
    sess.close_restricted_days= InpSess_CloseRestricted;
    sess.respect_broker_sessions = InpSess_RespectBrokerSessions;
    sess.timer_sec = InpSess_TimerSec;
    return sess;
}

SWeekendInputs MakeWeekendInputs() {
    SWeekendInputs w;
    w.enable = InpFTMO_WeekendClose;
    w.buffer_min = InpFTMO_WeekendBufferMin;
    w.gap_min_hours = InpFTMO_WeekendGapMinHours;
    w.block_before_min = InpFTMO_WeekendBlockNewBeforeMin;
    w.close_pendings = InpFTMO_WeekendClosePendings;
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

SFtmoInputs MakeFtmoInputs() {
    SFtmoInputs in;
    in.mode = InpFTMO_Mode;
    in.daily_max_pct = InpFTMO_DailyMaxPercent;
    in.daily_include_floating = InpFTMO_DailyIncludeFloating;
    in.daily_warn_pct = InpFTMO_DailyWarnPct;
    in.daily_hard = InpFTMO_DailyHardAction;
    in.total_max_pct = InpFTMO_TotalMaxPercent;
    in.total_warn_pct = InpFTMO_TotalWarnPct;
    in.total_hard = InpFTMO_TotalHardAction;
    in.cap_lots_order = InpFTMO_MaxLotsPerOrder;
    in.cap_net_lots_symbol = InpFTMO_MaxNetLotsPerSymbol;
    in.cap_max_open_positions = InpFTMO_MaxOpenPositions;
    in.pretrade_enable = InpFTMO_PreTradeCheckEnable;
    in.pretrade_buffer_pct = InpFTMO_PreTradeBufferPct;
    return in;
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
    s.grid_min_profit_pct = GridMinProfitPct;
    return s;
}

SRiskInputs MakeRiskInputs() {
    SRiskInputs r;
    r.risk = Risk;
    r.risk_mode = RiskMode;
    r.ignore_sl = IgnoreSL;
    r.trail = Trail;
    r.trailing_stop_level = TrailingStopLevel;
    r.equity_dd_limit = EquityDrawdownLimit;
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

void ConfigureEAFromInputs(const SRiskInputs &rin, const SOpenInputs &oin, const SIndicatorInputs &iin) {
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
    ea.gridMinProfitPct = iin.grid_min_profit_pct;

    ea.equityDrawdownLimit = rin.equity_dd_limit * 0.01;
    ea.slippage = oin.slippage;
    ea.filling = oin.filling;
    ea.riskMode = rin.risk_mode;
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

bool AllowFtmoPreview(const bool isBuy, const double entry, const double stop) {
    if (!g_ftmo_guard.PreTradeEnabled()) return true;
    double sl_points = MathAbs(entry - stop) / _Point;
    if (sl_points <= 0)
        sl_points = (double)MathMax(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL), 1);
    double previewLot = calcVolumeFromPoints(sl_points, ea.risk, ea.riskMode, _Symbol);
    if (previewLot <= 0)
        previewLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if (!g_ftmo_guard.PreTradeOK(_Symbol, previewLot, sl_points)) {
        if (CAuroraLogger::IsEnabled(AURORA_LOG_FTMO))
            CAuroraLogger::WarnFtmo(StringFormat("[PRETRADE] %s bloqué (preview)", isBuy ? "Achat" : "Vente"));
        return false;
    }
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
    double entry=0.0, stop=0.0;
    if (!BuildSignalPrices(true, entry, stop)) return false;
    if (!AllowFtmoPreview(true, entry, stop)) return false;
    ea.BuyOpen(entry, stop, 0.0, IgnoreSL, true);
    return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSetup() {
    return (CE_S[1] != 0 && HA_C[1] < ZL[1]);
}

bool SellSignal() {
    if (!SellSetup()) return false;
    double entry=0.0, stop=0.0;
    if (!BuildSignalPrices(false, entry, stop)) return false;
    if (!AllowFtmoPreview(false, entry, stop)) return false;
    ea.SellOpen(entry, stop, 0.0, IgnoreSL, true);
    return true;
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
    ConfigureEAFromInputs(rin, oin, iin);

    CAuroraLogger::Configure(
        InpLog_General,
        InpLog_Position,
        InpLog_Risk,
        InpLog_Session,
        InpLog_News,
        InpLog_FTMO,
        InpLog_Strategy,
        InpLog_Orders,
        InpLog_Diagnostic
    );
    CAuroraLogger::SetPrefix(_Symbol);
    
    // Configurer le Session Manager
    SSessionInputs sess = MakeSessionInputs();
    g_session.Configure(sess);

    // Weekend guard (FTMO)
    SWeekendInputs w = MakeWeekendInputs();
    g_weekend.Configure(w);

    SNewsInputs newsParams = MakeNewsInputs();
    newsFilter.Configure(newsParams);

    // FTMO — Clock & Guard & News Strict
    g_ftmo_clock.Configure(InpFTMO_ResetPragueAuto, InpFTMO_ResetHour, InpFTMO_ResetMin);
    g_ftmo_clock.InitAnchorsOnInit();
    g_ftmo_guard.EnsureInitialBalance();
    g_ftmo_guard.OnNewDay(AccountInfoDouble(ACCOUNT_BALANCE));
    SFtmoInputs ftmoin = MakeFtmoInputs();
    g_ftmo_guard.Configure(ftmoin);

    SFtmoNewsStrictInputs ns;
    ns.enable = InpFTMO_NewsStrict_Enable;
    ns.before_sec = InpFTMO_NewsStrict_BeforeSec;
    ns.after_sec  = InpFTMO_NewsStrict_AfterSec;
    ns.targeted_only = InpFTMO_NewsStrict_TargetedOnly;
    ns.hold_allowed  = InpFTMO_NewsStrict_HoldAllowed;
    ns.close_before  = InpFTMO_NewsStrict_CloseBefore;
    ns.close_buffer_sec = InpFTMO_NewsStrict_CloseBufferSec;
    ns.suspend_manage  = InpFTMO_NewsStrict_SuspendManage;
    // Niveaux hérités du bloc News
    ns.level_high   = (InpNews_Levels==NEWS_LEVELS_HIGH_ONLY || InpNews_Levels==NEWS_LEVELS_HIGH_MEDIUM || InpNews_Levels==NEWS_LEVELS_ALL);
    ns.level_medium = (InpNews_Levels==NEWS_LEVELS_HIGH_MEDIUM || InpNews_Levels==NEWS_LEVELS_ALL);
    ns.level_low    = (InpNews_Levels==NEWS_LEVELS_ALL);
    g_ftmo_news.Configure(ns);

    HA_handle = iCustom(NULL, 0, I_HA);
    CE_handle = iCustom(NULL, 0, I_CE, CeAtrPeriod, CeAtrMult);
    ZL_handle = iCustom(NULL, 0, I_ZL, ZlPeriod, true);

    if (HA_handle == INVALID_HANDLE || CE_handle == INVALID_HANDLE || ZL_handle == INVALID_HANDLE) {
        if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::ErrorGeneral(StringFormat("Runtime error = %d", GetLastError()));
        return(INIT_FAILED);
    }

    // Timer: maximum entre TimerInterval (EA) et InpSess_TimerSec (sessions)
    int timerSec = (int)MathMax((double)TimerInterval, (double)InpSess_TimerSec);
    if(timerSec < AURORA_TIMER_MIN_SEC) timerSec = AURORA_TIMER_MIN_SEC;
    EventSetTimer(timerSec);
    // Info stratégie: côté d'ouverture
    if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY)) {
        string sideTxt = (InpOpen_Side==ACHATS?"ACHATS":(InpOpen_Side==VENTES?"VENTES":"ACHATS+VENTES"));
        CAuroraLogger::InfoStrategy(StringFormat("Type de positions autorisées: %s", sideTxt));
    }
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    EventKillTimer();
    newsFilter.FlushDiagnostics();
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
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer() {
    datetime oldTc = tc;
    tc = TimeTradeServer();
    if (tc == oldTc) return;
    // Reset blocage entrées FTMO (interne guard) à chaque évaluation timer
    g_ftmo_guard.ResetEntriesBlock();
    // Reset minuit Prague: si changement de jour, réinitialiser l'ancre journalière
    datetime anchor_ts=0;
    if (g_ftmo_clock.PragueMidnightChanged(tc, anchor_ts)) {
        g_ftmo_guard.OnNewDay(AccountInfoDouble(ACCOUNT_BALANCE));
    }
    if (!AuroraGuards::ProcessTimer(
            g_session,
            g_weekend,
            newsFilter,
            g_ftmo_news,
            g_ftmo_guard,
            ea,
            _Symbol,
            tc,
            InpNews_Action,
            InpFTMO_NewsStrict_HoldAllowed,
            InpFTMO_NewsStrict_CloseBefore,
            Slippage,
            g_ctr_weekend_preclose,
            g_ctr_news_suspend)) {
        return;
    }

    // Break‑Even (avant trailing)
    if (InpBE_Enable) {
        ea.CheckForBE(InpBE_TriggerR, InpBE_Offset_SpreadMult, SLDev, InpBE_OnNewBar);
    }

    // Trailing statique (niveau issu des inputs)
    if (Trail) {
        ea.trailingStopLevel = TrailingStopLevel * 0.01;
        ea.CheckForTrail();
    }
    if (EquityDrawdownLimit) ea.CheckForEquity();
    if (Grid) {
        int sideFilter = -1;
        if (InpOpen_Side == ACHATS) sideFilter = 0;
        else if (InpOpen_Side == VENTES) sideFilter = 1;
        if (!g_suspend_grid)
            ea.CheckForGridSide(sideFilter);
        else if (CAuroraLogger::IsEnabled(AURORA_LOG_STRATEGY))
            CAuroraLogger::InfoStrategy("[GRID] Ajout suspendu (inversion non confirmée)");
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if (lastCandle != Time(0)) {
        lastCandle = Time(0);

        // Guards: handles valides et buffers calculés
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
        ArraySetAsSeries(HA_C, true);
        ArraySetAsSeries(CE_B, true);
        ArraySetAsSeries(CE_S, true);
        ArraySetAsSeries(ZL, true);

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

        datetime now = TimeTradeServer();
        if (!AuroraGuards::ProcessTick(
                g_session,
                g_weekend,
                newsFilter,
                g_ftmo_news,
                g_ftmo_guard,
                ea,
                _Symbol,
                now,
                InpNews_Action)) {
            return;
        }

        if (!OpenNewPos) return;
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
//| Tester export FTMO diagnostics                                   |
//+------------------------------------------------------------------+
double OnTester()
{
    // Exporte un CSV par symbole dans Common Files
    int day_resets=0, mdl_hits=0, total_hits=0, pretrade_vetos=0;
    g_ftmo_guard.GetCounters(day_resets, mdl_hits, total_hits, pretrade_vetos);
    string fname = StringFormat("AURORA_FTMO_%s_%s.csv", _Symbol, TimeToString(TimeCurrent(), TIME_DATE));
    bool newfile = !FileIsExist(fname, FILE_COMMON);
    int h = FileOpen(fname, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON|FILE_ANSI, ';');
    if(h!=INVALID_HANDLE){
        if(newfile){
            FileWrite(h, "mode","day_anchor_ts","day_anchor_balance","mdl_hits","total_hits","pretrade_vetos","news_suspend","wk_preclose");
        }
        FileSeek(h, 0, SEEK_END);
        FileWrite(h,
            (int)InpFTMO_Mode,
            (long)g_ftmo_clock.LastAnchorTs(),
            g_ftmo_guard.DayAnchorBalance(),
            mdl_hits,
            total_hits,
            pretrade_vetos,
            g_ctr_news_suspend,
            g_ctr_weekend_preclose
        );
        FileClose(h);
    }
    // Dump JSON diagnostics (structure compacte)
    DumpOnTesterJSON(
        _Symbol,
        (int)InpFTMO_Mode,
        g_ftmo_clock.LastAnchorTs(),
        g_ftmo_guard.DayAnchorBalance(),
        day_resets,
        mdl_hits,
        total_hits,
        pretrade_vetos,
        g_ctr_news_suspend,
        g_ctr_weekend_preclose
    );
    return 0.0;
}

//+------------------------------------------------------------------+