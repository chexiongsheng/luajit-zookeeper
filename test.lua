--
--------------------------------------------------------------------------------
--         FILE:  test.lua
--        USAGE:  ./test.lua 
--  DESCRIPTION:  
--      OPTIONS:  ---
-- REQUIREMENTS:  ---
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  chexiongsheng, <chexiongsheng@qq.com>
--      VERSION:  1.0
--      CREATED:  2014年05月13日 15时13分47秒 CST
--     REVISION:  ---
--------------------------------------------------------------------------------
--

local ffi = require 'ffi'

local zklib = require 'zookeeper_epoll'
local dispatcher = require "fend.epoll"
local epoll = dispatcher()

zklib.zoo_deterministic_conn_order(1)
zklib.zoo_set_debug_level(zklib.ZOO_LOG_LEVEL_WARN)
local zh = zklib.zookeeper_init("192.168.1.250:2181", function(zh, type, state, path, watcherCtx)
    if state == zklib.ZOO_CONNECTED_STATE then
        local cid = zklib.zoo_client_id(zh)
        print('connnected', 'client_id=', tonumber(cid.client_id), 'passwd=', ffi.string(cid.passwd))
    end
    --print(type, state, path)
end, 30000, 0, epoll)

--zklib.zoo_acreate(zh, "/zklib", "john", 0, function(rc, _, data) 
--    print('zoo_acreate rc =', rc, ffi.string(zklib.zerror(rc)), tonumber(ffi.cast('uintptr_t', data))) 
--end, ffi.cast('void *', ffi.cast('uintptr_t', 1234)))

local threadpool = require 'threadpool_epoll'
threadpool.init({
    logger = {
        warn = print,
        error = print,
        debug = print
    },
    growing_thread_num = 10,
    epoll = epoll,
})

threadpool.work(function()
    local rc, value = zklib.zoo_create(zh, "/zklib", "john", 0)
    print('zoo_acreate rc =', rc, ffi.string(zklib.zerror(rc))) 
end)

local runing = true

while runing do
    epoll:dispatch(100, -1, function(e, file , cbs , err , eventtype)
        print(file:getfd(), 'dispatch.onerror, err =', err, debug.traceback())
        local pcall_ret, msg = pcall(e.del_fd, e, file )
        if not pcall_ret then
            print('dispatch.onerror, call del_fd fail, msg = ', msg)
        end
        pcall_ret, msg = pcall( file.close , file )
        file.no_close = true
        if not pcall_ret then
            print('dispatch.onerror, call file.close fail, msg = ', msg)
        end
    end)
    collectgarbage ()
end



