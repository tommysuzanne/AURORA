//+------------------------------------------------------------------+
//|                                                    Aurora Logger |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_LOGGER_MQH__
#define __AURORA_LOGGER_MQH__

#define AURORA_LOGGER_VERSION "1.3"

enum AURORA_LOG_CATEGORY
  {
   AURORA_LOG_GENERAL = 0,
   AURORA_LOG_POSITION,
   AURORA_LOG_RISK,
   AURORA_LOG_SESSION,
   AURORA_LOG_NEWS,
   AURORA_LOG_SIMULATION,
   AURORA_LOG_STRATEGY,
   AURORA_LOG_ORDERS,
   AURORA_LOG_INVARIANT,
   AURORA_LOG_DIAGNOSTIC,
   AURORA_LOG_PIPELINE
  };

class CAuroraLogger
  {
private:
   static bool   m_general;
   static bool   m_position;
   static bool   m_risk;
   static bool   m_session;
   static bool   m_news;
   static bool   m_simulation;
   static bool   m_strategy;
   static bool   m_orders;
   static bool   m_invariant;
   static bool   m_diagnostic;
   static string m_prefix;

   static string CategoryName(const AURORA_LOG_CATEGORY category)
     {
      switch((int)category)
        {
         case AURORA_LOG_GENERAL:    return("GENERAL");
         case AURORA_LOG_POSITION:   return("POSITION");
         case AURORA_LOG_RISK:       return("RISK");
         case AURORA_LOG_SESSION:    return("SESSION");
         case AURORA_LOG_NEWS:       return("NEWS");
         case AURORA_LOG_SIMULATION: return("SIM");
         case AURORA_LOG_STRATEGY:   return("STRATEGY");
         case AURORA_LOG_ORDERS:     return("ORDERS");
         case AURORA_LOG_INVARIANT:  return("INVARIANT");
         case AURORA_LOG_DIAGNOSTIC: return("DIAG");
         case AURORA_LOG_PIPELINE:   return("PIPE");
        }
      return("UNKNOWN");
     }

   static bool Enabled(const AURORA_LOG_CATEGORY category)
     {
      switch((int)category)
        {
         case AURORA_LOG_GENERAL:    return(m_general);
         case AURORA_LOG_POSITION:   return(m_position);
         case AURORA_LOG_RISK:       return(m_risk);
         case AURORA_LOG_SESSION:    return(m_session);
         case AURORA_LOG_NEWS:       return(m_news);
         case AURORA_LOG_SIMULATION: return(m_simulation);
         case AURORA_LOG_STRATEGY:   return(m_strategy);
         case AURORA_LOG_ORDERS:     return(m_orders);
         case AURORA_LOG_INVARIANT:  return(m_invariant);
         case AURORA_LOG_DIAGNOSTIC: return(m_diagnostic);
         case AURORA_LOG_PIPELINE:   return(m_diagnostic || m_session); // pas de nouvel input — route via DIAG/SESSION
        }
      return(false);
     }

   static void PrintWithLevel(const string level,
                              const AURORA_LOG_CATEGORY category,
                              const string message)
     {
      const string prefix = (m_prefix == NULL || m_prefix == "") ? "" : (m_prefix + " ");
      PrintFormat("[AURORA][%s][%s] %s%s",
                  level,
                  CategoryName(category),
                  prefix,
                  message);
     }

public:
   // Quick check to avoid expensive formats
   static bool IsEnabled(const AURORA_LOG_CATEGORY category)
     {
      return Enabled(category);
     }

   static void Configure(const bool enable_general,
                         const bool enable_position,
                         const bool enable_risk,
                         const bool enable_session,
                         const bool enable_news,
                         const bool enable_simulation,
                         const bool enable_strategy,
                         const bool enable_orders,
                         const bool enable_diagnostic=false,
                         const bool enable_invariant=false)
     {
      m_general    = enable_general;
      m_position   = enable_position;
      m_risk       = enable_risk;
      m_session    = enable_session;
      m_news       = enable_news;
      m_simulation = enable_simulation;
      m_strategy   = enable_strategy;
      m_orders     = enable_orders;
      m_diagnostic = enable_diagnostic;
      m_invariant  = enable_invariant;
     }

   static void SetPrefix(const string prefix)
     {
      m_prefix = prefix;
     }

   static void Info(const AURORA_LOG_CATEGORY category, const string message)
     {
      if(!Enabled(category)) return; PrintWithLevel("INFO", category, message);
     }
   static void Warn(const AURORA_LOG_CATEGORY category, const string message)
     {
      if(!Enabled(category)) return; PrintWithLevel("WARN", category, message);
     }
   static void Error(const AURORA_LOG_CATEGORY category, const string message)
     {
      if(!Enabled(category)) return; PrintWithLevel("ERROR", category, message);
     }

   // Raccourcis News
   static void InfoNews(const string message)  { Info(AURORA_LOG_NEWS, message); }
   static void WarnNews(const string message)  { Warn(AURORA_LOG_NEWS, message); }
   static void ErrorNews(const string message) { Error(AURORA_LOG_NEWS, message); }

   // Category shortcuts (ergonomics)
   static void InfoGeneral(const string message)    { Info(AURORA_LOG_GENERAL, message); }
   static void WarnGeneral(const string message)    { Warn(AURORA_LOG_GENERAL, message); }
   static void ErrorGeneral(const string message)   { Error(AURORA_LOG_GENERAL, message); }

   static void InfoOrders(const string message)     { Info(AURORA_LOG_ORDERS, message); }
   static void WarnOrders(const string message)     { Warn(AURORA_LOG_ORDERS, message); }
   static void ErrorOrders(const string message)    { Error(AURORA_LOG_ORDERS, message); }
   static void InfoInvariant(const string message)  { Info(AURORA_LOG_INVARIANT, message); }
   static void WarnInvariant(const string message)  { Warn(AURORA_LOG_INVARIANT, message); }
   static void ErrorInvariant(const string message) { Error(AURORA_LOG_INVARIANT, message); }

   static void InfoPosition(const string message)   { Info(AURORA_LOG_POSITION, message); }
   static void WarnPosition(const string message)   { Warn(AURORA_LOG_POSITION, message); }
   static void ErrorPosition(const string message)  { Error(AURORA_LOG_POSITION, message); }

   static void InfoRisk(const string message)       { Info(AURORA_LOG_RISK, message); }
   static void WarnRisk(const string message)       { Warn(AURORA_LOG_RISK, message); }
   static void ErrorRisk(const string message)      { Error(AURORA_LOG_RISK, message); }

   static void InfoSim(const string message)        { Info(AURORA_LOG_SIMULATION, message); }
   static void WarnSim(const string message)        { Warn(AURORA_LOG_SIMULATION, message); }
   static void ErrorSim(const string message)       { Error(AURORA_LOG_SIMULATION, message); }

   static void InfoSession(const string message)    { Info(AURORA_LOG_SESSION, message); }
   static void WarnSession(const string message)    { Warn(AURORA_LOG_SESSION, message); }
   static void ErrorSession(const string message)   { Error(AURORA_LOG_SESSION, message); }

   static void InfoStrategy(const string message)   { Info(AURORA_LOG_STRATEGY, message); }
   static void WarnStrategy(const string message)   { Warn(AURORA_LOG_STRATEGY, message); }
   static void ErrorStrategy(const string message)  { Error(AURORA_LOG_STRATEGY, message); }

   static void InfoDiag(const string message)       { Info(AURORA_LOG_DIAGNOSTIC, message); }
   static void WarnDiag(const string message)       { Warn(AURORA_LOG_DIAGNOSTIC, message); }
   static void ErrorDiag(const string message)      { Error(AURORA_LOG_DIAGNOSTIC, message); }

   // Raccourcis Pipeline
   static void InfoPipe(const string message)       { Info(AURORA_LOG_PIPELINE, message); }
   static void WarnPipe(const string message)       { Warn(AURORA_LOG_PIPELINE, message); }
   static void ErrorPipe(const string message)      { Error(AURORA_LOG_PIPELINE, message); }
  };

// Static definitions
bool   CAuroraLogger::m_general    = true;
bool   CAuroraLogger::m_position   = false;
bool   CAuroraLogger::m_risk       = false;
bool   CAuroraLogger::m_session    = false;
bool   CAuroraLogger::m_news       = false;
bool   CAuroraLogger::m_simulation = false;
bool   CAuroraLogger::m_strategy   = false;
bool   CAuroraLogger::m_orders     = false;
bool   CAuroraLogger::m_invariant  = false;
bool   CAuroraLogger::m_diagnostic = false;
string CAuroraLogger::m_prefix     = "";

#endif // __AURORA_LOGGER_MQH__
