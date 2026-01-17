//+------------------------------------------------------------------+
//|                                                    Aurora Inputs |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property version   "1.3"
#property strict

#ifndef __AURORA_INPUTS_STRUCTS_MQH__
#define __AURORA_INPUTS_STRUCTS_MQH__

struct SIndicatorInputs
{
  int    ce_atr_period;
  double ce_atr_mult;
  int    zl_period;
  bool   grid;
  double grid_vol_mult;
  double grid_trail_level;
  int    grid_max_lvl;
  
  // Paramètres Grid Avancés (v1.31+)
  bool   grid_dynamic;        // Espacement dynamique basé sur ATR
  int    grid_atr_period;     // Période ATR pour le calcul dynamique
  double grid_atr_mult;       // Multiplicateur ATR pour l'espacement
  double grid_min_profit;     // Cible de profit minimum pour fermer la grille
  int    grid_profit_mode;    // Mode de profit (ENUM_GRID_PROFIT_MODE cast)
  double grid_max_atr;        // Filtre Volatilité (Step 3.2)
};

struct SDashboardInputs
{
  bool enable; // Activer le Dashboard
};

enum ENUM_GRID_PROFIT_MODE {
    GRID_PROFIT_CURRENCY, // Montant Fixe ($)
    GRID_PROFIT_PERCENT,  // % du Solde
    GRID_PROFIT_POINTS    // Points (Distance)
};

enum ENUM_FILLING {
    FILLING_DEFAULT, // Auto (Par défaut)
    FILLING_FOK,     // FOK (Fill or Kill)
    FILLING_IOK,     // IOK (Immediate or Cancel)
    FILLING_BOC,     // BOC (Book or Cancel)
    FILLING_RETURN   // Return
};

enum ENUM_RISK {
    RISK_DEFAULT,     // Auto (Balance/MargeSafe)
    RISK_FIXED_VOL,   // Volume Fixe (Lots)
    RISK_MIN_AMOUNT,  // Montant Fixe ($)
    RISK_EQUITY = ACCOUNT_EQUITY,           // % Equité
    RISK_BALANCE = ACCOUNT_BALANCE,         // % Balance
    RISK_MARGIN_FREE = ACCOUNT_MARGIN_FREE, // % Marge Libre
    RISK_CREDIT = ACCOUNT_CREDIT            // % Crédit
};

enum ENUM_TRAIL_MODE
{
  TRAIL_STANDARD, // Standard (Basé sur le SL)
  TRAIL_ATR       // Volatilité (ATR)
};

enum ENUM_SESSION_CLOSE_MODE {
    SESS_MODE_OFF,          // Inactif: Bloque tout hors session, grille figée
    SESS_MODE_FORCE_CLOSE,  // Fermeture Forcée: Ferme tout immédiatement
    SESS_MODE_RECOVERY,     // Gestion Seule: Bloque entrées, autorise grille
    SESS_MODE_SMART_EXIT,   // Sortie Intelligente: Ferme si Profit > 0
    SESS_MODE_DELEVERAGE    // Allègement Tactique: Réduit l'exposition
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
  // BE inputs laissés globaux (utilisés directement par l'EA)
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
   ENUM_SESSION_CLOSE_MODE close_mode;
   double deleverage_target_pct;
   bool close_restricted_days;
   bool respect_broker_sessions;
  };

enum ENUM_BE_MODE { 
    BE_MODE_RATIO,  // Ratio (R:R)
    BE_MODE_POINTS  // Points Fixes
};

struct SMarginGuardInputs
{
  bool   enable;
  double stretch_level;
  double stretch_max_mult;
  double delev_level;
  bool   delev_worst;
  bool   damping_enable;
  double damping_start;
  double damping_min_mult;
  double damping_low_bound;
};

struct SSmartGridInputs
{
  bool   reduction_enable;
  int    reduction_start_lvl;
  double reduction_profit_ratio;
  double reduction_min_vol;
  double reduction_winner_close_percent;
};

enum ENUM_INFINITY_STEP_MODE {
    INF_STEP_PERCENT, // Pourcentage du profit
    INF_STEP_POINTS,  // Points fixes (Distance)
    INF_STEP_ATR      // Volatilité (ATR)
};

struct SInfinityInputs
{
  bool   enable;
  double trigger_pct; // % of Target Profit to trigger infinity (e.g. 90)
  double trailing_step; // Dedicated trailing step for Infinity Mode
  int    tp_distance;   // Distance TP Infinity (points)
  ENUM_INFINITY_STEP_MODE step_mode; // Mode de calcul du trailing step
  int    atr_period;    // ATR Period for Infinity Mode
  double atr_mult;      // ATR Multiplier for Infinity Mode
};

// Mode de Trailing pour le Pyramidage (v1.6)
enum ENUM_PYRA_TRAIL_MODE
{
   PYRA_TRAIL_POINTS,   // Mode Distance Fixe (Points)
   PYRA_TRAIL_ATR       // Mode Dynamique (ATR)
};

struct SDynamicRiskInputs
{
  bool   enable;              // Activer le calcul de lot dynamique
  double min_risk_factor;     // Facteur de risque Minimum (0.5 = -50%)
  double max_risk_factor;     // Facteur de risque Maximum (1.5 = +50%)
  
  double weight_efficiency;    // Poids de l'Efficacité (Kaufman)
  double weight_trend_stability; // Poids de la stabilité ZLSMA
  double weight_volatility;    // Poids de la volatilité
  
  int    er_period;           // Période Efficiency Ratio
  int    zlsma_slope_period;  // Période calcul pente (ZLSMA)
};

struct STrendScaleInputs
{
    bool   enable;              // Activer le pyramidage
    int    max_layers;          // Nombre max d'ajouts (ex: 3)
    double scaling_step_pts;    // Distance en points pour déclencher un ajout (ex: 500 pts)
    double volume_mult;         // Multiplicateur de volume pour l'ajout (ex: 1.0 ou 0.5)
    double min_confidence;      // Score de confiance min requis (ex: 0.8)
    bool   trailing_sync;       // Activer la syncronisation du SL (Trailing de groupe)
    int    trail_dist_2layers;  // Distance Trailing pour 2 couches (ex: 300 pts)
    int    trail_dist_3layers;  // Distance Trailing pour 3+ couches (ex: 150 pts)
    
    // Nouveaux paramètres ATR (v1.6)
    ENUM_PYRA_TRAIL_MODE trail_mode; // Mode de calcul (Fixed ou ATR)
    int    atr_period;               // Période ATR
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
  double        margin_limit;
  int           spread_limit;
  int           slippage;
  int           timer_interval;
  ulong         magic_number;
  ENUM_FILLING  filling;
};

#endif // __AURORA_INPUTS_STRUCTS_MQH__