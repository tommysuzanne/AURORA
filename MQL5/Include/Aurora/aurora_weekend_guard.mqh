//+------------------------------------------------------------------+
//|                                             Aurora Weekend Guard |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_WEEKEND_GUARD_MQH__
#define __AURORA_WEEKEND_GUARD_MQH__

#include <Aurora/aurora_logger.mqh>
#include <Aurora/aurora_types.mqh>

#define AURORA_WEEKEND_GUARD_VERSION "1.3"

namespace AuroraWeekendMath
{
   inline bool ComputeGapAndTimeToClose(const datetime now,
                                        const datetime &from_ts[],
                                        const datetime &to_ts[],
                                        const int count,
                                        int &gap_min,
                                        int &time_to_close_min)
     {
      gap_min = 0;
      time_to_close_min = 0;
      if(count <= 0) return false;

      int idx = -1;
      for(int i=0; i<count; ++i)
        {
         if(now <= to_ts[i]) { idx = i; break; }
        }
      if(idx < 0) return false;

      const datetime cur_to = to_ts[idx];
      datetime next_from = (idx + 1 < count) ? from_ts[idx + 1] : (cur_to + 7 * 86400);

      if(next_from < cur_to) next_from = cur_to;

      gap_min = (int)((next_from - cur_to) / 60);
      time_to_close_min = (int)((cur_to - now) / 60);
      if(gap_min < 0) gap_min = 0;
      return true;
     }
}

class CAuroraWeekendGuard
  {
private:
   bool m_enable;
   int  m_buffer_min;
   int  m_gap_min_hours;
   int  m_block_before_min;
   bool m_close_pendings;

   bool BuildSessionsNextDays(const string symbol,
                              const datetime now,
                              int &count,
                              datetime &from_ts[],
                              datetime &to_ts[],
                              const int max_items,
                              bool &any)
     {
      count = 0; any=false;
      for(int d=-1; d<5 && count<max_items; ++d)
        {
         const datetime ref_time = now + d * 86400;
         MqlDateTime dref;
         TimeToStruct(ref_time, dref);
         dref.hour = 0;
         dref.min = 0;
         dref.sec = 0;
         const datetime day_start = StructToTime(dref);
         const ENUM_DAY_OF_WEEK day = (ENUM_DAY_OF_WEEK)dref.day_of_week;

         for(int i=0; i<10 && count<max_items; ++i)
           {
            datetime from=0, to=0;
            if(!SymbolInfoSessionTrade(symbol, day, i, from, to))
               break;

            any=true;
            const int from_sec = (int)(from % 86400);
            const int to_sec = (int)(to % 86400);

            datetime abs_from = day_start + from_sec;
            datetime abs_to = day_start + to_sec;
            if(to_sec < from_sec) abs_to += 86400; // overnight

            if(abs_to < (now - 86400)) continue;

            from_ts[count] = abs_from;
            to_ts[count] = abs_to;
            ++count;
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
      // Static arrays to avoid repetitive reallocation
      static datetime farr[];
      static datetime tarr[];
      if(ArraySize(farr) != MAX_ITEMS) { ArrayResize(farr, MAX_ITEMS); ArrayResize(tarr, MAX_ITEMS); }
      int n=0; bool any=false;
      if(!BuildSessionsNextDays(symbol, now, n, farr, tarr, MAX_ITEMS, any))
        return false;
      return AuroraWeekendMath::ComputeGapAndTimeToClose(now, farr, tarr, n, gap_min, time_to_close_min);
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
	            CAuroraLogger::InfoSession(StringFormat("[WEEKEND][GUARD] gap_min=%d ttc_min=%d action=close-soon", gap_min, ttc_min));
	         return true;
	        }
      return false;
     }

  bool BlockEntriesNow(const datetime now, const string symbol)
     {
      if(!m_enable) return false;
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
