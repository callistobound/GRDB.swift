#ifndef grdb_config_h
#define grdb_config_h

#if __has_include(<SQLCipher/sqlite3.h>)
#include <SQLCipher/sqlite3.h>

typedef void(*_errorLogCallback)(void *pArg, int iErrCode, const char *zMsg);

/// Wrapper around sqlite3_config(SQLITE_CONFIG_LOG, ...) which is a variadic
/// function that can't be used from Swift.
static inline void _registerErrorLogCallback(_errorLogCallback callback) {
    sqlite3_config(SQLITE_CONFIG_LOG, callback, 0);
}

#if SQLITE_VERSION_NUMBER >= 3029000
/// Wrapper around sqlite3_db_config() which is a variadic function that can't
/// be used from Swift.
static inline void _disableDoubleQuotedStringLiterals(sqlite3 *db) {
    sqlite3_db_config(db, SQLITE_DBCONFIG_DQS_DDL, 0, (void *)0);
    sqlite3_db_config(db, SQLITE_DBCONFIG_DQS_DML, 0, (void *)0);
}

/// Wrapper around sqlite3_db_config() which is a variadic function that can't
/// be used from Swift.
static inline void _enableDoubleQuotedStringLiterals(sqlite3 *db) {
    sqlite3_db_config(db, SQLITE_DBCONFIG_DQS_DDL, 1, (void *)0);
    sqlite3_db_config(db, SQLITE_DBCONFIG_DQS_DML, 1, (void *)0);
}
#else
static inline void _disableDoubleQuotedStringLiterals(sqlite3 *db) { }
static inline void _enableDoubleQuotedStringLiterals(sqlite3 *db) { }
#endif
#else
// swift-sqlcipher (github.com/skiptools/swift-sqlcipher): its SQLCipher module has sqlite3.h at the top and
// already declares the helpers above (its grdb.h).
#include <sqlite3.h>
#endif
#endif /* grdb_config_h */
