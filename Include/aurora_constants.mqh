//+------------------------------------------------------------------+
//| Aurora Constants (shared magic numbers)                          |
//| Version: 1.0                                                     |
//+------------------------------------------------------------------+
#property strict

#ifndef __AURORA_CONSTANTS_MQH__
#define __AURORA_CONSTANTS_MQH__

#define AURORA_CONSTANTS_VERSION "1.0"

// Taille standard des buffers CopyBuffer (HA/CE/ZL)
#define AURORA_BUFF_SIZE                4

// Délai minimum pour EventSetTimer (en secondes)
#define AURORA_TIMER_MIN_SEC            5

// Durée minimale pour le flag HoldAllowed des news strictes (en secondes)
#define AURORA_NEWS_STRICT_HOLD_SEC     120

#endif // __AURORA_CONSTANTS_MQH__
