//+------------------------------------------------------------------+
//| Aurora Session Manager (MQL5_X)                                  |
//| Version: 1.2                                                     |
//| Jours autorisés + fenêtre horaire + respect sessions broker.     |
//+------------------------------------------------------------------+
#property strict
#property version   "1.01"

#ifndef __AURORA_SESSION_MANAGER_MQH__
#define __AURORA_SESSION_MANAGER_MQH__

#include "aurora_logger.mqh"
#include "aurora_time_helper.mqh"

#define AURORA_SESSION_VERSION "1.2"

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
   bool close_outside;
   bool close_restricted_days;
   bool respect_broker_sessions;
   int  timer_sec; // cadence de contrôle via OnTimer
  };

class CAuroraSessionManager
  {
private:
   bool m_trade_day[7]; // 0=Lundi … 6=Dimanche
   bool m_enable_time;
   int  m_start_hour, m_start_min, m_end_hour, m_end_min;
   bool m_close_outside, m_close_restricted;
   bool m_respect_broker;

   int  m_last_allow; // -1 inconnu, 0/1 état
   int  m_last_close; // -1 inconnu, 0/1 état

   static int ClampI(const int v, const int lo, const int hi)
     { return (int)MathMax((double)lo, (double)MathMin((double)v, (double)hi)); }

   static int DayIndexMondayZero(const datetime t)
     { return AuroraTimeHelper::DayIndexMondayZero(t); }

   bool IsDayAllowed(const datetime now)
     {
      return m_trade_day[DayIndexMondayZero(now)];
     }

   static int MinutesOfDay(const datetime t)
     { return AuroraTimeHelper::MinutesOfDay(t); }

   bool IsWithinTimeWindow(const datetime now)
     {
      if(!m_enable_time) return true;
      const int minutes = MinutesOfDay(now);
      const int start   = m_start_hour * 60 + m_start_min;
      const int end     = m_end_hour   * 60 + m_end_min;
      if(start <= end) return (minutes >= start && minutes <= end);
      // overnight (ex: 22:00→04:00)
      return (minutes >= start || minutes <= end);
     }

   bool InAnyBrokerTradingSession(const datetime now, const string symbol)
     {
      if(!m_respect_broker) return true;
      MqlDateTime dt; TimeToStruct(now, dt);
      // ENUM_DAY_OF_WEEK de MQL5: 0=dimanche … 6=samedi
      const int mql5_dow = dt.day_of_week;
      datetime from=0, to=0;
      bool any=false;
      for(uint i=0; i<10; ++i) // jusqu'à 10 fenêtres par jour (sûrement suffisant)
        {
         if(!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)mql5_dow, i, from, to))
           break;
         any = true;
         int from_min = (int)((from % 86400) / 60);
         int to_min   = (int)((to   % 86400) / 60);
         const int now_min = MinutesOfDay(now);
         if(from_min <= to_min)
           {
            if(now_min >= from_min && now_min <= to_min)
               return true;
           }
         else
           {
            // overnight au niveau broker
            if(now_min >= from_min || now_min <= to_min)
               return true;
           }
        }
      // Fallback conservateur si le broker ne renvoie aucune session
      // Fermer le week‑end (dimanche/samedi) sinon considérer comme non restreint.
      if(!any)
        {
         if(mql5_dow==0 /*dimanche*/ || mql5_dow==6 /*samedi*/)
            return false;
         return true;
        }
      return false;
     }

   void LogStateIfChanged(const datetime now, const string symbol)
     {
      const bool allow = AllowTrade(now, symbol);
      const bool close = ShouldClosePositions(now, symbol);
      const int ia = allow ? 1 : 0;
      const int ic = close ? 1 : 0;
      if(ia != m_last_allow || ic != m_last_close)
        {
         m_last_allow = ia; m_last_close = ic;
         if(CAuroraLogger::IsEnabled(AURORA_LOG_SESSION))
           {
            MqlDateTime dt; TimeToStruct(now, dt);
            CAuroraLogger::InfoSession(StringFormat(
              "State change [%s] %02d:%02d allow=%s close=%s",
              symbol, dt.hour, dt.min, allow?"true":"false", close?"true":"false"));
           }
        }
     }

public:
   CAuroraSessionManager()
     {
      ArrayInitialize(m_trade_day, false);
      m_enable_time=false; m_start_hour=0; m_start_min=0; m_end_hour=23; m_end_min=59;
      m_close_outside=false; m_close_restricted=false; m_respect_broker=true;
      m_last_allow=-1; m_last_close=-1;
     }

   void Configure(const SSessionInputs &in)
     {
      m_trade_day[0] = in.trade_mon;
      m_trade_day[1] = in.trade_tue;
      m_trade_day[2] = in.trade_wed;
      m_trade_day[3] = in.trade_thu;
      m_trade_day[4] = in.trade_fri;
      m_trade_day[5] = in.trade_sat;
      m_trade_day[6] = in.trade_sun;
      m_enable_time  = in.enable_time_window;
      m_start_hour   = ClampI(in.start_hour, 0, 23);
      m_start_min    = ClampI(in.start_min,  0, 59);
      m_end_hour     = ClampI(in.end_hour,   0, 23);
      m_end_min      = ClampI(in.end_min,    0, 59);
      m_close_outside= in.close_outside;
      m_close_restricted = in.close_restricted_days;
      m_respect_broker   = in.respect_broker_sessions;
      m_last_allow=-1; m_last_close=-1; // reset transition log
     }

   bool AllowTrade(const datetime now, const string symbol)
     {
      if(!IsDayAllowed(now)) return false;
      if(!IsWithinTimeWindow(now)) return false;
      if(!InAnyBrokerTradingSession(now, symbol)) return false;
      return true;
     }

   bool ShouldClosePositions(const datetime now, const string symbol)
     {
      if(m_close_restricted && !IsDayAllowed(now)) return true;
      if(m_close_outside && !IsWithinTimeWindow(now)) return true;
      if(m_respect_broker && !InAnyBrokerTradingSession(now, symbol)) return true;
      return false;
     }

   void LogState(const datetime now, const string symbol)
     {
      LogStateIfChanged(now, symbol);
     }
  };

#endif // __AURORA_SESSION_MANAGER_MQH__
