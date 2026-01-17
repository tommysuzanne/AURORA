//+------------------------------------------------------------------+
//|                                                 Aurora Constants |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property version   "1.0"
#property strict

#ifndef __AURORA_CONSTANTS_MQH__
#define __AURORA_CONSTANTS_MQH__

#define AURORA_CONSTANTS_VERSION "1.0"

// Taille standard des buffers CopyBuffer (HA/CE/ZL)
#define AURORA_BUFF_SIZE                4

// Délai minimum pour EventSetTimer (en secondes)
#define AURORA_TIMER_MIN_SEC            1

// Durée minimale pour le flag HoldAllowed des news strictes (en secondes)
#define AURORA_NEWS_STRICT_HOLD_SEC     120

#endif // __AURORA_CONSTANTS_MQH__
