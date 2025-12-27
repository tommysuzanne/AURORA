//+------------------------------------------------------------------+
//| Aurora FTMO News Strict — Overlay 2/2 ciblé                      |
//| Version: 1.0                                                     |
//+------------------------------------------------------------------+
#property strict

#ifndef __AURORA_FTMO_NEWS_STRICT_MQH__
#define __AURORA_FTMO_NEWS_STRICT_MQH__

#include "aurora_news_core.mqh"
#include "aurora_logger.mqh"

#define AURORA_FTMO_NEWS_STRICT_VERSION "1.0"

struct SFtmoNewsStrictInputs
  {
   bool enable;
   int  before_sec;
   int  after_sec;
   bool targeted_only;
   bool hold_allowed;
   bool close_before;
   int  close_buffer_sec;
   bool suspend_manage;
   // Niveaux à appliquer (hérités des inputs News généraux)
   bool level_high;
   bool level_medium;
   bool level_low;
  };

class CAuroraFtmoNewsStrict
  {
private:
   SFtmoNewsStrictInputs m_in;
   CAuroraNewsCore       m_core;
   string                m_symbol;

   // Recherche l'événement strict le plus proche autour de now
   bool NextEventTime(const datetime now, datetime &out_evtime, string &out_title, string &out_ccy)
     {
      out_evtime=0; out_title=""; out_ccy="";
      if(!(m_in.enable && (m_in.level_high||m_in.level_medium||m_in.level_low))) return false;
      const int before_min = (int)MathMax(1.0, MathCeil((double)m_in.before_sec/60.0));
      const int after_min  = (int)MathMax(1.0, MathCeil((double)m_in.after_sec/60.0));
      const datetime from = now - before_min*60;
      const datetime to   = now + after_min*60;
      string cur_list = (m_in.targeted_only ? AutoCurrencies(m_symbol) : "");
      bool found=false; datetime best=0;
      if(cur_list!="")
        {
         int start=0; string cur;
         do {
            int pos = StringFind(cur_list, ",", start);
            cur = (pos==-1)? StringSubstr(cur_list, start): StringSubstr(cur_list, start, pos-start);
            if(cur!="")
              {
               MqlCalendarValue values[]; int total = CalendarValueHistory(values, from, to, NULL, cur);
               for(int i=0;i<total;++i)
                 {
                  MqlCalendarEvent ev; ZeroMemory(ev);
                  if(!CalendarEventById(values[i].event_id, ev)) continue;
                  ENUM_CALENDAR_EVENT_IMPORTANCE imp = ev.importance;
                  if( (imp==CALENDAR_IMPORTANCE_HIGH   && m_in.level_high)   ||
                      (imp==CALENDAR_IMPORTANCE_MODERATE&& m_in.level_medium) ||
                      (imp==CALENDAR_IMPORTANCE_LOW     && m_in.level_low) )
                    {
                     if(!found || MathAbs((long)values[i].time - (long)now) < MathAbs((long)best - (long)now))
                       { best=values[i].time; out_title=ev.name; out_ccy=cur; found=true; }
                    }
                 }
              }
            if(pos==-1) break; start=pos+1;
         } while(true);
        }
      else
        {
         MqlCalendarValue values[]; int total = CalendarValueHistory(values, from, to);
         for(int i=0;i<total;++i)
           {
            MqlCalendarEvent ev; ZeroMemory(ev);
            if(!CalendarEventById(values[i].event_id, ev)) continue;
            ENUM_CALENDAR_EVENT_IMPORTANCE imp = ev.importance;
            if( (imp==CALENDAR_IMPORTANCE_HIGH   && m_in.level_high)   ||
                (imp==CALENDAR_IMPORTANCE_MODERATE&& m_in.level_medium) ||
                (imp==CALENDAR_IMPORTANCE_LOW     && m_in.level_low) )
              {
               string ccy=""; MqlCalendarCountry co; ZeroMemory(co);
               if(CalendarCountryById(ev.country_id, co)) ccy = co.currency;
               if(!found || MathAbs((long)values[i].time - (long)now) < MathAbs((long)best - (long)now))
                 { best=values[i].time; out_title=ev.name; out_ccy=ccy; found=true; }
              }
           }
        }
      out_evtime = best;
      return found;
     }

   static string AutoCurrencies(const string symbol)
     {
      string base = SymbolInfoString(symbol, SYMBOL_CURRENCY_BASE);
      string profit = SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT);
      StringToUpper(base); StringToUpper(profit);
      if(base==profit) return base;
      if(base=="" && profit=="") return "";
      if(base=="") return profit;
      if(profit=="") return base;
      return base + "," + profit;
     }

public:
   CAuroraFtmoNewsStrict() { m_symbol = _Symbol; ZeroMemory(m_in); }

   void Configure(const SFtmoNewsStrictInputs &in)
     {
      m_in = in;
      m_symbol = _Symbol;
      const int before_min = (int)MathMax(1.0, MathCeil((double)m_in.before_sec/60.0));
      const int after_min  = (int)MathMax(1.0, MathCeil((double)m_in.after_sec/60.0));
      const string ccy = (m_in.targeted_only ? AutoCurrencies(m_symbol) : "");
      // rafraîchissement minimal 1 min
      m_core.Configure(m_in.enable && (m_in.level_high||m_in.level_medium||m_in.level_low),
                       m_in.level_high,
                       m_in.level_medium,
                       m_in.level_low,
                       ccy,
                       before_min,
                       after_min,
                       2,   // min_core_high_min (déjà garanti par 2/2s en secondes)
                       1,   // refresh minutes
                       CAuroraLogger::IsEnabled(AURORA_LOG_NEWS));
     }

   bool InStrictWindow(const datetime now,
                       string &out_title,
                       string &out_currency)
     {
      out_title = ""; out_currency="";
      if(!(m_in.enable && (m_in.level_high||m_in.level_medium||m_in.level_low))) return false;
      bool freeze = m_core.FreezeNow(now, out_title, out_currency);
      if(freeze && CAuroraLogger::IsEnabled(AURORA_LOG_FTMO))
        CAuroraLogger::InfoFtmo(StringFormat("[NEWS_STRICT] Freeze %s (%s)", out_title, out_currency));
      return freeze;
     }

   bool ShouldCloseBefore(const datetime now)
     {
      if(!m_in.enable) return false;
      return m_in.close_before; // décision d’exécution dans l’EA (avec buffer)
     }

   bool CloseBeforeNow(const datetime now,
                       bool &out_close,
                       datetime &out_evtime,
                       string &out_title,
                       string &out_ccy)
     {
      out_close=false; out_evtime=0; out_title=""; out_ccy="";
      if(!(m_in.enable && m_in.close_before)) return false;
      if(!InStrictWindow(now, out_title, out_ccy)) return false;
      datetime evtime=0; string t="", c="";
      if(!NextEventTime(now, evtime, t, c)) return false;
      int dt = (int)MathAbs((long)evtime - (long)now);
      if(dt <= m_in.close_buffer_sec)
        { out_close=true; out_evtime=evtime; if(out_title=="") out_title=t; if(out_ccy=="") out_ccy=c; return true; }
      out_evtime=evtime; return true;
     }

   bool SuspendManageNow(const datetime now)
     {
      if(!m_in.enable) return false;
      return m_in.suspend_manage;
     }
  };

#endif // __AURORA_FTMO_NEWS_STRICT_MQH__
