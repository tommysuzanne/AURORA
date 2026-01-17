//+------------------------------------------------------------------+
//|                                                 Aurora News Core |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property version   "1.3"
#property strict

#ifndef __AURORA_NEWS_CORE_MQH__
#define __AURORA_NEWS_CORE_MQH__

#include <aurora_logger.mqh>
#include <aurora_error_utils.mqh>

#define AURORA_NEWS_CORE_VERSION "1.3"

class CAuroraNewsCore
  {
private:
   bool     m_enable;
   bool     m_level_high;
   bool     m_level_medium;
   bool     m_level_low;
   string   m_currencies;         // "USD,EUR,GBP" (uppercase, sans espaces)
   int      m_blackout_before;    // minutes
   int      m_blackout_after;     // minutes
   int      m_min_core_high_min;  // minutes
   int      m_refresh_minutes;     // cadence OnTimer
   bool     m_log_news;

   datetime m_last_update;

public:
   struct SEvent
     {
      datetime time;
      string   title;
      string   currency;
      ENUM_CALENDAR_EVENT_IMPORTANCE importance;
     };
private:
   SEvent   m_events[];

   void NormalizeList(const string raw) const { } // Removed, using Global EAUtils::NormalizeCurrencyList


   bool CurrencyAllowed(const string currency) const
     {
      if(m_currencies == "" || currency == "") return(true);
      string cur = currency; StringToUpper(cur);
      return(StringFind("," + m_currencies + ",", "," + cur + ",") != -1);
     }

   bool LevelEnabled(const ENUM_CALENDAR_EVENT_IMPORTANCE imp) const
     {
      if(imp == CALENDAR_IMPORTANCE_HIGH)     return(m_level_high);
      if(imp == CALENDAR_IMPORTANCE_MODERATE) return(m_level_medium);
      if(imp == CALENDAR_IMPORTANCE_LOW)      return(m_level_low);
      return(false);
     }

   void FetchApi(const datetime now)
     {
      ArrayResize(m_events, 0);
      if(!m_enable) return;

      const int b0 = (m_blackout_before<0?0:m_blackout_before);
      const int a0 = (m_blackout_after <0?0:m_blackout_after);
      const int bb = (m_min_core_high_min>b0?m_min_core_high_min:b0);
      const int aa = (m_min_core_high_min>a0?m_min_core_high_min:a0);
      const int margin_min = 60; 
      const int display_lookahead_min = 10080; // 7 jours pour affichage dashboard (Week-end safe)
      const datetime from = now - bb*60;
      const datetime to   = now + MathMax((aa+margin_min)*60, display_lookahead_min*60);

      // Split currencies list
      string list = m_currencies;
      int start=0; string cur;
      bool used_currency_filter = (list!="");
      do {
         int pos = StringFind(list, ",", start);
         cur = (pos==-1)? StringSubstr(list, start): StringSubstr(list, start, pos-start);
         if(cur!="")
           {
            MqlCalendarValue values[]; int total = CalendarValueHistory(values, from, to, NULL, cur);
            if(total < 0)
              {
               const int err = GetLastError();
               if(m_log_news)
                 {
                  if(err==5402) CAuroraLogger::WarnNews(StringFormat("Calendrier: NO_DATA pour %s (neutralité)", cur));
                  else if(err==5401) CAuroraLogger::WarnNews(StringFormat("Calendrier: TIMEOUT pour %s (neutralité)", cur));
                  else CAuroraLogger::WarnNews(StringFormat("Calendrier indisponible (%d) pour %s", err, cur));
                 }
              }
            for(int i=0;i<total;++i)
              {
               MqlCalendarEvent ev; ZeroMemory(ev);
               if(!CalendarEventById(values[i].event_id, ev)) continue;
               string ccy=""; MqlCalendarCountry co; ZeroMemory(co);
               if(CalendarCountryById(ev.country_id, co)) ccy = co.currency;
               if(!CurrencyAllowed(ccy)) continue;
               const int idx = ArraySize(m_events); ArrayResize(m_events, idx+1);
               m_events[idx].time       = values[i].time;
               m_events[idx].title      = ev.name;
               m_events[idx].currency   = ccy;
               m_events[idx].importance = ev.importance;
              }
           }
         if(pos==-1) break; start=pos+1;
      } while(true);

      if(!used_currency_filter)
        {
         // Pas de devise spécifiée: requête générale sur fenêtre courte
         MqlCalendarValue values[]; int total = CalendarValueHistory(values, from, to);
         if(total < 0)
           {
            const int err = GetLastError();
            if(m_log_news)
              {
               if(err==5402) CAuroraLogger::WarnNews("Calendrier: NO_DATA (neutralité)");
               else if(err==5401) CAuroraLogger::WarnNews("Calendrier: TIMEOUT (neutralité)");
               else CAuroraLogger::WarnNews(StringFormat("Calendrier indisponible (%d)", err));
              }
           }
         for(int i=0;i<total;++i)
           {
            MqlCalendarEvent ev; ZeroMemory(ev);
            if(!CalendarEventById(values[i].event_id, ev)) continue;
            string ccy=""; MqlCalendarCountry co; ZeroMemory(co);
            if(CalendarCountryById(ev.country_id, co)) ccy = co.currency;
            if(!CurrencyAllowed(ccy)) continue;
            const int idx = ArraySize(m_events); ArrayResize(m_events, idx+1);
            m_events[idx].time       = values[i].time;
            m_events[idx].title      = ev.name;
            m_events[idx].currency   = ccy;
            m_events[idx].importance = ev.importance;
           }
        }

      m_last_update = TimeTradeServer();
      if(m_log_news)
         CAuroraLogger::InfoNews(StringFormat("[DATA] News: %d évènements (cache, window=%d/%d+%d)", ArraySize(m_events), b0, a0, margin_min));
     }

   bool EvaluateApiFreeze(const datetime now,
                          string &out_title,
                          string &out_currency) const
     {
      out_title = ""; out_currency = "";
      const int b = (m_blackout_before<0?0:m_blackout_before);
      const int a = (m_blackout_after <0?0:m_blackout_after);
      const bool fresh = (ArraySize(m_events)>0 && m_last_update>0 && (TimeTradeServer()-m_last_update) <= (m_refresh_minutes*60 + 30));
      if(fresh)
        {
         for(int i=0;i<ArraySize(m_events);++i)
           {
            const SEvent ev = m_events[i];
            if(!LevelEnabled(ev.importance)) continue;
            if(!CurrencyAllowed(ev.currency)) continue;
            int bb=b, aa=a;
            if(ev.importance==CALENDAR_IMPORTANCE_HIGH)
              { if(m_min_core_high_min>bb) bb=m_min_core_high_min; if(m_min_core_high_min>aa) aa=m_min_core_high_min; }
            const datetime start = ev.time - bb*60;
            const datetime end   = ev.time + aa*60;
            if(now>=start && now<=end)
              { out_title=ev.title; out_currency=ev.currency; return(true); }
           }
         // Pas trouvé dans le cache: on poursuivra avec le fallback direct ci‑dessous
        }
      // Fallback direct API si pas de cache — fenêtre minimale + filtre devise si disponible
      const int bb2 = (m_min_core_high_min>b?m_min_core_high_min:b);
      const int aa2 = (m_min_core_high_min>a?m_min_core_high_min:a);
      const datetime from2 = now - bb2*60;
      const datetime to2   = now + aa2*60;

      string list2=m_currencies; int start2=0; string cur2; bool used2=(list2!="");
      do {
        int pos2 = StringFind(list2, ",", start2);
        cur2 = (pos2==-1)? StringSubstr(list2, start2): StringSubstr(list2, start2, pos2-start2);
        if(cur2!="" || !used2)
        {
          MqlCalendarValue values[];
          int total = used2 ? CalendarValueHistory(values, from2, to2, NULL, cur2)
                            : CalendarValueHistory(values, from2, to2);
          if(total>0)
          {
            for(int i=0;i<total;++i)
            {
              MqlCalendarEvent ev; ZeroMemory(ev);
              if(!CalendarEventById(values[i].event_id, ev)) continue;
              if(!LevelEnabled(ev.importance)) continue;
              string ccy=""; MqlCalendarCountry co; ZeroMemory(co);
              if(CalendarCountryById(ev.country_id, co)) ccy = co.currency;
              if(!CurrencyAllowed(ccy)) continue;
              int bbx=b, aax=a;
              if(ev.importance==CALENDAR_IMPORTANCE_HIGH)
                { if(m_min_core_high_min>bbx) bbx=m_min_core_high_min; if(m_min_core_high_min>aax) aax=m_min_core_high_min; }
              const datetime startw = values[i].time - bbx*60;
              const datetime endw   = values[i].time + aax*60;
              if(now>=startw && now<=endw)
                { out_title=ev.name; out_currency=ccy; return(true); }
            }
          }
        }
        if(pos2==-1) break; start2=pos2+1;
      } while(true);
      return(false);
     }

   bool EnsureDbPath(string &out_path) const
     {
      out_path = "AURORA\\" + (string)"calendar-" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".db";
      return(FileIsExist(out_path, FILE_COMMON));
     }



public:
   CAuroraNewsCore()
     {
      m_enable=false; m_level_high=false; m_level_medium=false; m_level_low=false;
      m_currencies=""; m_blackout_before=0; m_blackout_after=0; m_min_core_high_min=2; m_refresh_minutes=15; m_log_news=false;
      m_last_update=0; ArrayResize(m_events,0);
     }

   void Configure(const bool enable,
                  const bool level_high,
                  const bool level_medium,
                  const bool level_low,
                  const string currencies,
                  const int blackout_before,
                  const int blackout_after,
                  const int min_core_high_min,
                  const int refresh_minutes,
                  const bool log_news)
     {
      m_enable = enable; m_level_high=level_high; m_level_medium=level_medium; m_level_low=level_low;
      m_currencies = NormalizeCurrencyList(currencies);
      m_blackout_before = MathMax(blackout_before,0);
      m_blackout_after  = MathMax(blackout_after,0);
      m_min_core_high_min = MathMax(min_core_high_min,0);
      m_refresh_minutes = (refresh_minutes<=0?15:refresh_minutes);
      m_log_news = log_news;
      m_last_update = 0; ArrayResize(m_events,0);
      
      if(m_enable && MQLInfoInteger(MQL_TESTER)) LoadDbToCache();
     }

   void RefreshIfDue(const datetime now)
     {
      if(!m_enable) return;
      if(MQLInfoInteger(MQL_TESTER)) return; // Tester uses cache loaded in Configure
      if(!m_enable) return;
      if(m_last_update==0 || (TimeTradeServer()-m_last_update) >= m_refresh_minutes*60)
         FetchApi(now);
     }

   // Load entire DB to memory for Tester optimization (O(1) access vs Disk I/O)
   void LoadDbToCache()
     {
      ArrayResize(m_events, 0);
      string dbPath="";
      if(!EnsureDbPath(dbPath)) return;

      int db = DatabaseOpen(dbPath, DATABASE_OPEN_READONLY | DATABASE_OPEN_COMMON);
      if(db == INVALID_HANDLE) {
          if(m_log_news) CAuroraLogger::WarnNews(StringFormat("DatabaseOpen Failed: %d", GetLastError()));
          return;
      }

      string query = "SELECT time, importance, name, currency FROM main ORDER BY time ASC";
      int stmt = DatabasePrepare(db, query);
      if(stmt == INVALID_HANDLE) {
          DatabaseClose(db);
          return;
      }

      long ev_time=0, ev_imp=0; string ev_title="", ev_ccy="";
      while(DatabaseRead(stmt) && !IsStopped()) {
          DatabaseColumnLong(stmt, 0, ev_time);
          DatabaseColumnLong(stmt, 1, ev_imp);
          DatabaseColumnText(stmt, 2, ev_title);
          DatabaseColumnText(stmt, 3, ev_ccy);

          if(!CurrencyAllowed(ev_ccy)) continue;
          if(!LevelEnabled((ENUM_CALENDAR_EVENT_IMPORTANCE)ev_imp)) continue;

          int idx = ArraySize(m_events);
          ArrayResize(m_events, idx+1, 1000); 
          m_events[idx].time = (datetime)ev_time;
          m_events[idx].importance = (ENUM_CALENDAR_EVENT_IMPORTANCE)ev_imp;
          m_events[idx].title = ev_title;
          m_events[idx].currency = ev_ccy;
      }
      DatabaseFinalize(stmt);
      DatabaseClose(db);
      
      m_last_update = TimeCurrent(); 
      if(m_log_news) CAuroraLogger::InfoNews(StringFormat("[TESTER] Loaded %d events to memory cache", ArraySize(m_events)));
     }

   bool EvaluateMemoryFreeze(const datetime now, string &out_title, string &out_currency) const
     {
      out_title = ""; out_currency = "";
      int total = ArraySize(m_events);
      if(total == 0) return false;
      
      for(int i=0; i<total; ++i) {
          const SEvent ev = m_events[i];
          int aa = m_blackout_after;
          if(ev.importance == CALENDAR_IMPORTANCE_HIGH) if(m_min_core_high_min > aa) aa = m_min_core_high_min;
          
          if(ev.time + aa * 60 < now) continue;
          
          int bb = m_blackout_before;
          if(ev.importance == CALENDAR_IMPORTANCE_HIGH) if(m_min_core_high_min > bb) bb = m_min_core_high_min;
          
          if(ev.time - bb * 60 > now) return false; 
          
          if(CurrencyAllowed(ev.currency) && LevelEnabled(ev.importance)) {
               datetime start = ev.time - bb * 60;
               datetime end = ev.time + aa * 60;
               if(now >= start && now <= end) {
                   out_title = ev.title;
                   out_currency = ev.currency;
                   return true;
               }
          }
      }
      return false;
     }

   bool FreezeNow(const datetime now,
                  string &out_title,
                  string &out_currency)
     {
      out_title=""; out_currency="";
      if(!m_enable || !(m_level_high||m_level_medium||m_level_low)) return(false);

      bool freeze=false; 
      
      if(MQLInfoInteger(MQL_TESTER))
      {
          if(ArraySize(m_events) == 0 && m_last_update == 0) LoadDbToCache();
          freeze = EvaluateMemoryFreeze(now, out_title, out_currency);
      }
      else
      {
          freeze = EvaluateApiFreeze(now, out_title, out_currency);
      }
      
      return(freeze);
     }
     
   void GetUpcomingEvents(const datetime now, const int count, SEvent &out_results[]) {
      ArrayResize(out_results, 0);
      int total = ArraySize(m_events);
      if(total == 0) return;
      
      // Collect future events
      int found = 0;
      for(int i=0; i<total; i++) {
         if(m_events[i].time >= now) {
            // Check filters
            if(!LevelEnabled(m_events[i].importance)) continue;
            if(!CurrencyAllowed(m_events[i].currency)) continue;
            
            ArrayResize(out_results, found+1);
            out_results[found] = m_events[i];
            found++;
         }
      }
      
      // Sort by time (Bubble sort simple car liste courte)
      int n = ArraySize(out_results);
      for(int i=0; i<n-1; i++) {
         for(int j=0; j<n-i-1; j++) {
            if(out_results[j].time > out_results[j+1].time) {
               SEvent temp = out_results[j];
               out_results[j] = out_results[j+1];
               out_results[j+1] = temp;
            }
         }
      }
      
      // Trim to count
      if(n > count) ArrayResize(out_results, count);
   }
  };

#endif // __AURORA_NEWS_CORE_MQH__
