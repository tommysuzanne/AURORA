//+------------------------------------------------------------------+
//| Aurora FTMO Guard — MDL / Max Loss / Pre-Trade / Caps           |
//| Version: 1.1                                                    |
//+------------------------------------------------------------------+
#property strict

#ifndef __AURORA_FTMO_GUARD_MQH__
#define __AURORA_FTMO_GUARD_MQH__

#include "aurora_logger.mqh"

#define AURORA_FTMO_GUARD_VERSION "1.1"

enum ENUM_FTMO_MODE
  {
   FTMO_OFF=0,
   FTMO_CHALLENGE,
   FTMO_VERIFICATION,
   FTMO_ACCOUNT,
   FTMO_ACCOUNT_SWING
  };

enum ENUM_FTMO_HARD
  {
   FTMO_BLOCK_ENTRIES=0,
   FTMO_CLOSE_ALL
  };

struct SFtmoInputs
  {
   ENUM_FTMO_MODE mode;
   // Daily
   double daily_max_pct;
   bool   daily_include_floating;
   int    daily_warn_pct;
   ENUM_FTMO_HARD daily_hard;
   // Total
   double total_max_pct;
   int    total_warn_pct;
   ENUM_FTMO_HARD total_hard;
   // Caps & Pre-Trade
   double cap_lots_order;
   double cap_net_lots_symbol;
   int    cap_max_open_positions;
   bool   pretrade_enable;
   int    pretrade_buffer_pct;
  };

