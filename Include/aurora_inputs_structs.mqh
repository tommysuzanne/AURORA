//+------------------------------------------------------------------+
//| Aurora Inputs Structs                                           |
//| Version: 1.1                                                    |
//+------------------------------------------------------------------+
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
  bool   grid_min_profit_pct; // Si true, grid_min_profit est un % du solde
};

struct SRiskInputs
{
  double    risk;
  ENUM_RISK risk_mode;
  bool      ignore_sl;
  bool      trail;
  double    trailing_stop_level;
  double    equity_dd_limit;
  // BE inputs laissés globaux (utilisés directement par l'EA)
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