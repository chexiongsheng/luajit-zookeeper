--
--------------------------------------------------------------------------------
--         FILE:  common.lua
--        USAGE:  ./common.lua 
--  DESCRIPTION:  
--      OPTIONS:  ---
-- REQUIREMENTS:  ---
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  chexiongsheng, <chexiongsheng@qq.com>
--      VERSION:  1.0
--      CREATED:  2014年05月13日 15时01分22秒 CST
--     REVISION:  ---
--------------------------------------------------------------------------------
--

local ffi = require("ffi")

ffi.cdef [[
    typedef struct zhandle_t zhandle_t;
    typedef struct {
        int64_t client_id;
        char passwd[16];
    } clientid_t;
    typedef struct ACL_vector ACL_vector;

    /*callback def*/
    typedef void ( *watcher_fn)(zhandle_t *zh, int type,
             int state, const char *path,void *watcherCtx);
    typedef void
        (*string_completion_t)(int rc, const char *value, const void *data);
    
    typedef enum {ZOO_LOG_LEVEL_ERROR=1,ZOO_LOG_LEVEL_WARN=2,ZOO_LOG_LEVEL_INFO=3,ZOO_LOG_LEVEL_DEBUG=4} ZooLogLevel;

    /** This is a completely open ACL*/
    struct ACL_vector ZOO_OPEN_ACL_UNSAFE;
    /** This ACL gives the world the ability to read. */
    struct ACL_vector ZOO_READ_ACL_UNSAFE;
    /** This ACL gives the creators authentication id's all permissions. */
    struct ACL_vector ZOO_CREATOR_ALL_ACL;

    /*Interest Consts */
    const int ZOOKEEPER_WRITE;
    const int ZOOKEEPER_READ;

    const int ZOO_EPHEMERAL;
    const int ZOO_SEQUENCE;

    const int ZOO_EXPIRED_SESSION_STATE;
    const int ZOO_AUTH_FAILED_STATE;
    const int ZOO_CONNECTING_STATE;
    const int ZOO_ASSOCIATING_STATE;
    const int ZOO_CONNECTED_STATE;

    const int ZOO_CREATED_EVENT;
    const int ZOO_DELETED_EVENT;
    const int ZOO_CHANGED_EVENT;
    const int ZOO_CHILD_EVENT;
    const int ZOO_SESSION_EVENT;
    const int ZOO_NOTWATCHING_EVENT;


    zhandle_t *zookeeper_init(const char *host, watcher_fn fn,
         int recv_timeout, const clientid_t *clientid, void *context, int flags);

    int zookeeper_close(zhandle_t *zh);

    const char* zerror(int c);

    int zookeeper_interest(zhandle_t *zh, int *fd, int *interest, 
	    struct timeval *tv);

    int zookeeper_process(zhandle_t *zh, int events);

    int zoo_acreate(zhandle_t *zh, const char *path, const char *value, 
        int valuelen, const struct ACL_vector *acl, int flags,
        string_completion_t completion, const void *data);
    
    void zoo_deterministic_conn_order(int yesOrNo);
    void zoo_set_debug_level(ZooLogLevel logLevel);
    const clientid_t *zoo_client_id(zhandle_t *zh);
]]

--begin timeval def
require "fend.common"

--you can replace then fend.common requirement with below
--ffi.cdef [[
--    typedef long int __time_t;
--    typedef long int __suseconds_t;
--    struct timeval
--    {
--        __time_t tv_sec;
--        __suseconds_t tv_usec;
--    };
--]]
--end timeval def



