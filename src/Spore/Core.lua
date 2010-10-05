
--
-- lua-Spore : <http://fperrad.github.com/lua-Spore/>
--

local require = require
local type = type
local table = require 'table'
local ltn12 = require 'ltn12'
local Request = require 'Spore.Request'


module 'Spore.Core'

local protocol = {
    http    = require 'socket.http',
    https   = require 'ssl.https',
}

function enable (self, mw, args)
    if not mw:match'^Spore%.Middleware%.' then
        mw = 'Spore.Middleware.' .. mw
    end
    local m = require(mw)
    local f = function (req)
        return m.call(args, req)
    end
    local t = self.middlewares; t[#t+1] = f
end

function http_request (self, env)
    local req = Request.new(env)
    local callbacks = {}
    local response 
    local middlewares = self.middlewares
    for i = 1, #middlewares do
        local mw = middlewares[i]
        local res = mw(req)
        if type(res) == 'function' then
            callbacks[#callbacks+1] = res
        elseif res then
            if res.status == 599 then
                return res
            end
            response = res
            break
        end
    end

    if response == nil then
        req:finalize()
        local t = {}
        req.sink = ltn12.sink.table(t)
        local r, status, headers = protocol[env.spore.url_scheme].request(req)
        response = {
            status = status,
            headers = headers,
            body = table.concat(t),
        }
    end

    if #callbacks > 0 then
        for i = #callbacks, 1 do
            local cb = callbacks[i]
            response = cb(response)
        end
    end
    return response
end

--
-- Copyright (c) 2010 Francois Perrad
--
-- This library is licensed under the terms of the MIT/X11 license,
-- like Lua itself.
--
