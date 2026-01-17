//+------------------------------------------------------------------+
//|                                             Aurora Async Structs |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_ASYNC_STRUCTS_MQH__
#define __AURORA_ASYNC_STRUCTS_MQH__

struct SAsyncRequest {
    uint request_id;
    MqlTradeRequest req;
    int retries;
    datetime timestamp;
};

#endif // __AURORA_ASYNC_STRUCTS_MQH__
