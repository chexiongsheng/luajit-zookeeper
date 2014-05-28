--
--------------------------------------------------------------------------------
--         FILE:  zookeeper_epoll.lua
--        USAGE:  ./zookeeper_epoll.lua 
--  DESCRIPTION:  
--      OPTIONS:  ---
-- REQUIREMENTS:  ---
--         BUGS:  ---
--        NOTES:  ---
--       AUTHOR:  John (J), <chexiongsheng@qq.com>
--      COMPANY:  
--      VERSION:  1.0
--      CREATED:  2014年05月15日 14时39分50秒 CST
--     REVISION:  ---
--------------------------------------------------------------------------------
--

local ffi = require 'ffi'
local zklib = require 'zookeeper_ffi'

local threadpool = require 'threadpool_ext'

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

local zklib_epoll = setmetatable({}, {__index = zklib})

local seq_num = math.random(0, 2^32 - 1)
local function alloc_seq ()
    seq_num = (seq_num + 1) % 2^32
    return seq_num
end

zklib_epoll.zookeeper_init = function(host, fn, recv_timeout, flags, epoll_obj)
    local zh = zklib.zookeeper_init(host, fn, recv_timeout, flags)
    epoll_register(zh, epoll_obj)
    math.randomseed(epoll_obj:now())
    seq_num = math.random(0, 2^32 - 1)
    print('seq_num = ', seq_num)
    return zh
end

local data_ptr = ffi.new('uint[2]')
local uint32_ptr = ffi.cast('uintptr_t *', data_ptr)
local function merge_to_void_ptr(n1, n2)
    assert(n1 < 2 ^ 32)
    assert(n2 <= 2^20)
    data_ptr[0], data_ptr[1] = n1, n2
    return ffi.cast('void *', uint32_ptr[0])
end
local function extract_void_ptr(void_ptr)
    local n = tonumber(ffi.cast('uintptr_t', void_ptr))
    return n % (2^32), math.floor(n / (2^32))
end

local string_completion_ptr = ffi.cast("string_completion_t", function(rc, value, data)
    local seq, thread_id = extract_void_ptr(data)
    threadpool.notify(thread_id, seq, 0, rc)
end)

local WAIT_TIME = 9

zklib_epoll.zoo_create = function(zh, path, value, flags)
    local seq_num, thread_id = alloc_seq(), threadpool.running.id
    zklib.zoo_acreate(zh, path, value, flags, string_completion_ptr, merge_to_void_ptr(seq_num, thread_id))
    local wrc, rc = threadpool.wait(seq_num, WAIT_TIME)
    if wrc ~= 0 then
        error('zoo_create fail! return code =' .. wrc)
    end
    return rc
end

zklib_epoll.zoo_client_id = function(zh)
    local cid = zklib.zoo_client_id(zh)
    return {client_id = tonumber(cid.client_id), passwd = ffi.string(cid.passwd)}
end

zklib_epoll.zerror = function(rc)
    return ffi.string(zklib.zerror(rc))
end

return zklib_epoll


