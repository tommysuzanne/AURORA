//+------------------------------------------------------------------+
//|                                             aurora_trade_contract |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_TRADE_CONTRACT_MQH__
#define __AURORA_TRADE_CONTRACT_MQH__

#include <Aurora/aurora_types.mqh>

// Shared execution helpers exported by aurora_engine.mqh.
double NormalizePriceDown(double price, string symbol);
double NormalizePriceUp(double price, string symbol);
int MinBrokerPoints(const string symbol);
ENUM_ORDER_TYPE_FILLING SelectFilling(const string symbol, ENUM_FILLING preferred);
bool FixFillingByOrderCheck(MqlTradeRequest &req, const ENUM_FILLING preferred, MqlTradeCheckResult &ioCheck);
bool order(ENUM_ORDER_TYPE ot,
           ulong magic,
           double in,
           double sl,
           double tp,
           double risk,
           int slippage,
           bool isl,
           bool itp,
           string comment,
           string name,
           double vol,
           ENUM_FILLING filling,
           ENUM_RISK risk_mode,
           double balanceOverride,
           double maxLotLimit,
           double maxTotalLots);

#endif // __AURORA_TRADE_CONTRACT_MQH__
