//+------------------------------------------------------------------+
//| Aurora Order Closer                                             |
//| Version: 1.0                                                    |
//+------------------------------------------------------------------+
#property strict

#ifndef __AURORA_ORDER_CLOSER_MQH__
#define __AURORA_ORDER_CLOSER_MQH__

#include "aurora_logger.mqh"

namespace AuroraOrderCloser
{
  inline bool ClosePositionByTicket(GerEA &eaRef, const ulong ticket)
  {
    if(ticket==0) return false;
    return eaRef.PosClose(ticket);
  }

  inline void CloseAllPositionsForSymbol(GerEA &eaRef, const string symbol)
  {
    int total = PositionsTotal();
    for(int i = total - 1; i >= 0; --i)
    {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(!ClosePositionByTicket(eaRef, ticket))
      {
        const int err = GetLastError();
        if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
          CAuroraLogger::WarnOrders(StringFormat("[CLOSE] ticket=%I64u error #%d", ticket, err));
      }
    }
  }

  inline void ClosePendingsForSymbol(GerEA &eaRef, const string symbol)
  {
    int total = OrdersTotal();
    for(int i = total - 1; i >= 0; --i)
    {
      ulong ticket = OrderGetTicket(i);
      if(ticket==0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != eaRef.GetMagic()) continue;
      ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(otype==ORDER_TYPE_BUY_LIMIT || otype==ORDER_TYPE_SELL_LIMIT ||
         otype==ORDER_TYPE_BUY_STOP || otype==ORDER_TYPE_SELL_STOP ||
         otype==ORDER_TYPE_BUY_STOP_LIMIT || otype==ORDER_TYPE_SELL_STOP_LIMIT)
      {
        MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
        rq.action = TRADE_ACTION_REMOVE; rq.order = ticket; rq.symbol = symbol; rq.magic = eaRef.GetMagic();
        if(!OrderSend(rq, rs))
        {
          int err = GetLastError();
          if(CAuroraLogger::IsEnabled(AURORA_LOG_ORDERS))
            CAuroraLogger::WarnOrders(StringFormat("[CLOSE-PEND] remove #%I64u error %d", ticket, err));
        }
      }
    }
  }
}

#endif // __AURORA_ORDER_CLOSER_MQH__
