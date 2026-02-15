//+------------------------------------------------------------------+
//|                                             Aurora State Manager |
//|                                    Copyright 2026, Tommy Suzanne |
//|                                  https://github.com/tommysuzanne |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Tommy Suzanne"
#property link      " https://github.com/tommysuzanne"
#property strict

#ifndef __AURORA_STATE_MANAGER_MQH__
#define __AURORA_STATE_MANAGER_MQH__

#include <Aurora/aurora_logger.mqh>

// Must match structure defined in aurora_async_manager.mqh
#include <Aurora/aurora_types.mqh>

#define AURORA_STATE_SIGNATURE 0x41555241
#define AURORA_STATE_VERSION   2
#define AURORA_STATE_FOOTER    0x41535445

// NOTE: SAsyncRequest is defined in aurora_async_manager.mqh.
// To avoid circular dependency, we assume this file is included AFTER the struct definition.
// Alternativement, nous devrions extraire SAsyncRequest dans un fichier commun (ex: aurora_structs.mqh).
// Pour ce "Quick Win", nous allons faire une inclusion conditionnelle ou supposer l'ordre d'inclusion correct.

class CStateManager
{
private:
   string m_filename;
   ulong  m_magic;
   string m_symbol;
   bool   m_configured;
   
   string SanitizeToken(const string value)
   {
      string out = value;
      int len = StringLen(out);
      for(int i=0; i<len; i++) {
         ushort ch = StringGetCharacter(out, i);
         bool ok = ((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z'));
         if(!ok) StringSetCharacter(out, i, '_');
      }
      return out;
   }
   
   string GetFileName()
   {
      string acc = (string)AccountInfoInteger(ACCOUNT_LOGIN);
      string sym = (m_symbol != "" ? m_symbol : _Symbol);
      string prog = MQLInfoString(MQL_PROGRAM_NAME);
      return StringFormat("Aurora_AsyncState_%s_%s_%s_%I64u.bin", acc, SanitizeToken(prog), SanitizeToken(sym), (long)m_magic);
   }
   
   bool PersistenceEnabled() const
   {
      if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return false;
      return true;
   }

   uint HashMix(uint hash, const ulong value) const
   {
      hash ^= (uint)(value & 0xFFFFFFFF);
      hash *= 16777619;
      hash ^= (uint)((value >> 32) & 0xFFFFFFFF);
      hash *= 16777619;
      return hash;
   }

   uint HashString(uint hash, const string value) const
   {
      int len = StringLen(value);
      for(int i=0; i<len; i++) {
         hash ^= (uint)StringGetCharacter(value, i);
         hash *= 16777619;
      }
      return hash;
   }

   uint HashDouble(uint hash, const double value) const
   {
      long scaled = (long)MathRound(value * 100000000.0);
      return HashMix(hash, (ulong)scaled);
   }

   uint ComputeRequestChecksum(const SAsyncRequest &item) const
   {
      uint h = 2166136261;
      h = HashMix(h, (ulong)item.request_id);
      h = HashMix(h, (ulong)item.retries);
      h = HashMix(h, (ulong)item.timestamp);
      h = HashMix(h, (ulong)item.req.action);
      h = HashMix(h, (ulong)item.req.magic);
      h = HashMix(h, (ulong)item.req.order);
      h = HashString(h, item.req.symbol);
      h = HashDouble(h, item.req.volume);
      h = HashDouble(h, item.req.price);
      h = HashDouble(h, item.req.stoplimit);
      h = HashDouble(h, item.req.sl);
      h = HashDouble(h, item.req.tp);
      h = HashMix(h, (ulong)item.req.deviation);
      h = HashMix(h, (ulong)item.req.type);
      h = HashMix(h, (ulong)item.req.type_filling);
      h = HashMix(h, (ulong)item.req.type_time);
      h = HashMix(h, (ulong)item.req.expiration);
      h = HashString(h, item.req.comment);
      h = HashMix(h, (ulong)item.req.position);
      h = HashMix(h, (ulong)item.req.position_by);
      return h;
   }

   bool IsValidLoadedRequest(const SAsyncRequest &item) const
   {
      if(item.timestamp <= 0) return false;
      if(item.req.symbol == "" || item.req.symbol == NULL) return false;
      if((ulong)item.req.magic != m_magic) return false;
      if(item.req.action == TRADE_ACTION_PENDING && item.req.order != 0) return false;
      if(item.req.action == TRADE_ACTION_SLTP && item.req.position == 0) return false;
      if((item.req.action == TRADE_ACTION_MODIFY || item.req.action == TRADE_ACTION_REMOVE) && item.req.order == 0) return false;
      return true;
   }

public:
   CStateManager() : m_magic(0), m_symbol(""), m_configured(false) {}
   ~CStateManager() {}
   
   void Configure(const ulong magic, const string symbol)
   {
      m_magic = magic;
      m_symbol = symbol;
      m_configured = true;
   }

   // Save entire array of pending requests
   bool SaveState(const SAsyncRequest &pending[])
   {
      if(!PersistenceEnabled() || !m_configured) return false;
      string fname = GetFileName();
      int handle = FileOpen(fname, FILE_WRITE | FILE_BIN | FILE_COMMON);
      
      if(handle == INVALID_HANDLE)
      {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_DIAGNOSTIC))
             CAuroraLogger::ErrorDiag(StringFormat("StateSave Fail: Cannot open %s (Err=%d)", fname, GetLastError()));
         return false;
      }
      
      int size = ArraySize(pending);
      uint fileHash = 2166136261;

      FileWriteInteger(handle, AURORA_STATE_SIGNATURE);
      FileWriteInteger(handle, AURORA_STATE_VERSION);
      FileWriteLong(handle, (long)AccountInfoInteger(ACCOUNT_LOGIN));
      FileWriteLong(handle, (long)m_magic);
      FileWriteString(handle, m_symbol);
      FileWriteInteger(handle, size);

      for(int i=0; i<size; i++) {
        const SAsyncRequest item = pending[i];
        // Simple Fields
        FileWriteInteger(handle, (int)item.request_id);
        FileWriteInteger(handle, item.retries);
        FileWriteLong(handle, (long)item.timestamp);

        // MqlTradeRequest Fields
        FileWriteInteger(handle, (int)item.req.action);
        FileWriteLong(handle, (long)item.req.magic);
        FileWriteLong(handle, (long)item.req.order);
        FileWriteString(handle, item.req.symbol);
        FileWriteDouble(handle, item.req.volume);
        FileWriteDouble(handle, item.req.price);
        FileWriteDouble(handle, item.req.stoplimit);
        FileWriteDouble(handle, item.req.sl);
        FileWriteDouble(handle, item.req.tp);
        FileWriteLong(handle, (long)item.req.deviation);
        FileWriteInteger(handle, (int)item.req.type);
        FileWriteInteger(handle, (int)item.req.type_filling);
        FileWriteInteger(handle, (int)item.req.type_time);
        FileWriteLong(handle, (long)item.req.expiration);
        FileWriteString(handle, item.req.comment);
        FileWriteLong(handle, (long)item.req.position);
        FileWriteLong(handle, (long)item.req.position_by);

        uint recordHash = ComputeRequestChecksum(item);
        FileWriteInteger(handle, (int)recordHash);
        fileHash = HashMix(fileHash, (ulong)recordHash);
      }

      FileWriteInteger(handle, AURORA_STATE_FOOTER);
      FileWriteInteger(handle, (int)fileHash);
         
      FileClose(handle);
      return true;
   }

