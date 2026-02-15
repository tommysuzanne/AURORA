//+------------------------------------------------------------------+
//|                                                    Aurora Time    |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_TIME_MQH__
#define __AURORA_TIME_MQH__

#define AURORA_TIME_VERSION "1.0"

namespace AuroraClock
{
  // Temporal contract:
  // 1) Prefer trade server clock when available.
  // 2) Fallback to terminal clock (tester/local).
  // 3) Last fallback to machine local time.
  inline datetime Now(const datetime candidate = 0)
  {
    if(candidate > 0) return candidate;
    datetime t = TimeTradeServer();
    if(t > 0) return t;
    t = TimeCurrent();
    if(t > 0) return t;
    return TimeLocal();
  }

  inline datetime DayStart(const datetime t)
  {
    MqlDateTime dt;
    TimeToStruct(t, dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    return StructToTime(dt);
  }

  inline int DayIndexMondayZero(const datetime t)
  {
    MqlDateTime dt;
    TimeToStruct(t, dt);
    return ((dt.day_of_week + 6) % 7);
  }

  inline int MinutesOfDay(const datetime t)
  {
    MqlDateTime dt;
    TimeToStruct(t, dt);
    return dt.hour * 60 + dt.min;
  }
}

#endif // __AURORA_TIME_MQH__
