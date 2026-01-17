//+------------------------------------------------------------------+
//|                                               Aurora Time Helper |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property version   "1.0"
#property strict

#ifndef __AURORA_TIME_HELPER_MQH__
#define __AURORA_TIME_HELPER_MQH__

#define AURORA_TIME_HELPER_VERSION "1.0"

namespace AuroraTimeHelper
{
  // retourne 0=lundi … 6=dimanche
  inline int DayIndexMondayZero(const datetime t)
  {
    MqlDateTime dt; TimeToStruct(t, dt);
    return ((dt.day_of_week + 6) % 7);
  }

  inline int MinutesOfDay(const datetime t)
  {
    MqlDateTime dt; TimeToStruct(t, dt);
    return dt.hour*60 + dt.min;
  }

  inline int MinutesOfWeek(const datetime t)
  {
    MqlDateTime dt; TimeToStruct(t, dt);
    return dt.day_of_week*1440 + dt.hour*60 + dt.min;
  }
}

#endif // __AURORA_TIME_HELPER_MQH__

