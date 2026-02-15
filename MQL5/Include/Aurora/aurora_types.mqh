//+------------------------------------------------------------------+
//|                                                 Aurora Types     |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_TYPES_MQH__
#define __AURORA_TYPES_MQH__

// --- ENUMS ---
enum ENUM_ENTRY_MODE {
    ENTRY_MODE_MARKET,      // Market Execution (Standard)
    ENTRY_MODE_LIMIT,       // Limit Order (Strict Sniper IOC)
    ENTRY_MODE_STOP         // Stop Order (Breakout)
};

enum ENUM_ENTRY_STRATEGY {
    STRATEGY_REACTIVE,   // Reactive Mode
    STRATEGY_PREDICTIVE  // Predictive Mode
};

enum ENUM_STRATEGY_CORE {
    STRAT_CORE_SUPER_TREND, // Super Trend (ZLSMA+CE)
    STRAT_CORE_MOMENTUM     // Momentum (Keltner-KAMA)
};

enum ENUM_PREDICTIVE_OFFSET_MODE {
    OFFSET_MODE_POINTS,  // Distance Fixe (Points)
    OFFSET_MODE_ATR      // Dynamique (ATR)
};



enum ENUM_FILLING {
    FILLING_DEFAULT, // Auto (Default)
    FILLING_FOK,     // FOK (Fill or Kill)
    FILLING_IOK,     // IOK (Immediate or Cancel)
    FILLING_BOC,     // BOC (Book or Cancel)
    FILLING_RETURN   // Return
};

enum ENUM_RISK {
    RISK_DEFAULT,                           // Auto (Balance/MargeSafe)
    RISK_EQUITY = ACCOUNT_EQUITY,           // % Equity
    RISK_BALANCE = ACCOUNT_BALANCE,         // % Balance
    RISK_MARGIN_FREE = ACCOUNT_MARGIN_FREE, // % Marge Libre
    RISK_MARGIN_PERCENT,                    // % Marge Requise (Smart Risk)
    RISK_CREDIT = ACCOUNT_CREDIT,           // % Credit
    RISK_FIXED_VOL,                         // Volume Fixe (Lots)
    RISK_MIN_AMOUNT                         // Montant Fixe ($)
};

enum ENUM_SIGNAL_SOURCE {
    SIGNAL_SRC_HEIKEN_ASHI, // Heiken Ashi (Smoothed, Standard)
    SIGNAL_SRC_REAL_PRICE,  // Real Price (Close[1], Fast, Anti-Repainting)
    SIGNAL_SRC_ADAPTIVE     // Hybrid (HA in Calm, Real Price in Crisis)
};



enum ENUM_SESSION_CLOSE_MODE {
    SESS_MODE_OFF,          // Inactive: Block all outside session, frozen grid
    SESS_MODE_FORCE_CLOSE,  // Force Close: Close all immediately
    SESS_MODE_RECOVERY,     // Management Only: Block entries, allow grid
    SESS_MODE_SMART_EXIT,   // Sortie Intelligente: Ferme si Profit > 0
    SESS_MODE_DELEVERAGE    // Tactical Deleverage: Reduce exposure
};

enum ENUM_BE_MODE { 
    BE_MODE_RATIO,  // Ratio (R:R)
    BE_MODE_POINTS, // Distance Fixe (Points)
    BE_MODE_ATR     // Dynamique (ATR)
};



enum ENUM_TRAIL_MODE {
    TRAIL_STANDARD,     // Distance Fixe (% du SL)
    TRAIL_FIXED_POINTS, // Distance Fixe (Points)
    TRAIL_ATR           // Dynamique (ATR)
};

enum ENUM_PYRA_TRAIL_MODE {
    PYRA_TRAIL_POINTS,   // Distance Fixe (Points)
    PYRA_TRAIL_ATR       // Dynamique (ATR)
};

// Enums Stop Loss (Moved from Constants)
enum ENUM_SL_MODE {
    SL_MODE_DEV_POINTS,    // Deviation (Points)
    SL_MODE_FIXED_POINTS,  // Distance Fixe (Points)
    SL_MODE_DYNAMIC_ATR,   // Dynamique (ATR)
    SL_MODE_DEV_ATR        // Deviation (ATR)
};

enum AURORA_OPEN_SIDE {
    DIR_LONG_ONLY,      // Long (Achat uniquement)
    DIR_SHORT_ONLY,     // Short (Vente uniquement)
    DIR_BOTH_SIDES      // Bidirectionnel (Achat & Vente)
};

enum ENUM_NEWS_LEVELS
{
    NEWS_LEVELS_NONE = 0,      // None (Disabled)
    NEWS_LEVELS_HIGH_ONLY,     // Haute Importance
    NEWS_LEVELS_HIGH_MEDIUM,   // Haute & Moyenne
    NEWS_LEVELS_ALL            // Toutes les News
};

enum ENUM_NEWS_ACTION
{
    NEWS_ACTION_BLOCK_ENTRIES = 0,   // Block New Entries
    NEWS_ACTION_BLOCK_MANAGE,        // Block Entries & Management
    NEWS_ACTION_BLOCK_ALL_CLOSE,     // Tout Bloquer & Fermer Positions
    NEWS_ACTION_MONITOR_ONLY         // Afficher seulement (Ne pas bloquer)
};

// --- REGIME FILTER ENUMS ---
enum ENUM_STRESS_STATE {
    STRESS_STATE_NORMAL = 0,    // Normal
    STRESS_STATE_WARNING = 1,   // Avertissement
    STRESS_STATE_ACTIVE = 2,    // Stress Actif
    STRESS_STATE_COOLDOWN = 3   // Recovery
};