   // Load state from disk
   bool LoadState(SAsyncRequest &pending[], const int max_items = 200)
   {
      if(!PersistenceEnabled() || !m_configured) return false;
      string fname = GetFileName();
      if(!FileIsExist(fname, FILE_COMMON)) return false; 
      
      int handle = FileOpen(fname, FILE_READ | FILE_BIN | FILE_COMMON);
      if(handle == INVALID_HANDLE) return false;

      ArrayResize(pending, 0);

      int signature = FileReadInteger(handle);
      if(signature != AURORA_STATE_SIGNATURE) {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::WarnGeneral(StringFormat("State Restore ignored: invalid signature (%d).", signature));
         FileClose(handle);
         return false;
      }

      int version = FileReadInteger(handle);
      if(version != AURORA_STATE_VERSION) {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::WarnGeneral(StringFormat("State Restore ignored: unsupported version (%d).", version));
         FileClose(handle);
         return false;
      }

      long fileAccount = FileReadLong(handle);
      long fileMagic = FileReadLong(handle);
      string fileSymbol = FileReadString(handle);
      if(fileAccount != (long)AccountInfoInteger(ACCOUNT_LOGIN) || (ulong)fileMagic != m_magic || fileSymbol != m_symbol) {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::WarnGeneral("State Restore ignored: metadata mismatch (account/magic/symbol).");
         FileClose(handle);
         return false;
      }

      int fileCount = FileReadInteger(handle);
      if(fileCount < 0) fileCount = 0;
      int limit = (max_items > 0 ? max_items : 0);
      if(limit > 0 && fileCount > limit) {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::WarnGeneral(StringFormat("State Restore Truncated: %d -> %d pending async orders.", fileCount, limit));
      }

      uint fileHash = 2166136261;
      int restored = 0;
      int keepLimit = (limit > 0 ? limit : fileCount);

      for(int i=0; i<fileCount; i++) {
         if(FileIsEnding(handle)) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
               CAuroraLogger::WarnGeneral("State Restore aborted: unexpected end-of-file.");
            ArrayResize(pending, 0);
            FileClose(handle);
            return false;
         }

         SAsyncRequest item;
         ZeroMemory(item);

         item.request_id = (uint)FileReadInteger(handle);
         item.retries = FileReadInteger(handle);
         item.timestamp = (datetime)FileReadLong(handle);

         item.req.action = (ENUM_TRADE_REQUEST_ACTIONS)FileReadInteger(handle);
         item.req.magic = (ulong)FileReadLong(handle);
         item.req.order = (ulong)FileReadLong(handle);
         item.req.symbol = FileReadString(handle);
         item.req.volume = FileReadDouble(handle);
         item.req.price = FileReadDouble(handle);
         item.req.stoplimit = FileReadDouble(handle);
         item.req.sl = FileReadDouble(handle);
         item.req.tp = FileReadDouble(handle);
         item.req.deviation = (ulong)FileReadLong(handle);
         item.req.type = (ENUM_ORDER_TYPE)FileReadInteger(handle);
         item.req.type_filling = (ENUM_ORDER_TYPE_FILLING)FileReadInteger(handle);
         item.req.type_time = (ENUM_ORDER_TYPE_TIME)FileReadInteger(handle);
         item.req.expiration = (datetime)FileReadLong(handle);
         item.req.comment = FileReadString(handle);
         item.req.position = (ulong)FileReadLong(handle);
         item.req.position_by = (ulong)FileReadLong(handle);

         uint storedRecordHash = (uint)FileReadInteger(handle);
         uint calcRecordHash = ComputeRequestChecksum(item);
         fileHash = HashMix(fileHash, (ulong)storedRecordHash);

         if(storedRecordHash != calcRecordHash || !IsValidLoadedRequest(item)) {
            if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
               CAuroraLogger::WarnGeneral("State Restore: corrupted or invalid async entry skipped.");
            continue;
         }

         if(restored >= keepLimit) continue;

         int n = ArraySize(pending);
         ArrayResize(pending, n + 1);
         pending[n] = item;
         restored++;
      }

      if(FileIsEnding(handle)) {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::WarnGeneral("State Restore aborted: missing footer.");
         ArrayResize(pending, 0);
         FileClose(handle);
         return false;
      }

      int footer = FileReadInteger(handle);
      uint storedFileHash = (uint)FileReadInteger(handle);
      if(footer != AURORA_STATE_FOOTER || storedFileHash != fileHash) {
         if(CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
            CAuroraLogger::WarnGeneral("State Restore aborted: footer checksum mismatch.");
         ArrayResize(pending, 0);
         FileClose(handle);
         return false;
      }

      if(restored > 0 && CAuroraLogger::IsEnabled(AURORA_LOG_GENERAL))
         CAuroraLogger::InfoGeneral(StringFormat("State Restored: %d pending async orders recovered.", restored));

      FileClose(handle);
      return (restored > 0);
   }
   
   void ClearState()
   {
       if(!PersistenceEnabled() || !m_configured) return;
       string fname = GetFileName();
       if(FileIsExist(fname, FILE_COMMON))
           FileDelete(fname, FILE_COMMON);
   }
};

#endif // __AURORA_STATE_MANAGER_MQH__
