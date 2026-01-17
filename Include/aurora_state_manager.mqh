//+------------------------------------------------------------------+
//|                                             Aurora State Manager |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property version   "1.00"
#property strict

#include <aurora_logger.mqh>

// Doit correspondre à la structure définie dans aurora_async_manager.mqh
#include <aurora_async_structs.mqh>

// NOTE: SAsyncRequest est défini dans aurora_async_manager.mqh.
// Pour éviter la dépendance circulaire, nous supposons que ce fichier sera inclus APRES la définition de struct.
// Alternativement, nous devrions extraire SAsyncRequest dans un fichier commun (ex: aurora_structs.mqh).
// Pour ce "Quick Win", nous allons faire une inclusion conditionnelle ou supposer l'ordre d'inclusion correct.

class CStateManager
{
private:
   string m_filename;
   
   string GetFileName()
   {
      // Fichier unique par Compte + Symbole + Magic (si possible, ici on simplifie par compte)
      return StringFormat("Aurora_AsyncState_%d.bin", AccountInfoInteger(ACCOUNT_LOGIN));
   }

public:
   CStateManager() {}
   ~CStateManager() {}

   // Save entire array of pending requests
   bool SaveState(const SAsyncRequest &pending[])
   {
      string fname = GetFileName();
      int handle = FileOpen(fname, FILE_WRITE | FILE_BIN | FILE_COMMON);
      
      if(handle == INVALID_HANDLE)
      {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
             CAuroraLogger::ErrorDiag(StringFormat("StateSave Fail: Cannot open %s (Err=%d)", fname, GetLastError()));
         return false;
      }
      
      int size = ArraySize(pending);
      FileWriteInteger(handle, size); 
      
      for(int i=0; i<size; i++) {
        // Simple Fields
        FileWriteInteger(handle, (int)pending[i].request_id);
        FileWriteInteger(handle, pending[i].retries);
        FileWriteLong(handle, (long)pending[i].timestamp);

        // MqlTradeRequest Fields
        FileWriteInteger(handle, (int)pending[i].req.action);
        FileWriteLong(handle, (long)pending[i].req.magic);
        FileWriteLong(handle, (long)pending[i].req.order);
        FileWriteString(handle, pending[i].req.symbol);
        FileWriteDouble(handle, pending[i].req.volume);
        FileWriteDouble(handle, pending[i].req.price);
        FileWriteDouble(handle, pending[i].req.stoplimit);
        FileWriteDouble(handle, pending[i].req.sl);
        FileWriteDouble(handle, pending[i].req.tp);
        FileWriteLong(handle, (long)pending[i].req.deviation);
        FileWriteInteger(handle, (int)pending[i].req.type);
        FileWriteInteger(handle, (int)pending[i].req.type_filling);
        FileWriteInteger(handle, (int)pending[i].req.type_time);
        FileWriteLong(handle, (long)pending[i].req.expiration);
        FileWriteString(handle, pending[i].req.comment);
        FileWriteLong(handle, (long)pending[i].req.position);
        FileWriteLong(handle, (long)pending[i].req.position_by);
      }
         
      FileClose(handle);
      return true;
   }

   // Load state from disk
   bool LoadState(SAsyncRequest &pending[])
   {
      string fname = GetFileName();
      if(!FileIsExist(fname, FILE_COMMON)) return false; 
      
      int handle = FileOpen(fname, FILE_READ | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE) return false;
      
      int size = FileReadInteger(handle);
      if(size < 0) size = 0; // Integrity check
      
      ArrayResize(pending, size);

      for(int i=0; i<size; i++) {
         ZeroMemory(pending[i]);
         
         // Simple Fields
         pending[i].request_id = (uint)FileReadInteger(handle);
         pending[i].retries = FileReadInteger(handle);
         pending[i].timestamp = (datetime)FileReadLong(handle);

         // MqlTradeRequest Fields
         pending[i].req.action = (ENUM_TRADE_REQUEST_ACTIONS)FileReadInteger(handle);
         pending[i].req.magic = (ulong)FileReadLong(handle);
         pending[i].req.order = (ulong)FileReadLong(handle);
         pending[i].req.symbol = FileReadString(handle);
         pending[i].req.volume = FileReadDouble(handle);
         pending[i].req.price = FileReadDouble(handle);
         pending[i].req.stoplimit = FileReadDouble(handle);
         pending[i].req.sl = FileReadDouble(handle);
         pending[i].req.tp = FileReadDouble(handle);
         pending[i].req.deviation = (ulong)FileReadLong(handle);
         pending[i].req.type = (ENUM_ORDER_TYPE)FileReadInteger(handle);
         pending[i].req.type_filling = (ENUM_ORDER_TYPE_FILLING)FileReadInteger(handle);
         pending[i].req.type_time = (ENUM_ORDER_TYPE_TIME)FileReadInteger(handle);
         pending[i].req.expiration = (datetime)FileReadLong(handle);
         pending[i].req.comment = FileReadString(handle);
         pending[i].req.position = (ulong)FileReadLong(handle);
         pending[i].req.position_by = (ulong)FileReadLong(handle);
      }
      
      if(size > 0 && CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
          CAuroraLogger::InfoGeneral(StringFormat("State Restored: %d pending async orders recovered.", size));
      
      FileClose(handle);
      return true;
   }
   
   void ClearState()
   {
       string fname = GetFileName();
       if(FileIsExist(fname, FILE_COMMON))
           FileDelete(fname, FILE_COMMON);
   }
};
