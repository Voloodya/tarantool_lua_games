#!/usr/bin/env tarantool

local log = require('log')
local fiber = require('fiber')
local clock = require('clock')
local socket = require('socket')
local client = require('http.client').new()

local ips = {
   -- <Вставить ИП адреса с портами виртуалок>
   --'2.2.3.4',    -- пример, remove me
   --'33.44.44.45' -- пример, remove me
}

local function fill_states(ips)
    print('fill_states')
    local result = {}
    for i, ip in ipairs(ips) do
        s = socket.tcp_connect(ip, 8081, 1)
        if s then
            local name = s:read(10, 1)
            if name and #name > 0 then
                result[ip] = {
                    ip = ip,
                    name = name,
                    health = 5,
                    s = s,
                }
            end
        end
    end
    return result
end

local function get_action(player)
   local ip = player.ip
   player.s:write(tostring(player.health), 1)
   action = player.s:read(3, 1)
   return action
end

local function print_players(players)
    for ip, player in pairs(players) do
        local ping = 'norm '
        --if player.ping and player.ping > 2000000ULL then
        --    ping = 'late '
        --end
        if player.ping then
            ping = ping .. tostring(player.ping)
        end
        print(ip, player.health, player.affect, ping, player.name)
    end
end

local function main()
   local dead = {}
   local players = fill_states(ips)

   local times = 20

   local dead = {}
   while next(players) and next(players, next(players)) and times > 0 do
      print('----------------', times)
      print_players(players)
      fiber.sleep(1)

      for ip, _ in pairs(dead) do
         players[ip] = nil
      end
      dead = {}

      local actions = {}
      for ip, player in pairs(players) do
         local start = clock.monotonic64()
         action = get_action(player)
         player.ping = clock.monotonic64() - start
         --if player.ping > 20000000ULL then
            actions[ip] = action
         --end
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
         if action == 'hit' then -- hit
            if near_action ~= 'squ' then -- squat
               near_player.health = near_player.health - 1
               near_player.affect = 'hit'
            end
         elseif action == 'hoo' then -- hooking
            if near_action ~= 'jum' then -- jump
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