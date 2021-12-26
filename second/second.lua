#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local clock = require('clock')
local client = require('http.client').new()

local ips = {
   -- <Вставить ИП адреса с портами виртуалок>
   '127.0.0.1:8081',    -- пример, remove me
   '127.0.0.1:8082', -- пример, remove me
   '127.0.0.1:8083'
}

-- Функция заполнения состояния players
local function fill_states(ips)
   local result = {}
   for i, ip in ipairs(ips) do
      -- Запрос на получене имени клиента
      local success, response = pcall(client.get, client, ip .. '/name', {timeout=2})
      if success and response['status'] == 200 then
         result[ip] = {
            ip = ip,
            name = response['body'],
            health = 5,
         }
      end
   end
   return result
end


local function get_action(player)
   local ip = player.ip
   -- Запрос действия игрока
   local success, response = pcall(client.get, client, ip .. '/action?health=' .. tostring(player.health) , {timeout=2})
   if success and response['status'] == 200 then
      return response['body']
   end
   return nil
end

-- Вывод игроков
local function print_players(players)
   for ip, player in pairs(players) do
      print(ip, player.health, player.affect, player.ping, player.name)
   end
end

local function main()
   local dead = {}
   local players = fill_states(ips)

   local times = 20

   local dead = {}
   -- Ходим по таблице игроков
   while next(players) and next(players, next(players)) and times > 0 do
      print('----------------', times)
      print_players(players)
      fiber.sleep(1)

      for ip, _ in pairs(dead) do
         players[ip] = nil
      end
      dead = {}

      local actions = {}
      -- Опрос действий игрока. Запись пинга
      for ip, player in pairs(players) do
         local start = clock.monotonic64()
         action = get_action(player)
         player.ping = clock.monotonic64() - start
         actions[ip] = action
      end

      for ip, action in pairs(actions) do
         local _, near_player = next(players, ip)
         if not near_player then
            _, near_player = next(players)
         end

         local _, near_action = next(actions, ip)
         if not near_action then
            _, near_action = next(actions)
         end

         near_player.affect = nil
         if action == 'hit' then
            if near_action ~= 'squat' then
               near_player.health = near_player.health - 1
               near_player.affect = 'hit'
            end
         elseif action == 'hooking' then
            if near_action ~= 'jump' then
               near_player.health = near_player.health - 1
               near_player.affect = 'fell'
            end
         end

         if near_player.health == 0 then
            dead[near_player.ip] = true
         end
      end

      times = times - 1
   end

   for ip, _ in pairs(dead) do
      players[ip] = nil
   end

   local result = {}
   for _, player in pairs(players) do
      table.insert(result, player)
   end
   table.sort(result, function(left, right) return left.health > right.health end)

   print('================', 'End')
   for _, player in ipairs(result) do
      print(player.ip, player.health, player.name)
   end
end

main()