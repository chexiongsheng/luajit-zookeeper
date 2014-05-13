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
local zklib = require 'zookeeper_ffi'

local bit = require "bit"
local wrap_file = require "fend.file".wrap

local zk_cbs = {}
local zk_read_cb, zk_write_cb, zk_timer_cb, zk_error_cb, epoll_register
local heartbeat_timeout, heartbeat_timer

epoll_register = function(zh, epoll_obj, old_fd)
    local rc, fd, interest, check_interval = zklib.zookeeper_interest(zh)
    heartbeat_timeout = epoll_obj.now() + check_interval
    --print('zookeeper_interest:', rc, fd, interest, check_interval)
    if rc ~= zklib.ZOK then
        print(string.format("zookeeper_interest returned error: %d - %s\n", rc, ffi.string(zklib.zerror(rc))))
        if heartbeat_timer then
            heartbeat_timer:set(0)
        end
        return
    end
    if fd == -1 then
        print("stop zookeeper because of -1 fd")
        if old_fd then 
            pcall(old_fd.close, old_fd)
        end
        return
    end
    zk_cbs.read = bit.band ( interest , zklib.ZOOKEEPER_READ ) ~= 0 and zk_read_cb or nil
    zk_cbs.write = bit.band ( interest , zklib.ZOOKEEPER_WRITE ) ~= 0 and zk_write_cb or nil
    zk_cbs.epoll_obj = epoll_obj
    zk_cbs.zh = zh
    if old_fd and old_fd:getfd() ~= fd then 
        old_fd:close()
        old_fd = nil
    end
    --pcall(epoll_obj.del_fd, epoll_obj, old_fd or wrap_file(fd))
    local pcall_ret, msg = pcall(epoll_obj.add_fd, epoll_obj, wrap_file(fd), zk_cbs)
    if not pcall_ret then
        print("call add_fd, fail", msg)
    end
    if heartbeat_timer then
        heartbeat_timer:set(check_interval)
    else
        heartbeat_timer = epoll_obj:add_timer(check_interval, 0, function()
            local delay = heartbeat_timeout - epoll_obj.now() 
            --print('on heartbeat_timer', delay, heartbeat_timeout)
            if delay <= 0 then
                --print("zookeeper_process.events=0")
                zklib.zookeeper_process (zh, 0)
                epoll_register(zh, epoll_obj, old_fd)
            else
                return delay
            end
        end)
    end
end
local zk_io_cb = function(zh, epoll_obj, events, fd)
    --print("zookeeper_process.events="..events)
    local rc = zklib.zookeeper_process (zh, events)
    if rc ~= zklib.ZOK then
        print(string.format("zookeeper_process returned error: %d - %s\n", rc, ffi.string(zklib.zerror(rc))))
    end
    epoll_register(zh, epoll_obj, fd)
end
zk_read_cb = function(fd, cbs)
    zk_io_cb(cbs.zh, cbs.epoll_obj, zklib.ZOOKEEPER_READ, fd)
end
zk_write_cb = function(fd, cbs)
    zk_io_cb(cbs.zh, cbs.epoll_obj, zklib.ZOOKEEPER_WRITE, fd)
end
zk_close_cb = function(fd, cbs)
    fd:close()
end
zk_error_cb = function(fd, cbs)
    pcall(cbs.epoll_obj.del_fd, cbs.epoll_obj, fd)
    pcall(fd.close)
    epoll_register(cbs.zh, cbs.epoll_obj, fd)
end
zk_cbs.close = zk_close_cb
zk_cbs.error = zk_error_cb

----------------------------TEST----------------------------
--

zklib.zoo_deterministic_conn_order(1)
zklib.zoo_set_debug_level(zklib.ZOO_LOG_LEVEL_WARN)
local zh, clientid = zklib.zookeeper_init("192.168.1.250:2181", function(zh, type, state, path, watcherCtx)
    if state == zklib.ZOO_CONNECTED_STATE then
        local cid = zklib.zoo_client_id(zh)
        print('connnected', tonumber(cid.client_id), ffi.string(cid.passwd))
    end
    --print(type, state, path)
end, 30000, 0)
print("clientid:", clientid.client_id, clientid.passwd)

zklib.zoo_acreate(zh, "/zklib", "john", 0, function(rc) 
    print('zoo_acreate rc =', rc, ffi.string(zklib.zerror(rc))) 
end)


local dispatcher = require "fend.epoll"
local e = dispatcher()
epoll_register(zh, e)

local runing = true

while runing do
    e:dispatch(100, -1, function(e, file , cbs , err , eventtype)
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



