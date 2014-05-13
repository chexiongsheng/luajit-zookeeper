--
--------------------------------------------------------------------------------
--         FILE:  zookeeper_ffi.lua
--        USAGE:  ./zookeeper_ffi.lua 
--  DESCRIPTION:  
--      OPTIONS:  ---
-- REQUIREMENTS:  ---
--       zookeeper 3.4.6
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  John
--      VERSION:  1.0
--      CREATED:  2014年04月19日 16时36分14秒 CST
--     REVISION:  ---
--------------------------------------------------------------------------------
--
require 'zkdef'
local ffi = require 'ffi'
local _zk = ffi.load('zookeeper_st')

local ZOO_ERRORS = {
  ZOK = 0, --!< Everything is OK 

  --[[* System and server-side errors.
       * This is never thrown by the server, it shouldn't be used other than
       * to indicate a range. Specifically error codes greater than this
       * value, but lesser than {@link #ZAPIERROR}, are system errors. ]]
  ZSYSTEMERROR = -1,
  ZRUNTIMEINCONSISTENCY = -2, --!< A runtime inconsistency was found */
  ZDATAINCONSISTENCY = -3, --!< A data inconsistency was found */
  ZCONNECTIONLOSS = -4, --!< Connection to the server has been lost */
  ZMARSHALLINGERROR = -5, --!< Error while marshalling or unmarshalling data */
  ZUNIMPLEMENTED = -6, --!< Operation is unimplemented */
  ZOPERATIONTIMEOUT = -7, --!< Operation timeout */
  ZBADARGUMENTS = -8, --!< Invalid arguments */
  ZINVALIDSTATE = -9, --!< Invliad zhandle state */

  --[[ * API errors.
       * This is never thrown by the server, it shouldn't be used other than
       * to indicate a range. Specifically error codes greater than this
       * value are API errors (while values less than this indicate a 
       * {@link #ZSYSTEMERROR}).]]

  ZAPIERROR = -100,
  ZNONODE = -101, --!< Node does not exist */
  ZNOAUTH = -102, --!< Not authenticated */
  ZBADVERSION = -103, --!< Version conflict */
  ZNOCHILDRENFOREPHEMERALS = -108, --!< Ephemeral nodes may not have children */
  ZNODEEXISTS = -110, --!< The node already exists */
  ZNOTEMPTY = -111, --!< The node has children */
  ZSESSIONEXPIRED = -112, --!< The session has been expired by the server */
  ZINVALIDCALLBACK = -113, --!< Invalid callback specified */
  ZINVALIDACL = -114, --!< Invalid ACL specified */
  ZAUTHFAILED = -115, --!< Client authentication failed */
  ZCLOSING = -116, --!< ZooKeeper is closing */
  ZNOTHING = -117, --!< (not error) no server responses to process */
  ZSESSIONMOVED = -118 --!<session moved to another server, so operation is ignored */ 
}

local ZooLogLevel = {ZOO_LOG_LEVEL_ERROR=1,ZOO_LOG_LEVEL_WARN=2,ZOO_LOG_LEVEL_INFO=3,ZOO_LOG_LEVEL_DEBUG=4} 

local zklib = setmetatable({}, {__index = function(t, k) return _zk[k] end})
for k, v in pairs(ZOO_ERRORS) do zklib[k] = v end
for k, v in pairs(ZooLogLevel) do zklib[k] = v end

local clientid_ptr = ffi.new("clientid_t[1]")
zklib.zookeeper_init = function(host, fn, recv_timeout, flags)
    local zh = _zk.zookeeper_init(host, fn, recv_timeout, clientid_ptr, nil, flags)
    return zh, {client_id = tonumber(clientid_ptr[0].client_id), passwd = ffi.string(clientid_ptr[0].passwd)}
end

zklib.zoo_acreate = function(zh, path, value, flags, completion) 
    local completion_ptr 
    completion_ptr = ffi.cast("string_completion_t", function(rc, value, data)
        completion_ptr:free()
        completion(rc)
    end)
    _zk.zoo_acreate(zh, path, value, #value, _zk.ZOO_OPEN_ACL_UNSAFE, flags, completion_ptr, nil)
end

local fd_ptr = ffi.new("int[1]", {0})
local interest_ptr = ffi.new("int[1]", {0})
local tv_ptr = ffi.new('struct timeval[1]')
zklib.zookeeper_interest = function(zh)
    local ret = _zk.zookeeper_interest(zh, fd_ptr, interest_ptr, tv_ptr)
    return ret, fd_ptr[0], interest_ptr[0], (tonumber(tv_ptr[0].tv_sec) + tonumber(tv_ptr[0].tv_usec) / 1000000)
end


return zklib

