-- SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
-- SPDX-License-Identifier: MIT

--------------------------------
---   Read stats functions   ---
--------------------------------

-- Conky don't allow get raw value (i.e. net speed in bytes/s or cpu usage as float) so we use own implementations

local last_active = 0
local last_idle = 0

function get_cpu_stats()
	local active = 0
	local idle = 0
	
	io.input("/proc/stat")
	local stat1 = io.read("*line")
	io.input():close()
	
	local stat2 = string.gmatch(stat1, "%S+")
	local n = 0
	for v in stat2 do
		if n == 4 or n == 5 then
			idle = idle + tonumber(v)
		elseif n > 0 then
			active = active + tonumber(v)
		end
		n = n + 1
	end
	
	local a = active - last_active
	local i = idle - last_idle
	last_active = active
	last_idle = idle
	
	return (a)/(a+i) * 100 
end

local last_down = {}
local last_up = {}

function get_net_stats(calls_per_sec, net_dev)
	local down = 0
	local up = 0
	
	io.input("/proc/net/dev")
	local stat1
	while true do
		stat1 = io.read("*l")
		if stat1 == nil then return end
		if string.match(stat1, "^ *" .. net_dev .. ":") then break end
	end
	io.input():close()
	
	local stat2 = string.gmatch(stat1, "%S+")
	local n = 0
	for v in stat2 do
		if n == 1 then
			down = tonumber(v)
		elseif n == 9 then
			up = tonumber(v)
			break
		end
		n = n + 1
	end
	
	local d = (down - last_down[net_dev]) * calls_per_sec
	local u = (up - last_up[net_dev]) * calls_per_sec
	last_down[net_dev] = down
	last_up[net_dev] = up
	
	return d, u
end

function init_net_stats(net_dev)
	last_down[net_dev] = 0
	last_up[net_dev] = 0
	get_net_stats(0, net_dev)
end

local last_rd = {}
local last_wr = {}

function get_disk_stats(calls_per_sec, disk_dev)
	local rd = 0
	local wr = 0
	
	io.input("/proc/diskstats")
	local stat1
	while true do
		stat1 = io.read("*l")
		if stat1 == nil then return end
		
		local stat2 = string.gmatch(stat1, "%S+")
		local n = 0
		local has_data = false
		for v in stat2 do
			if n == 2 and v ~= disk_dev then
				break
			elseif n == 5 then
				rd = tonumber(v)
			elseif n == 9 then
				wr = tonumber(v)
				has_data = true
				break
			end
			n = n + 1
		end
		if has_data then break end
	end
	io.input():close()
	
	local r = (rd - last_rd[disk_dev]) * calls_per_sec * 512
	local w = (wr - last_wr[disk_dev]) * calls_per_sec * 512
	last_rd[disk_dev] = rd
	last_wr[disk_dev] = wr
	
	return r, w
end

function init_disk_stats(disk_dev)
	last_rd[disk_dev] = 0
	last_wr[disk_dev] = 0
	get_disk_stats(0, disk_dev)
end

function get_mem_stats()
	local f = 0
	local a = 0
	
	io.input("/proc/meminfo")
	local stat1
	local m = 3
	while true do
		stat1 = io.read("*l")
		if stat1 == nil then return end
		local stat2 = string.gmatch(stat1, "%S+")
		local id = stat2()
		if id == "MemTotal:" then
			mem_total = tonumber(stat2())
			m = m -1
		elseif id == "MemFree:" then
			f = tonumber(stat2())
			m = m -1
		elseif id == "MemAvailable:" then
			a = tonumber(stat2())
			m = m -1
		end
		if m == 0 then break end
	end
	io.input():close()
	
	return mem_total-a, mem_total-f
end
