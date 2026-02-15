//+------------------------------------------------------------------+
//|                                               Aurora News Filter |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_NEWSFILTER_MQH__
#define __AURORA_NEWSFILTER_MQH__

#include <Aurora/aurora_news_core.mqh>
#include <Aurora/aurora_logger.mqh>
#include <Aurora/aurora_types.mqh>
#include <Aurora/aurora_time.mqh>

#define AURORA_NEWSFILTER_ADAPTER_VERSION "1.3"
#define AURORA_NEWS_DB_DIR "AURORA\\"

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
   bool                  m_dash_cache_valid;
   datetime              m_dash_cache_bucket;
   int                   m_dash_cache_count;
   datetime              m_dash_cache_core_update;
   SAuroraState::SNewsItem m_dash_cache_news[];

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





   void ResetDecisionCache()
     {
      m_last_decision.valid = false;
      m_last_decision.ts = 0;
      m_last_decision.freeze = false;
      m_last_decision.close_now = false;
      m_last_decision.title = "";
      m_last_decision.currency = "";
     }

   void ResetDashboardCache()
     {
      m_dash_cache_valid = false;
      m_dash_cache_bucket = 0;
      m_dash_cache_count = 0;
      m_dash_cache_core_update = 0;
      ArrayResize(m_dash_cache_news, 0);
     }

   void CopyNewsItems(const SAuroraState::SNewsItem &src[], SAuroraState::SNewsItem &dst[]) const
     {
      const int n = ArraySize(src);
      ArrayResize(dst, n);
      for(int i = 0; i < n; ++i)
         dst[i] = src[i];
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
            CAuroraLogger::InfoNews(StringFormat("[NEWS][BLOCK] freeze-active title=%s currency=%s", decision.title, decision.currency));
         m_prev_title = decision.title;
         m_prev_currency = decision.currency;
        }

      m_prev_freeze = true;

      if(decision.close_now)
        {
         m_close_hits++;
         if(m_inputs.log_news && !same_event)
            CAuroraLogger::WarnNews(StringFormat("[NEWS][ACTION] close-positions title=%s currency=%s", decision.title, decision.currency));
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

      // Delegate all logic to Core (Cached for Tester, API/Cache for Live)
      if(m_core.FreezeNow(now, title, currency))
        {
         freeze = true;
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
      ResetDashboardCache();
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

      const string raw = NormalizeCurrencyList(m_inputs.currencies);
       if(raw == "")
          m_currency_list = NormalizeCurrencyList(AutoCurrencies());
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
      ResetDashboardCache();

      ApplyFilterConfiguration();
      m_configured = true;
     }

   void OnTimer()
     {
      if(!m_configured)
         return;
      m_core.RefreshIfDue(AuroraClock::Now());
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
      CAuroraLogger::InfoNews(StringFormat("[NEWS][DIAG] freeze_hits=%d close_hits=%d", m_freeze_hits, m_close_hits));
     }

   // Wrapper pour le Dashboard
   void GetUpcomingEvents(const int count, SAuroraState::SNewsItem &out_news[])
     {
      ArrayResize(out_news, 0);
      if(!m_configured || count <= 0)
         return;

      const datetime now = AuroraClock::Now();
      const datetime bucket = (now / 60) * 60;
      const datetime core_update = m_core.LastUpdate();

      if(m_dash_cache_valid &&
         m_dash_cache_bucket == bucket &&
         m_dash_cache_count == count &&
         m_dash_cache_core_update == core_update)
        {
         CopyNewsItems(m_dash_cache_news, out_news);
         return;
        }

      CAuroraNewsCore::SEvent evs[];
      m_core.GetUpcomingEvents(now, count, evs);
      
      int n = ArraySize(evs);
      ArrayResize(out_news, n);
      for(int i=0; i<n; i++) {
          out_news[i].time = evs[i].time;
          out_news[i].title = evs[i].title;
          out_news[i].currency = evs[i].currency;
          out_news[i].impact = (int)evs[i].importance;
      }

      CopyNewsItems(out_news, m_dash_cache_news);
      m_dash_cache_valid = true;
      m_dash_cache_bucket = bucket;
      m_dash_cache_count = count;
      m_dash_cache_core_update = core_update;
     }
  };

#endif // __AURORA_NEWSFILTER_MQH__