enum ENUM_FILTER_TYPE {
    FILTER_HURST,
    FILTER_VWAP,
    FILTER_KURTOSIS,
    FILTER_SPIKE,
    FILTER_TRAP
};

// --- STRUCTS (INPUTS) ---

struct SIndicatorInputs
{
  int    ce_atr_period;
  double ce_atr_mult;
  int    zl_period;

  
  // Adaptive Threshold Parameter (v3.0)
  double adaptive_vol_threshold; // Seuil bascule HA/Close
};

struct SDashboardInputs
{
  bool enable; // Activer le Dashboard
};

struct SRiskInputs
{
  double    risk;
  ENUM_RISK risk_mode;
  bool      ignore_sl;
  bool      trail;
  double    trailing_stop_level;
  ENUM_TRAIL_MODE trail_mode;
  int       trail_atr_period;
  double    trail_atr_mult;
  double    equity_dd_limit;
  double    max_total_lots;
  double    max_lot_size;
};

struct SSessionInputs
  {
   bool trade_mon;
   bool trade_tue;
   bool trade_wed;
   bool trade_thu;
   bool trade_fri;
   bool trade_sat;
   bool trade_sun;
   bool enable_time_window;
   int  start_hour;
   int  start_min;
   int  end_hour;
   int  end_min;
   // Session B
   bool enable_time_window_b;
   int  start_hour_b;
   int  start_min_b;
   int  end_hour_b;
   int  end_min_b;
   
   ENUM_SESSION_CLOSE_MODE close_mode;
   double deleverage_target_pct;
   bool close_restricted_days;
   bool respect_broker_sessions;
  };

struct SWeekendInputs
{
   bool enable;
   int  buffer_min;   // minutes avant la fermeture de session
   int  gap_min_hours; // gap minimal (heures) pour activer le garde
   int  block_before_min; // minutes before close to block entries
   bool close_pendings; // fermer les ordres en attente
};

struct SNewsInputs
{
   bool             enable;
   ENUM_NEWS_LEVELS levels;
   string           currencies;
   int              blackout_before;
   int              blackout_after;
   int              min_core_high_min;
   ENUM_NEWS_ACTION action;
   int              refresh_minutes;
   bool             log_news;
};









struct STrendScaleInputs
{
    bool   enable;              // Activer le pyramidage
    int    max_layers;          // Nombre max d'ajouts (ex: 3)
    double scaling_step_pts;    // Distance in points to trigger add (ex: 500 pts)
    double volume_mult;         // Multiplicateur de volume pour l'ajout (ex: 1.0 ou 0.5)
    double min_confidence;      // Score de confiance min requis (ex: 0.8)
    bool   trailing_sync;       // Activer la syncronisation du SL (Trailing de groupe)
    int    trail_dist_2layers;  // Distance Trailing pour 2 couches (ex: 300 pts)
    int    trail_dist_3layers;  // Distance Trailing pour 3+ couches (ex: 150 pts)
    
    // New ATR parameters (v1.6)
    ENUM_PYRA_TRAIL_MODE trail_mode; // Mode de calcul (Fixed ou ATR)
    int    atr_period;               // ATR Period
    double atr_mult_2layers;         // Multiplicateur ATR (2 couches)
    double atr_mult_3layers;         // Multiplicateur ATR (3+ couches)
};

struct SOpenInputs
{
  int           sl_dev_pts;
  bool          close_orders;
  bool          reverse;
  int           open_side; // AURORA_OPEN_SIDE cast
  bool          open_new_pos;
  bool          multiple_open_pos;

  int           spread_limit;
  int           slippage;
  int           timer_interval;
  ulong         magic_number;
  ENUM_FILLING  filling;
  ENUM_ENTRY_MODE entry_mode;
  int           entry_dist_pts;
  int           entry_expiration_sec;
};

// --- STRUCTS (STATE) ---
struct SAuroraState
{
   double   account_equity;      // Real-time Equity
   double   account_balance;     // Solde
   double   profit_total;        // Profit total historique
   double   profit_current;      // Profit flottant actuel
   double   dd_max_alltime;      // Drawdown Max absolu
   double   dd_current;          // Drawdown actuel
   double   dd_daily;            // Drawdown journalier
   
   // News Structure
   struct SNewsItem {
       datetime time;
       string   currency;
       int      impact; // 0=None, 1=Low, 2=Med, 3=High
       string   title;
   };
   SNewsItem news[];
   
   // Deprecated/Removed fields (kept if needed for compile but ignored in logic)
   double   confidence_score;    
   double   trend_direction;     
   int      layers_current;      
   int      layers_max;
   
   // Regime Status (Safe, Toxic, etc)
   string   regime_status;          
};

// --- STRUCTS (ASYNC) ---
struct SAsyncRequest {
    uint request_id;
    MqlTradeRequest req;
    int retries;
    datetime timestamp;
};

// --- SIMULATION INPUTS (Backtest Only) ---
struct SSimulationInputs
{
    bool   enable;
    int    latency_ms;          // Execution Latency (ms)
    int    spread_pad_pts;      // Spread Safety Margin (Points)
    double comm_per_lot;        // Commission par lot ($)
    int    slippage_add_pts;    // Slippage Additionnel (Points)
    int    rejection_prob;      // Rejection probability (%)
    ulong  start_ticket;        // Start ticket (to avoid conflicts)
};

#endif // __AURORA_TYPES_MQH__
