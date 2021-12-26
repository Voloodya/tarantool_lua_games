#!/usr/bin/env tarantool

local http = require('http.server')
--local router = require('http.router').new()

server = http.new('0.0.0.0', 8083)

-- возвращает имя игрока
function name(req)
   return {
      status = 200,
      body = 'thebot_3'
   }
end

--[[
-- Выбрать или атаковать или защищаться
-- Если решили атаковать выбрать "hit" или "hooking"
-- Если решили защищаться выбрать "squat" или "jump"
--    "squat" защищает от "hit"
--    "jump" защищает от "hooking"
--]]
local actions = {
   "hit",
   "hooking",
   "squat",
   "jump",
}
local fiber = require('fiber')
math.randomseed(fiber.time())

--/action - принимает количество текущих жизней и возвращает одно из действий
function action(req)
    local text = req:param('health')
    local health = tonumber(text)

    local action = actions[math.random(1,3)]

    return {
        status = 200,
        body = action, -- action
    }
end

server:route({path="/name", method="GET"}, name)
server:route({path="/action", method="GET"}, action)

server:start()