class CAuroraFtmoGuard
  {
private:
   SFtmoInputs m_in;
   double      m_day_anchor_balance;
   double      m_initial_balance;
   bool        m_init_ok;
   bool        m_warned_daily;
   bool        m_warned_total;
   bool        m_daily_hard_active;
   bool        m_total_hard_active;
   int         m_ctr_day_resets;
   int         m_ctr_mdl_hard;
   int         m_ctr_total_hard;
   int         m_ctr_pretrade_veto;
   bool        m_entries_blocked;

   static string InitBalKey()
     {
      return StringFormat("AURORA_INITBAL_%I64d", AccountInfoInteger(ACCOUNT_LOGIN));
     }

   static double TickValuePerPoint(const string symbol)
     {
      const double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      const double tick_size  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      const double point      = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(tick_size<=0 || point<=0) return 0.0;
      const double ticks_per_point = point / tick_size;
      return tick_value * ticks_per_point;
     }

public:
   CAuroraFtmoGuard(): m_day_anchor_balance(0), m_initial_balance(0), m_init_ok(false), m_warned_daily(false), m_warned_total(false), m_daily_hard_active(false), m_total_hard_active(false), m_ctr_day_resets(0), m_ctr_mdl_hard(0), m_ctr_total_hard(0), m_ctr_pretrade_veto(0), m_entries_blocked(false) {}

   void Configure(const SFtmoInputs &in)
     {
      m_in = in;
      if(m_in.daily_max_pct<0) m_in.daily_max_pct=0;
      if(m_in.total_max_pct<0) m_in.total_max_pct=0;
      if(m_in.pretrade_buffer_pct<0) m_in.pretrade_buffer_pct=0;
     }

   void EnsureInitialBalance()
     {
      if(m_init_ok) return;
      const string key = InitBalKey();
      if(GlobalVariableCheck(key))
        m_initial_balance = GlobalVariableGet(key);
      if(m_initial_balance<=0)
        {
         m_initial_balance = AccountInfoDouble(ACCOUNT_BALANCE);
         GlobalVariableSet(key, m_initial_balance);
         if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::InfoFtmo(StringFormat("[INIT] initial_balance=%.2f", m_initial_balance));
        }
      m_init_ok = true;
     }

   void OnNewDay(const double day_anchor_balance)
     {
      m_day_anchor_balance = day_anchor_balance;
      m_warned_daily=false;
      m_daily_hard_active=false;
      m_ctr_day_resets++;
      if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::InfoFtmo(StringFormat("[DAY] anchor_balance=%.2f", m_day_anchor_balance));
     }

   double DayAnchorBalance() const { return m_day_anchor_balance; }
   double InitialBalance() const { return m_initial_balance; }
   double CapNetLotsPerSymbol() const { return m_in.cap_net_lots_symbol; }
   int    MaxOpenPositions() const { return m_in.cap_max_open_positions; }
   void   ResetEntriesBlock() { m_entries_blocked = false; }
   void   SetEntriesBlocked(const bool v) { if(v) m_entries_blocked = true; }
   bool   EntriesBlocked() const { return m_entries_blocked; }

   // Vérification Daily Loss
   bool CheckDaily(const double equity, const double balance, bool &out_warn, bool &out_hard_close_all, bool &out_block_entries)
     {
      out_warn=false; out_hard_close_all=false; out_block_entries=false;
      if(m_in.mode==FTMO_OFF || m_day_anchor_balance<=0) return false;
      // Profits fermés du jour
      double pnl_closed_today = balance - m_day_anchor_balance;
      double pnl_floating = equity - balance;
      double pnl_day = pnl_closed_today + (m_in.daily_include_floating ? pnl_floating : 0.0);
      double loss_day = (pnl_day<0 ? -pnl_day : 0.0);
      if(m_in.daily_max_pct<=0) return false;
      const double limit = m_in.daily_max_pct * 0.01 * m_day_anchor_balance;
      const double warn_th = (m_in.daily_warn_pct>0 ? (m_in.daily_warn_pct * 0.01 * limit) : 0.0);
      if(!m_warned_daily && loss_day >= warn_th && warn_th>0)
        {
         m_warned_daily = true;
         out_warn = true;
         if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::WarnFtmo(StringFormat("[MDL][WARN] loss_day=%.2f / warn=%.2f", loss_day, warn_th));
        }
      if(loss_day >= limit)
        {
         out_block_entries = (m_in.daily_hard==FTMO_BLOCK_ENTRIES || m_in.daily_hard==FTMO_CLOSE_ALL);
         out_hard_close_all= (m_in.daily_hard==FTMO_CLOSE_ALL);
         if(!m_daily_hard_active) { m_daily_hard_active=true; m_ctr_mdl_hard++; }
         if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::ErrorFtmo(StringFormat("[MDL][HARD] loss_day=%.2f / limit=%.2f", loss_day, limit));
         if(out_block_entries) SetEntriesBlocked(true);
         return true;
        }
      m_daily_hard_active=false;
      return false;
     }

   // Vérification Maximum Loss total
   bool CheckTotal(const double equity, bool &out_warn, bool &out_hard_close_all, bool &out_block_entries)
     {
      out_warn=false; out_hard_close_all=false; out_block_entries=false;
      if(m_in.mode==FTMO_OFF || m_initial_balance<=0) return false;
      const double loss_total = MathMax(m_initial_balance - equity, 0.0);
      if(m_in.total_max_pct<=0) return false;
      const double limit = m_in.total_max_pct * 0.01 * m_initial_balance;
      const double warn_th = (m_in.total_warn_pct>0 ? (m_in.total_warn_pct * 0.01 * limit) : 0.0);
      if(!m_warned_total && loss_total >= warn_th && warn_th>0)
        {
         m_warned_total = true;
         out_warn = true;
         if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::WarnFtmo(StringFormat("[TOTAL][WARN] loss_total=%.2f / warn=%.2f", loss_total, warn_th));
        }
      if(loss_total >= limit)
        {
         out_block_entries = (m_in.total_hard==FTMO_BLOCK_ENTRIES || m_in.total_hard==FTMO_CLOSE_ALL);
         out_hard_close_all= (m_in.total_hard==FTMO_CLOSE_ALL);
         if(!m_total_hard_active) { m_total_hard_active=true; m_ctr_total_hard++; }
         if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::ErrorFtmo(StringFormat("[TOTAL][HARD] loss_total=%.2f / limit=%.2f", loss_total, limit));
         if(out_block_entries) SetEntriesBlocked(true);
         return true;
        }
      m_total_hard_active=false;
      return false;
     }

   // Pre-Trade: vérifie qu'ajouter un risque max (SL) ne fait pas dépasser les seuils
   bool PreTradeEnabled() const { return (m_in.mode!=FTMO_OFF && m_in.pretrade_enable); }

   double CapVolumeForSymbol(const string symbol, const double vol) const
     {
      if(m_in.mode==FTMO_OFF) return vol;
      double v = vol;
      if(m_in.cap_lots_order>0) v = MathMin(v, m_in.cap_lots_order);
      const double vol_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      const double vol_min  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      const double vol_max  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      // arrondi et bornes broker
      if(vol_step>0) v = MathFloor(v/vol_step)*vol_step;
      v = MathMax(v, vol_min);
      v = MathMin(v, vol_max);
      return v;
     }

   bool PreTradeOK(const string symbol, const double lot, const double sl_points)
     {
      if(!PreTradeEnabled()) return true;
      const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      const double balance= AccountInfoDouble(ACCOUNT_BALANCE);
      const double tvpp   = TickValuePerPoint(symbol);
      double risk_money   = lot * tvpp * MathAbs(sl_points);
      if(risk_money<=0)
        {
         // fallback conservateur: considérer un risque minimal basé sur FREEZE/STOPS
         const int minPts = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
         risk_money = lot * tvpp * MathMax((double)minPts, 1.0);
        }

      // thresholds avec buffer
      const double daily_limit   = (m_in.daily_max_pct>0 ? m_in.daily_max_pct*0.01*m_day_anchor_balance : DBL_MAX);
      const double total_limit   = (m_in.total_max_pct>0 ? m_in.total_max_pct*0.01*m_initial_balance : DBL_MAX);
      const double buffer_factor = MathMax(0.0, 1.0 - (m_in.pretrade_buffer_pct*0.01));
      const double daily_cap     = (daily_limit==DBL_MAX ? DBL_MAX : daily_limit*buffer_factor);
      const double total_cap     = (total_limit==DBL_MAX ? DBL_MAX : total_limit*buffer_factor);

      // pertes actuelles
      const double pnl_closed_today = balance - m_day_anchor_balance;
      const double pnl_floating     = equity - balance;
      const double loss_day         = MathMax(-(pnl_closed_today + (m_in.daily_include_floating ? pnl_floating : 0.0)), 0.0);
      const double loss_total       = MathMax(m_initial_balance - equity, 0.0);

      const double day_post   = loss_day + risk_money;
      const double total_post = loss_total + risk_money;

      const bool breach_day   = (day_post   >= daily_cap);
      const bool breach_total = (total_post >= total_cap);

      if(breach_day || breach_total)
        {
         m_ctr_pretrade_veto++;
         if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::WarnFtmo(StringFormat("[PRETRADE][BLOCK] lot=%.2f sl_pts=%.1f day_post=%.2f/%.2f total_post=%.2f/%.2f", lot, sl_points, day_post, daily_cap, total_post, total_cap));
         SetEntriesBlocked(true);
         return false;
        }
      return true;
     }

   void GetCounters(int &day_resets, int &mdl_hits, int &total_hits, int &pretrade_vetos) const
     {
      day_resets = m_ctr_day_resets;
      mdl_hits = m_ctr_mdl_hard;
      total_hits = m_ctr_total_hard;
      pretrade_vetos = m_ctr_pretrade_veto;
     }
  };

#endif // __AURORA_FTMO_GUARD_MQH__
