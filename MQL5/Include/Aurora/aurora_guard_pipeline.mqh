//+------------------------------------------------------------------+
//|                                            Aurora Guard Pipeline |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_GUARD_PIPELINE_MQH__
#define __AURORA_GUARD_PIPELINE_MQH__

#include <Aurora/aurora_constants.mqh>
#include <Aurora/aurora_logger.mqh>
#include <Aurora/aurora_session_manager.mqh>
#include <Aurora/aurora_weekend_guard.mqh>
#include <Aurora/aurora_newsfilter.mqh>


namespace AuroraGuards
{

inline bool ProcessTimer(CAuroraSessionManager &session,
                         CAuroraWeekendGuard &weekend,
                         CAuroraNewsFilter &newsF,
                         GerEA &eaRef,
                         const string symbol,
                         const datetime now,
                         const ENUM_NEWS_ACTION newsAction,
                         const int slippage)
  {
   const uint t0 = GetTickCount();

   if(weekend.ShouldCloseSoon(now, symbol))
     {
      eaRef.BuyClose();
      eaRef.SellClose();
      if(weekend.ClosePendingsEnabled())
         eaRef.ClosePendingsForSymbol(symbol);
      if(CAuroraLogger::IsEnabled(AURORA_LOG_PIPELINE)) CAuroraLogger::InfoPipe("[WEEKEND] close soon");
      return false;
     }

   double profit = eaRef.GetTotalProfit(symbol);
   bool allowSess = session.AllowTrade(now, symbol);
   bool closeSess = session.ShouldClosePositions(now, symbol, profit);
   session.LogState(now, symbol);
   if(closeSess)
     {
      eaRef.BuyClose();
      eaRef.SellClose();
     }
   
   if(!allowSess)
     {
      // FIX: Use Absolute Target Persistence
      double curVol = eaRef.GetTotalVolume(symbol); // Need to ensure this helper exists or compute it
      double absTarget = session.GetDeleverageAbsTarget(now, symbol, eaRef.GetMagic(), curVol);
      if(absTarget >= 0.0)
        {
         eaRef.DeleveragePositionsToTarget(symbol, absTarget);
        }
      eaRef.ClosePendingsForSymbol(symbol);

         if(CAuroraLogger::IsEnabled(AURORA_LOG_PIPELINE)) CAuroraLogger::InfoPipe("[SESSION] not allowed");
         return false;
     }

   newsF.OnTimer();

   string freezeTitle="", freezeCurrency="";
   const bool freeze = newsF.FreezeNow(now, freezeTitle, freezeCurrency);
   if(freeze)
     {
       if(newsAction == NEWS_ACTION_BLOCK_ALL_CLOSE)
        {
         string closeTitle="", closeCurrency="";
         if(newsF.ShouldCloseNow(now, closeTitle, closeCurrency))
           {
            eaRef.BuyClose();
            eaRef.SellClose();
           }
        }
       if(newsAction != NEWS_ACTION_MONITOR_ONLY)
          eaRef.ClosePendingsForSymbol(symbol);
       // Fix: Allow continuation if Monitor Only / Block Entries
       if(newsAction != NEWS_ACTION_MONITOR_ONLY && newsAction != NEWS_ACTION_BLOCK_ENTRIES)
          return false;
     }

   if(CAuroraLogger::IsEnabled(AURORA_LOG_PIPELINE))
     {
      const uint dt = GetTickCount() - t0;
      CAuroraLogger::InfoPipe(StringFormat("[TIMER] done in %ums", (unsigned int)dt));
     }

   return true;
  }

  inline bool ProcessTick(CAuroraSessionManager &session,
                        CAuroraWeekendGuard &weekend,
                        CAuroraNewsFilter &newsF,
                        GerEA &eaRef,
                        const string symbol,
                        const datetime now,
                        const ENUM_NEWS_ACTION newsAction,
                        bool &outAllowEntry,
                        bool &outAllowManage,
                        bool &outPurgePending) 
  {
   outAllowEntry = true;
   outAllowManage = true;
   outPurgePending = false;

   // SESSION MANAGEMENT
   // 1. Check Close / Smart Exit
   double profit = eaRef.GetTotalProfit(symbol);
   if(session.ShouldClosePositions(now, symbol, profit))
     {
      eaRef.BuyClose();
      eaRef.SellClose();
      outAllowEntry = false;
      outAllowManage = false;
      outPurgePending = true;
      return false; // Full Stop
     }

   // 2. Check Deleverage
   // FIX: Use Absolute Target Persistence (Copy of Timer Logic)
   if(session.ShouldDeleverage(now))
     {
      double curVol = eaRef.GetTotalVolume(symbol); 
      double absTarget = session.GetDeleverageAbsTarget(now, symbol, eaRef.GetMagic(), curVol);
      if(absTarget >= 0.0)
        {
         eaRef.DeleveragePositionsToTarget(symbol, absTarget);
        }
     }

   // 3. Check Permissions (Entry vs Grid)
   if(!session.AllowTrade(now, symbol))
     {
      // Outside Session
      // OFF / FORCE CLOSE (remaining) / RESTRICTED
      outAllowEntry = false;
      outPurgePending = true;
      return false;
     }

   // WEEKEND GUARD
   if(weekend.BlockEntriesNow(now, symbol))
     {
      outAllowEntry = false;
      outPurgePending = weekend.ClosePendingsEnabled();
      return false;
     }

   // NEWS GUARD
   string freezeTitle="", freezeCurrency="";
   if(newsF.FreezeNow(now, freezeTitle, freezeCurrency))
     {
      if(newsAction == NEWS_ACTION_BLOCK_ALL_CLOSE)
        {
         string closeTitle="", closeCurrency="";
         if(newsF.ShouldCloseNow(now, closeTitle, closeCurrency))
           {
            eaRef.BuyClose();
            eaRef.SellClose();
           }
        }

      if(newsAction == NEWS_ACTION_MONITOR_ONLY)
         return true;

      outAllowEntry = false;
      outPurgePending = true;

      if(newsAction == NEWS_ACTION_BLOCK_MANAGE || newsAction == NEWS_ACTION_BLOCK_ALL_CLOSE)
         outAllowManage = false;
      return false;
     }

   return true;
  }
}

#endif // __AURORA_GUARD_PIPELINE_MQH__
