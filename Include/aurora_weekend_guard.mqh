//+------------------------------------------------------------------+
//|                                             Aurora Weekend Guard |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict
#property version   "1.2"

#ifndef __AURORA_WEEKEND_GUARD_MQH__
#define __AURORA_WEEKEND_GUARD_MQH__

#include <aurora_logger.mqh>
#include <aurora_time_helper.mqh>

#define AURORA_WEEKEND_GUARD_VERSION "1.2"

struct SWeekendInputs
  {
   bool enable;
   int  buffer_min;   // minutes avant la fermeture de session
   int  gap_min_hours; // gap minimal (heures) pour activer le garde
   int  block_before_min; // minutes avant close pour bloquer les entrées
   bool close_pendings; // fermer les ordres en attente
  };

class CAuroraWeekendGuard
  {
private:
   bool m_enable;
   int  m_buffer_min;
   int  m_gap_min_hours;
   int  m_block_before_min;
   bool m_close_pendings;

   static int MinutesOfDay(const datetime t)  { return AuroraTimeHelper::MinutesOfDay(t); }
   static int MinutesOfWeek(const datetime t) { return AuroraTimeHelper::MinutesOfWeek(t); }

   bool BuildSessionsNextDays(const string symbol,
                              const datetime now,
                              int &count,
                              int &from_min_week[],
                              int &to_min_week[],
                              const int max_items,
                              bool &any)
     {
      count = 0; any=false;
      MqlDateTime dtnow; TimeToStruct(now, dtnow);
      for(int d=0; d<4 && count<max_items; ++d)
        {
         int day = (dtnow.day_of_week + d) % 7; // 0=dimanche … 6=samedi
         for(int i=0; i<10 && count<max_items; ++i)
           {
            datetime from=0, to=0;
            if(!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)day, i, from, to))
               break;
            any=true;
            int f = (int)((from % 86400) / 60);
            int t = (int)((to   % 86400) / 60);
            int base = day*1440;
            if(f <= t)
              {
               from_min_week[count] = base + f;
               to_min_week[count]   = base + t;
               ++count;
              }
            else
              {
               // overnight → basculer to au jour suivant
               from_min_week[count] = base + f;
               to_min_week[count]   = base + 1440 + t;
               ++count;
              }
           }
        }
      return (count>0);
     }

   bool ComputeGapAndTimeToClose(const datetime now,
                                 const string symbol,
                                 int &gap_min,
                                 int &time_to_close_min)
     {
      const int MAX_ITEMS = 48;
      // Optimization 🟠: Static arrays to prevent repetitive reallocation
      static int farr[]; 
      static int tarr[]; 
      if(ArraySize(farr) != MAX_ITEMS) { ArrayResize(farr, MAX_ITEMS); ArrayResize(tarr, MAX_ITEMS); }
      int n=0; bool any=false;
      if(!BuildSessionsNextDays(symbol, now, n, farr, tarr, MAX_ITEMS, any))
        return false;

      const int now_w = MinutesOfWeek(now);
      // trouver la première session dont la fin est >= maintenant
      int idx = -1;
      for(int i=0; i<n; ++i)
        {
         if(now_w <= tarr[i]) { idx=i; break; }
        }
      if(idx<0) return false; // aucune fin de session visible dans la fenêtre scannée

      // déterminer la fin courante et la prochaine ouverture
      const int cur_to = tarr[idx];
      int next_from = -1;
      if(idx+1 < n) next_from = farr[idx+1];
      else next_from = cur_to + 100000; // très grand écart

      gap_min = next_from - cur_to;
      time_to_close_min = cur_to - now_w;
      return true;
     }

public:
   CAuroraWeekendGuard(): m_enable(false), m_buffer_min(30), m_gap_min_hours(2), m_block_before_min(30), m_close_pendings(true) {}

   void Configure(const SWeekendInputs &in)
     {
      m_enable = in.enable;
      m_buffer_min = (in.buffer_min<1 ? 1 : in.buffer_min);
      m_gap_min_hours = (in.gap_min_hours<1?1:in.gap_min_hours);
      m_block_before_min = (in.block_before_min<1?1:in.block_before_min);
      m_close_pendings = in.close_pendings;
     }

   bool ShouldCloseSoon(const datetime now, const string symbol)
     {
      if(!m_enable) return false;
      int gap_min=0, ttc_min=0;
      if(!ComputeGapAndTimeToClose(now, symbol, gap_min, ttc_min)) return false;
      const int gap_thr = m_gap_min_hours*60;
      if(gap_min >= gap_thr && ttc_min >= 0 && ttc_min <= m_buffer_min)
        {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_SESSION))
            CAuroraLogger::InfoSession(StringFormat("[WeekendGuard] gap=%dmin ttc=%dmin — close soon", gap_min, ttc_min));
         return true;
        }
      return false;
     }

  bool BlockEntriesNow(const datetime now, const string symbol)
     {
      int gap_min=0, ttc_min=0;
      if(!ComputeGapAndTimeToClose(now, symbol, gap_min, ttc_min)) return false;
      const int gap_thr = m_gap_min_hours*60;
      if(gap_min >= gap_thr && ttc_min >= 0 && ttc_min <= m_block_before_min)
        return true;
      return false;
     }

   bool ClosePendingsEnabled() const { return m_close_pendings; }
  };

#endif // __AURORA_WEEKEND_GUARD_MQH__
