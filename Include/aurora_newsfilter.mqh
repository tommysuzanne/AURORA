//+------------------------------------------------------------------+
//| Aurora News Filter Adapter                                       |
//| Version: 1.0                                                     |
//| Pont entre le filtre legacy (API live) et la couche Aurora.    |
//+------------------------------------------------------------------+
#property strict

#ifndef __AURORA_NEWSFILTER_ADAPTER_MQH__
#define __AURORA_NEWSFILTER_ADAPTER_MQH__

#include "aurora_news_core.mqh"
#include "aurora_logger.mqh"
#include "errordescription.mqh"

#define AURORA_NEWSFILTER_ADAPTER_VERSION "1.0"
#define AURORA_NEWS_DB_DIR "AURORA\\"

enum ENUM_NEWS_LEVELS
  {
   NEWS_LEVELS_NONE = 0,
   NEWS_LEVELS_HIGH_ONLY,
   NEWS_LEVELS_HIGH_MEDIUM,
   NEWS_LEVELS_ALL
  };

enum ENUM_NEWS_ACTION
  {
   NEWS_ACTION_BLOCK_ENTRIES = 0,
   NEWS_ACTION_BLOCK_MANAGE,
   NEWS_ACTION_BLOCK_ALL_CLOSE
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

class CAuroraNewsFilter
  {
private:
   SNewsInputs           m_inputs;
   CAuroraNewsCore       m_core;
   string                m_currency_list;
   string                m_symbol;
   bool                  m_level_high;
   bool                  m_level_medium;
   bool                  m_level_low;
   bool                  m_configured;
   bool                  m_db_checked;
   bool                  m_db_available;
   string                m_db_path;
   int                   m_freeze_hits;
   int                   m_close_hits;
   bool                  m_prev_freeze;
   string                m_prev_title;
   string                m_prev_currency;

   struct SDecision
     {
      bool     valid;
      datetime ts;
      bool     freeze;
      bool     close_now;
      string   title;
      string   currency;
     };
   SDecision             m_last_decision;

   string NormalizeList(const string raw) const
     {
      string formatted = raw;
      StringReplace(formatted, " ", "");
      StringToUpper(formatted);
      return(formatted);
     }

   string AutoCurrencies() const
     {
      string base = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_BASE);
      string profit = SymbolInfoString(m_symbol, SYMBOL_CURRENCY_PROFIT);

      StringToUpper(base);
      StringToUpper(profit);

      if(base == profit)
         return(base);

      if(base == "" && profit == "")
         return("");

      if(base == "")
         return(profit);

      if(profit == "")
         return(base);

      if(StringFind(base, profit) == 0)
         return(base);

      return(base + "," + profit);
     }

   bool CurrencyAllowed(const string currency) const
     {
      if(m_currency_list == "" || currency == "")
         return(true);

      string cur = currency;
      StringToUpper(cur);
      return(StringFind("," + m_currency_list + ",", "," + cur + ",") != -1);
     }

   bool LevelEnabled(const ENUM_CALENDAR_EVENT_IMPORTANCE importance) const
     {
      if(importance == CALENDAR_IMPORTANCE_HIGH)
         return(m_level_high);
      if(importance == CALENDAR_IMPORTANCE_MODERATE)
         return(m_level_medium);
      if(importance == CALENDAR_IMPORTANCE_LOW)
         return(m_level_low);
      return(false);
     }

   bool HasActiveLevels() const
     {
      return(m_level_high || m_level_medium || m_level_low);
     }

   void ApplyFilterConfiguration()
     {
      const bool enable = m_inputs.enable && HasActiveLevels();
      m_core.Configure(enable,
                       m_level_high,
                       m_level_medium,
                       m_level_low,
                       m_currency_list,
                       m_inputs.blackout_before,
                       m_inputs.blackout_after,
                       m_inputs.min_core_high_min,
                       m_inputs.refresh_minutes,
                       m_inputs.log_news);
     }

   bool EnsureDbPath()
     {
      if(m_db_checked)
         return(m_db_available);

      m_db_path = AURORA_NEWS_DB_DIR + "calendar-" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".db";
      m_db_available = FileIsExist(m_db_path, FILE_COMMON);
      m_db_checked = true;
      return(m_db_available);
     }

   bool EvaluateDb(const datetime now,
                   string &out_title,
                   string &out_currency,
                   ENUM_CALENDAR_EVENT_IMPORTANCE &out_importance)
     {
      out_title = "";
      out_currency = "";
      out_importance = CALENDAR_IMPORTANCE_NONE;

      if(!EnsureDbPath())
         return(false);

      int db = DatabaseOpen(m_db_path, DATABASE_OPEN_READONLY | DATABASE_OPEN_COMMON);
      if(db == INVALID_HANDLE)
        {
         const int err = GetLastError();
         if(m_inputs.log_news)
            CAuroraLogger::WarnNews(StringFormat("DatabaseOpen échoue (%d): %s", err, ErrorDescription(err)));
         m_db_available = false;
         return(false);
        }

      const int padded_before = MathMax(m_inputs.blackout_before, m_inputs.min_core_high_min);
      const int padded_after  = MathMax(m_inputs.blackout_after, m_inputs.min_core_high_min);
      const datetime from = now - padded_before * 60;
      const datetime to   = now + padded_after * 60;

      const string sql = StringFormat("SELECT time, importance, name, currency FROM main WHERE time >= %d AND time <= %d ORDER BY time ASC", from, to);
      const int stmt = DatabasePrepare(db, sql);
      if(stmt == INVALID_HANDLE)
        {
         const int err = GetLastError();
         if(m_inputs.log_news)
            CAuroraLogger::WarnNews(StringFormat("DatabasePrepare échoue (%d): %s", err, ErrorDescription(err)));
         DatabaseClose(db);
         return(false);
        }

      bool freeze = false;
      long ev_time = 0;
      long ev_importance = 0;
      string ev_title = "";
      string ev_currency = "";

      while(DatabaseRead(stmt) && !IsStopped())
        {
         DatabaseColumnLong(stmt, 0, ev_time);
         DatabaseColumnLong(stmt, 1, ev_importance);
         DatabaseColumnText(stmt, 2, ev_title);
         DatabaseColumnText(stmt, 3, ev_currency);

         ENUM_CALENDAR_EVENT_IMPORTANCE imp = (ENUM_CALENDAR_EVENT_IMPORTANCE)ev_importance;
         if(!LevelEnabled(imp))
            continue;

         if(!CurrencyAllowed(ev_currency))
            continue;

         int before = m_inputs.blackout_before;
         int after  = m_inputs.blackout_after;
         if(imp == CALENDAR_IMPORTANCE_HIGH)
           {
            before = MathMax(before, m_inputs.min_core_high_min);
            after  = MathMax(after, m_inputs.min_core_high_min);
           }

         const datetime event_time = (datetime)ev_time;
         const datetime start = event_time - before * 60;
         const datetime end   = event_time + after * 60;

         if(now < start || now > end)
            continue;

         freeze = true;
         out_title = ev_title;
         out_currency = ev_currency;
         out_importance = imp;
         break;
        }

      DatabaseFinalize(stmt);
      DatabaseClose(db);
      return(freeze);
     }

   void ResetDecisionCache()
     {
      m_last_decision.valid = false;
      m_last_decision.ts = 0;
      m_last_decision.freeze = false;
      m_last_decision.close_now = false;
      m_last_decision.title = "";
      m_last_decision.currency = "";
     }

   void HandleDiagnostics(const SDecision &decision)
     {
      if(!decision.freeze)
        {
         m_prev_freeze = false;
         m_prev_title = "";
         m_prev_currency = "";
         return;
        }

      const bool same_event = (m_prev_freeze &&
                               m_prev_title == decision.title &&
                               m_prev_currency == decision.currency);

      if(!same_event)
        {
         m_freeze_hits++;
         if(m_inputs.log_news)
            CAuroraLogger::InfoNews(StringFormat("[BLOCK] Freeze actif — %s (%s)", decision.title, decision.currency));
         m_prev_title = decision.title;
         m_prev_currency = decision.currency;
        }

      m_prev_freeze = true;

      if(decision.close_now)
        {
         m_close_hits++;
         if(m_inputs.log_news && !same_event)
            CAuroraLogger::WarnNews(StringFormat("[ACTION] Fermeture positions — %s (%s)", decision.title, decision.currency));
        }
     }

   void EvaluateDecision(const datetime now)
     {
      if(m_last_decision.valid && m_last_decision.ts == now)
         return;

      SDecision decision;
      decision.valid = true;
      decision.ts = now;
      decision.freeze = false;
      decision.close_now = false;
      decision.title = "";
      decision.currency = "";

      if(!(m_inputs.enable && HasActiveLevels()))
        {
         m_last_decision = decision;
         return;
        }

      string title = "";
      string currency = "";
      ENUM_CALENDAR_EVENT_IMPORTANCE imp = CALENDAR_IMPORTANCE_NONE;
      bool freeze = false;

      if(MQLInfoInteger(MQL_TESTER))
        {
         freeze = EvaluateDb(now, title, currency, imp);
        }

      if(!freeze)
        {
         freeze = m_core.FreezeNow(now, title, currency);
        }

      if(freeze)
        {
         decision.freeze = true;
         decision.title = title;
         decision.currency = currency;
         decision.close_now = (m_inputs.action == NEWS_ACTION_BLOCK_ALL_CLOSE);
        }

      m_last_decision = decision;
      HandleDiagnostics(m_last_decision);
     }

public:
   CAuroraNewsFilter()
     {
      m_inputs.enable = false;
      m_inputs.levels = NEWS_LEVELS_NONE;
      m_inputs.currencies = "";
      m_inputs.blackout_before = 0;
      m_inputs.blackout_after = 0;
      m_inputs.min_core_high_min = 2;
      m_inputs.action = NEWS_ACTION_BLOCK_ENTRIES;
      m_inputs.refresh_minutes = 15;
      m_inputs.log_news = false;
      m_currency_list = "";
      m_symbol = _Symbol;
      m_level_high = false;
      m_level_medium = false;
      m_level_low = false;
      m_configured = false;
      m_db_checked = false;
      m_db_available = false;
      m_db_path = "";
      m_freeze_hits = 0;
      m_close_hits = 0;
      m_prev_freeze = false;
      m_prev_title = "";
      m_prev_currency = "";
      ResetDecisionCache();
     }

   void Configure(const SNewsInputs &params)
     {
      m_inputs = params;
      m_symbol = _Symbol;

      switch((int)m_inputs.levels)
        {
         case NEWS_LEVELS_HIGH_ONLY:
            m_level_high = true;
            m_level_medium = false;
            m_level_low = false;
            break;
         case NEWS_LEVELS_HIGH_MEDIUM:
            m_level_high = true;
            m_level_medium = true;
            m_level_low = false;
            break;
         case NEWS_LEVELS_ALL:
            m_level_high = true;
            m_level_medium = true;
            m_level_low = true;
            break;
         default:
            m_level_high = false;
            m_level_medium = false;
            m_level_low = false;
            break;
        }

      const string raw = NormalizeList(m_inputs.currencies);
      if(raw == "")
         m_currency_list = NormalizeList(AutoCurrencies());
      else
         m_currency_list = raw;

      m_db_checked = false;
      m_db_available = false;
      m_freeze_hits = 0;
      m_close_hits = 0;
      m_prev_freeze = false;
      m_prev_title = "";
      m_prev_currency = "";
      ResetDecisionCache();

      ApplyFilterConfiguration();
      m_configured = true;
     }

   void OnTimer()
     {
      if(!m_configured)
         return;
      m_core.RefreshIfDue(TimeTradeServer());
     }

   bool FreezeNow(const datetime now,
                  string &title,
                  string &currency)
     {
      title = "";
      currency = "";

      if(!m_configured)
         return(false);

      EvaluateDecision(now);
      title = m_last_decision.title;
      currency = m_last_decision.currency;
      return(m_last_decision.freeze);
     }

   bool ShouldCloseNow(const datetime now,
                       string &title,
                       string &currency)
     {
      title = "";
      currency = "";

      if(!m_configured)
         return(false);

      EvaluateDecision(now);
      title = m_last_decision.title;
      currency = m_last_decision.currency;
      return(m_last_decision.close_now);
     }

   void FlushDiagnostics()
     {
      if(!m_inputs.log_news)
         return;
      CAuroraLogger::InfoNews(StringFormat("[DIAG] freeze_hits=%d close_hits=%d", m_freeze_hits, m_close_hits));
     }
  };

#endif // __AURORA_NEWSFILTER_ADAPTER_MQH__
