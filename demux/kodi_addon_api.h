#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#if defined _WIN32 || defined _WIN64 || defined __CYGWIN__
#define ATTR_DLL_EXPORT __declspec(dllexport)
#else
#define ATTR_DLL_EXPORT __attribute__((visibility("default")))
#endif

typedef void* KODI_ADDON_HDL;
typedef void* KODI_ADDON_BACKEND_HDL;
typedef void* KODI_ADDON_INSTANCE_HDL;

typedef enum ADDON_STATUS {
    ADDON_STATUS_OK,
    ADDON_STATUS_LOST_CONNECTION,
    ADDON_STATUS_NEED_RESTART,
    ADDON_STATUS_NEED_SETTINGS,
    ADDON_STATUS_UNKNOWN,
    ADDON_STATUS_PERMANENT_FAILURE,
    ADDON_STATUS_NOT_IMPLEMENTED
} ADDON_STATUS;

typedef enum ADDON_LOG {
    ADDON_LOG_DEBUG = 0,
    ADDON_LOG_INFO = 1,
    ADDON_LOG_WARNING = 2,
    ADDON_LOG_ERROR = 3,
    ADDON_LOG_FATAL = 4
} ADDON_LOG;

typedef int KODI_ADDON_INSTANCE_TYPE;

struct AddonInstance_InputStream;

typedef struct KODI_ADDON_INSTANCE_INFO
{
    KODI_ADDON_INSTANCE_TYPE type;
    uint32_t number;
    const char* id;
    const char* version;
    void* kodi;
    KODI_ADDON_INSTANCE_HDL parent;
    bool first_instance;
    void* functions;
} KODI_ADDON_INSTANCE_INFO;

typedef struct KODI_ADDON_INSTANCE_STRUCT
{
    const KODI_ADDON_INSTANCE_INFO* info;
    KODI_ADDON_INSTANCE_HDL hdl;
    void* functions;
    union
    {
      void* dummy;
      struct AddonInstance_InputStream* inputstream;
    };
} KODI_ADDON_INSTANCE_STRUCT;

typedef struct AddonToKodiFuncTable_Addon {
    KODI_ADDON_BACKEND_HDL kodiBase;
    void (*free_string)(const KODI_ADDON_BACKEND_HDL hdl, char* str);
    void (*addon_log_msg)(const KODI_ADDON_BACKEND_HDL hdl, const int loglevel, const char* msg);
    // ...
} AddonToKodiFuncTable_Addon;

typedef struct KodiToAddonFuncTable_Addon {
    ADDON_STATUS (*create)(const void* first_instance, KODI_ADDON_HDL* hdl);
    void (*destroy)(const KODI_ADDON_HDL hdl);
    ADDON_STATUS (*create_instance)(const KODI_ADDON_HDL hdl, struct KODI_ADDON_INSTANCE_STRUCT* instance);
    void (*destroy_instance)(const KODI_ADDON_HDL hdl, struct KODI_ADDON_INSTANCE_STRUCT* instance);
    // ...
} KodiToAddonFuncTable_Addon;

typedef struct AddonGlobalInterface {
    struct KODI_ADDON_INSTANCE_STRUCT* firstKodiInstance;
    KODI_ADDON_HDL addonBase;
    KODI_ADDON_INSTANCE_HDL globalSingleInstance;
    AddonToKodiFuncTable_Addon* toKodi;
    KodiToAddonFuncTable_Addon* toAddon;
} AddonGlobalInterface;

#define STREAM_TIME_BASE 1000000
#define STREAM_NOPTS_VALUE 0xFFF0000000000000

#define STREAM_PROPERTY_INPUTSTREAM "inputstream"
#define STREAM_MAX_PROPERTY_COUNT 30

enum STREAM_CRYPTO_KEY_SYSTEM {
    STREAM_CRYPTO_KEY_SYSTEM_NONE = 0,
    STREAM_CRYPTO_KEY_SYSTEM_WIDEVINE,
    STREAM_CRYPTO_KEY_SYSTEM_PLAYREADY,
    STREAM_CRYPTO_KEY_SYSTEM_WISEPLAY,
    STREAM_CRYPTO_KEY_SYSTEM_CLEARKEY,
    STREAM_CRYPTO_KEY_SYSTEM_COUNT
};

struct DEMUX_CRYPTO_INFO {
    uint16_t numSubSamples;
    uint16_t flags;
    uint16_t* clearBytes;
    uint32_t* cipherBytes;
    uint8_t iv[16];
    uint8_t kid[16];
    uint16_t mode;
    uint8_t cryptBlocks;
    uint8_t skipBlocks;
};

struct STREAM_CRYPTO_SESSION {
    enum STREAM_CRYPTO_KEY_SYSTEM keySystem;
    uint8_t flags;
    char sessionId[256];
};

enum STREAMCODEC_PROFILE {
    CodecProfileUnknown = 0,
    // ...
};

struct DEMUX_PACKET {
    uint8_t* pData;
    int iSize;
    int iStreamId;
    int64_t demuxerId;
    int iGroupId;
    void* pSideData;
    int iSideDataElems;
    double pts;
    double dts;
    double duration;
    int dispTime;
    bool recoveryPoint;
    struct DEMUX_CRYPTO_INFO* cryptoInfo;
};
