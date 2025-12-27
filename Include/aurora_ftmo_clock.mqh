//+------------------------------------------------------------------+
//| Aurora FTMO Clock — Ancre Prague (CE(S)T)                        |
//| Version: 1.0                                                     |
//+------------------------------------------------------------------+
#property strict

#ifndef __AURORA_FTMO_CLOCK_MQH__
#define __AURORA_FTMO_CLOCK_MQH__

#include "aurora_logger.mqh"

#define AURORA_FTMO_CLOCK_VERSION "1.0"

class CAuroraFtmoClock
  {
private:
   bool     m_auto_prague;
   int      m_fallback_hh;
   int      m_fallback_mm;
   int      m_last_prague_ymd;  // yyyymmdd (jour courant Prague)
   datetime m_last_anchor_ts;   // timestamp local au moment du reset

   static bool IsDstEu(const datetime t_gmt)
     {
      MqlDateTime dt; TimeToStruct(t_gmt, dt);
      const int y = dt.year;
      // Dernier dimanche de mars, 01:00 UTC
      datetime dst_start = LastSundayOfMonthUtc(y, 3) + 3600; // 01:00 UTC
      // Dernier dimanche d'octobre, 01:00 UTC
      datetime dst_end   = LastSundayOfMonthUtc(y, 10) + 3600; // 01:00 UTC
      return (t_gmt >= dst_start && t_gmt < dst_end);
     }

   static datetime LastSundayOfMonthUtc(const int year, const int month)
     {
      // Construire le dernier jour du mois, reculer jusqu'au dimanche
      int days = DaysInMonth(year, month);
      MqlDateTime dt = {};
      dt.year = year; dt.mon = month; dt.day = days; dt.hour=0; dt.min=0; dt.sec=0;
      datetime t = StructToTime(dt);
      for(int i=0;i<7;i++)
        {
         MqlDateTime dtt; TimeToStruct(t, dtt);
         if(dtt.day_of_week == 0) return t; // 0=dimanche
         t -= 86400;
        }
      return t;
     }

   static int DaysInMonth(const int year, const int month)
     {
      switch(month)
        {
         case 1: case 3: case 5: case 7: case 8: case 10: case 12: return 31;
         case 4: case 6: case 9: case 11: return 30;
         case 2: return ( ((year%4==0) && (year%100!=0)) || (year%400==0) ) ? 29 : 28;
        }
      return 30;
     }

   static void PragueDateYMD(const datetime now_gmt, int &out_ymd)
     {
      // CET=UTC+1, CEST=UTC+2
      const bool dst = IsDstEu(now_gmt);
      const int offset = dst ? 7200 : 3600;
      datetime prague = now_gmt + offset;
      MqlDateTime dt; TimeToStruct(prague, dt);
      out_ymd = dt.year*10000 + dt.mon*100 + dt.day;
     }

public:
   CAuroraFtmoClock(): m_auto_prague(true), m_fallback_hh(0), m_fallback_mm(0), m_last_prague_ymd(0), m_last_anchor_ts(0) {}

   void Configure(const bool auto_prague, const int hh, const int mm)
     {
      m_auto_prague = auto_prague;
      m_fallback_hh = (hh<0?0:(hh>23?23:hh));
      m_fallback_mm = (mm<0?0:(mm>59?59:mm));
     }

   void InitAnchorsOnInit()
     {
      // Initialise le cache du jour Prague courant
      if(m_auto_prague)
        {
         int ymd=0; PragueDateYMD(TimeGMT(), ymd);
         m_last_prague_ymd = ymd;
        }
      else
        {
         // Mode fallback: utiliser le jour serveur mais reset à HH:MM
         MqlDateTime s; TimeToStruct(TimeTradeServer(), s);
         m_last_prague_ymd = s.year*10000 + s.mon*100 + s.day;
        }
      m_last_anchor_ts = TimeTradeServer();
     }

   bool PragueMidnightChanged(const datetime now_server, datetime &out_day_anchor_ts)
     {
      if(m_auto_prague)
        {
         int ymd=0; PragueDateYMD(TimeGMT(), ymd);
         if(ymd != m_last_prague_ymd)
           {
            m_last_prague_ymd = ymd;
            m_last_anchor_ts = now_server;
            out_day_anchor_ts = m_last_anchor_ts;
            if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::InfoFtmo("[CLOCK] Reset minuit Prague");
            return true;
           }
         out_day_anchor_ts = m_last_anchor_ts;
         return false;
        }
      else
        {
         // Reset sur horloge serveur HH:MM
         static int last_day = -1;
         MqlDateTime dt; TimeToStruct(now_server, dt);
         const int day = dt.year*10000 + dt.mon*100 + dt.day;
         if(day != last_day && dt.hour==m_fallback_hh && dt.min==m_fallback_mm)
           {
            last_day = day;
            m_last_prague_ymd = day;
            m_last_anchor_ts = now_server;
            out_day_anchor_ts = m_last_anchor_ts;
            if(CAuroraLogger::IsEnabled(AURORA_LOG_FTMO)) CAuroraLogger::InfoFtmo("[CLOCK] Reset minuit (fallback serveur)");
            return true;
           }
         out_day_anchor_ts = m_last_anchor_ts;
         return false;
        }
     }

   datetime LastAnchorTs() const { return m_last_anchor_ts; }
  };

#endif // __AURORA_FTMO_CLOCK_MQH__

