//+------------------------------------------------------------------+
//| Aurora Guard Pipeline — Sessions / Weekend / News / FTMO         |
//| Version: 1.1                                                     |
//+------------------------------------------------------------------+
#property strict

#ifndef __AURORA_GUARD_PIPELINE_MQH__
#define __AURORA_GUARD_PIPELINE_MQH__

#include "aurora_constants.mqh"
#include "aurora_logger.mqh"
#include "aurora_session_manager.mqh"
#include "aurora_weekend_guard.mqh"
#include "aurora_newsfilter.mqh"
#include "aurora_ftmo_news_strict.mqh"
#include "aurora_ftmo_guard.mqh"
#include "aurora_order_closer.mqh"

namespace AuroraGuards
{
// Pendings: utilise le helper dédié

inline void ClosePositionsBeforeEvent(GerEA &eaRef,
                                      const string symbol,
                                      const bool holdAllowed,
                                      const datetime eventTime,
                                      const int slippage)
  {
   const int hold_sec = AURORA_NEWS_STRICT_HOLD_SEC;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if((ulong)PositionGetInteger(POSITION_MAGIC) != eaRef.GetMagic()) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      datetime tOpen = (datetime)PositionGetInteger(POSITION_TIME);
      if(holdAllowed && (tOpen <= eventTime - hold_sec)) continue;
      if(!AuroraOrderCloser::ClosePositionByTicket(eaRef, ticket))
        {
         int err = GetLastError();
         if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
            CAuroraLogger::WarnOrders(StringFormat("[NewsStrict] CloseBefore ticket=%I64u error #%d : %s", ticket, err, ErrorDescription(err)));
        }
     }
  }

inline bool ProcessTimer(CAuroraSessionManager &session,
                         CAuroraWeekendGuard &weekend,
                         CAuroraNewsFilter &newsF,
                         CAuroraFtmoNewsStrict &ftmoNews,
                         CAuroraFtmoGuard &ftmoGuard,
                         GerEA &eaRef,
                         const string symbol,
                         const datetime now,
                         const ENUM_NEWS_ACTION newsAction,
                         const bool newsStrictHoldAllowed,
                         const bool newsStrictCloseBefore,
                         const int slippage,
                         int &ctrWeekendClose,
                         int &ctrNewsSuspend)
  {
   const uint t0 = GetTickCount();
   ftmoGuard.ResetEntriesBlock();

   if(weekend.ShouldCloseSoon(now, symbol))
     {
      eaRef.BuyClose();
      eaRef.SellClose();
      ctrWeekendClose++;
      if(weekend.ClosePendingsEnabled())
         AuroraOrderCloser::ClosePendingsForSymbol(eaRef, symbol);
      if(CAuroraLogger::IsEnabled(AURORA_LOG_PIPELINE)) CAuroraLogger::InfoPipe("[WEEKEND] close soon");
      return false;
     }

   bool allowSess = session.AllowTrade(now, symbol);
   bool closeSess = session.ShouldClosePositions(now, symbol);
   session.LogState(now, symbol);
   if(closeSess)
     {
      eaRef.BuyClose();
      eaRef.SellClose();
     }
   if(!allowSess)
     {
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
      if(newsAction != NEWS_ACTION_BLOCK_ENTRIES)
         return false;
     }

   if(ftmoNews.SuspendManageNow(now))
     {
      if(newsStrictCloseBefore)
        {
         bool doClose=false; datetime evtime=0; string etitle="", eccy="";
         if(ftmoNews.CloseBeforeNow(now, doClose, evtime, etitle, eccy) && doClose)
            ClosePositionsBeforeEvent(eaRef, symbol, newsStrictHoldAllowed, evtime, slippage);
        }
      ctrNewsSuspend++;
      return false;
     }

   bool warn=false, hard_close=false, block=false;
   const double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   const double ba = AccountInfoDouble(ACCOUNT_BALANCE);
   ftmoGuard.CheckDaily(eq, ba, warn, hard_close, block);
   ftmoGuard.CheckTotal(eq, warn, hard_close, block);
   if(hard_close)
     {
      eaRef.BuyClose();
      eaRef.SellClose();
      return false;
     }

   if(CAuroraLogger::IsEnabled(AURORA_LOG_PIPELINE))
     {
      const uint dt = GetTickCount() - t0;
      CAuroraLogger::InfoPipe(StringFormat("[TIMER] done in %ums block_entries=%s", (unsigned int)dt, (ftmoGuard.EntriesBlocked()?"true":"false")));
     }

   return true;
  }

inline bool ProcessTick(CAuroraSessionManager &session,
                        CAuroraWeekendGuard &weekend,
                        CAuroraNewsFilter &newsF,
                        CAuroraFtmoNewsStrict &ftmoNews,
                        CAuroraFtmoGuard &ftmoGuard,
                        GerEA &eaRef,
                        const string symbol,
                        const datetime now,
                        const ENUM_NEWS_ACTION newsAction)
  {
   if(!session.AllowTrade(now, symbol))
     {
      if(session.ShouldClosePositions(now, symbol))
        {
         eaRef.BuyClose();
         eaRef.SellClose();
        }
      return false;
     }

   if(weekend.BlockEntriesNow(now, symbol))
      return false;

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
      return false;
     }

   string strictTitle="", strictCcy="";
   if(ftmoNews.InStrictWindow(now, strictTitle, strictCcy))
      return false;

   if(ftmoGuard.EntriesBlocked())
      return false;

   return true;
  }
}

#endif // __AURORA_GUARD_PIPELINE_MQH__
