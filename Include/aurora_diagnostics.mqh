//+------------------------------------------------------------------+
//| Aurora Diagnostics (OnTester JSON dump)                         |
//| Version: 1.0                                                    |
//+------------------------------------------------------------------+
#property strict

#ifndef __AURORA_DIAGNOSTICS_MQH__
#define __AURORA_DIAGNOSTICS_MQH__

#include "aurora_logger.mqh"

inline void DumpOnTesterJSON(const string symbol,
                             const int ftmo_mode,
                             const datetime day_anchor_ts,
                             const double day_anchor_balance,
                             const int day_resets,
                             const int mdl_hits,
                             const int total_hits,
                             const int pretrade_vetos,
                             const int news_suspend,
                             const int weekend_preclose)
{
  string fname = StringFormat("AURORA_Diag_%s_%s.json", symbol, TimeToString(TimeCurrent(), TIME_DATE));
  int h = FileOpen(fname, FILE_WRITE|FILE_COMMON|FILE_ANSI);
  if(h==INVALID_HANDLE)
  {
    if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
      CAuroraLogger::WarnGeneral(StringFormat("[DIAG] FileOpen fail %s", fname));
    return;
  }
  string json = "{"+
    StringFormat("\"symbol\":\"%s\",", symbol)+
    StringFormat("\"ftmo_mode\":%d,", ftmo_mode)+
    StringFormat("\"day_anchor_ts\":%I64d,", (long)day_anchor_ts)+
    StringFormat("\"day_anchor_balance\":%.2f,", day_anchor_balance)+
    StringFormat("\"day_resets\":%d,", day_resets)+
    StringFormat("\"mdl_hits\":%d,", mdl_hits)+
    StringFormat("\"total_hits\":%d,", total_hits)+
    StringFormat("\"pretrade_vetos\":%d,", pretrade_vetos)+
    StringFormat("\"news_suspend\":%d,", news_suspend)+
    StringFormat("\"weekend_preclose\":%d", weekend_preclose)+
  "}";
  FileWriteString(h, json+"\n");
  FileClose(h);
}

#endif // __AURORA_DIAGNOSTICS_MQH__

