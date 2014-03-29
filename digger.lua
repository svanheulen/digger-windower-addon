--[[
Copyright 2014 Seth VanHeulen

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

_addon.name = 'digger'
_addon.version = '1.1.0'
_addon.command = 'digger'
_addon.author = 'Seth VanHeulen'

defaults = {}
defaults.rank = 'amateur'
defaults.fatigue = {}
defaults.fatigue.date = os.date('%Y-%m-%d', os.time() + 32400)
defaults.fatigue.remaining = 100
defaults.accuracy = {}
defaults.accuracy.successful = 0
defaults.accuracy.total = 0

config = require('config')
settings = config.load(defaults)

area_delay = 60
area_delay_lag = 3
dig_delay = 15

fail_message_ids = {7032, 7191, 7195, 7205, 7213, 7224, 7247, 7253, 7533, 7679}
success_message_ids = {6379, 6393, 6406, 6552, 7372, 7687, 7712}
ease_message_ids = {7107, 7266, 7270, 7280, 7288, 7299, 7322, 7328, 7608, 7754}

-- binary helper functions

function string.unpack_uint16(str, i)
    return str:byte(i + 1) * 0x100 + str:byte(i)
end

function string.unpack_uint32(str, i)
    local num = str:byte(i + 3)
    num = num * 0x100 + str:byte(i + 2)
    num = num * 0x100 + str:byte(i + 1)
    return num * 0x100 + str:byte(i)
end

-- buff helper function

function get_chocobo_buff()
    for _,buff_id in pairs(windower.ffxi.get_player().buffs) do
        if buff_id == 252 then
            return true
        end
    end
    return false
end

-- inventory helper function

function get_gysahl_count()
    count = 0
    for _,item in pairs(windower.ffxi.get_items().inventory) do
        if item.id == 4545 and item.status == 0 then
            count = count + item.count
        end
    end
    return count
end

-- stats helper functions

function update_stats(count)
    today = os.date('%Y-%m-%d', os.time() + 32400)
    if settings.fatigue.date ~= today then
        settings.fatigue.date = today
        settings.fatigue.remaining = 100
    end
    if count < 1 then
        settings.accuracy.total = settings.accuracy.total + 1
    end
    if count < 0 then
        settings.accuracy.successful = settings.accuracy.successful + 1
    end
    settings.fatigue.remaining = settings.fatigue.remaining + count
    settings:save('all')
end

function display_stats()
    accuracy = (settings.accuracy.successful / settings.accuracy.total) * 100
    windower.add_to_chat(200, 'dig accuracy: %d%% (%d/%d), items until fatigued: %d, gysahl greens remaining: %d':format(accuracy, settings.accuracy.successful, settings.accuracy.total, settings.fatigue.remaining, get_gysahl_count()))
end

-- event callback functions

function check_zone_change(new_id, old_id)
    windower.send_command(string.format('timers c "Chocobo Area Delay" %d down', area_delay + area_delay_lag))
end

function check_incoming_chunk(id, original, modified, injected, blocked)
    if id == 47 and dig_delay > 0 then
        if windower.ffxi.get_player().id == original:unpack_uint32(5) then
            windower.send_command(string.format('timers c "Chocobo Dig Delay" %d down', dig_delay))
        end
    elseif id == 54 then
        message_id = original:unpack_uint16(11) % 0x8000
        for _,fail_message_id in pairs(fail_message_ids) do
            if message_id == fail_message_id then
                update_stats(0)
                display_stats()
            end
        end
    elseif id == 42 then
        message_id = original:unpack_uint16(27) % 0x8000
        for _,success_message_id in pairs(success_message_ids) do
            if message_id == success_message_id and get_chocobo_buff() == true then
                update_stats(-1)
                display_stats()
                return
            end
        end
        for _,ease_message_id in pairs(ease_message_ids) do
            if message_id == ease_message_id then
                update_stats(1)
            end
        end
    end
end

function set_dig_rank(rank)
    rank = rank:lower()
    if rank == 'amateur' then
        area_delay = 60
        dig_delay = 15
    elseif rank == 'recruit' then
        area_delay = 55
        dig_delay = 10
    elseif rank == 'initiate' then
        area_delay = 50
        dig_delay = 5
    elseif rank == 'novice' then
        area_delay = 45
        dig_delay = 0
    elseif rank == 'apprentice' then
        area_delay = 40
        dig_delay = 0
    elseif rank == 'journeyman' then
        area_delay = 35
        dig_delay = 0
    elseif rank == 'craftsman' then
        area_delay = 30
        dig_delay = 0
    elseif rank == 'artisan' then
        area_delay = 25
        dig_delay = 0
    elseif rank == 'adept' then
        area_delay = 20
        dig_delay = 0
    elseif rank == 'veteran' then
        area_delay = 15
        dig_delay = 0
    elseif rank == 'expert' then
        area_delay = 10
        dig_delay = 0
    else
        windower.add_to_chat(167, string.format('invalid digging rank: %s', rank))
        return false
    end
    windower.add_to_chat(200, string.format('setting digging rank to %s: area delay = %d seconds, dig delay = %d seconds', rank, area_delay, dig_delay))
    settings.rank = rank
    return true
end

function digger_command(...)
    if #arg == 1 and arg[1]:lower() == 'reset' then
        windower.add_to_chat(200, 'resetting dig accuracy statistics')
        settings.accuracy.successful = 0
        settings.accuracy.total = 0
        settings:save('all')
    elseif #arg == 2 and arg[1]:lower() == 'rank' then
        if set_dig_rank(arg[2]) == true then
            settings:save('all')
        end
    else
        windower.add_to_chat(167, 'usage: digger rank <rank>')
        windower.add_to_chat(167, '        digger reset')
    end
end

function digger_load()
    set_dig_rank(settings.rank)
end

-- register event callbacks

windower.register_event('zone change', check_zone_change)
windower.register_event('incoming chunk', check_incoming_chunk)
windower.register_event('addon command', digger_command)
windower.register_event('load', digger_load)
