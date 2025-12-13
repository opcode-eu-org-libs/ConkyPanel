-- SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
-- SPDX-License-Identifier: MIT

-------------------------
---   hwmon globals   ---
-------------------------

hwmon = {}
hist_gpu = {}

if not HWMON_CONFIG then
	HWMON_CONFIG = "sh " .. debug.getinfo(1).source:match("@?(.*/)") .. "hwmon_config.sh"
	-- this is shell script to execute via io.popen
	-- it should print one hwmon point per line in format: `a.b.c  path` where:
	--   - `a.b.c` identified point and will be converted to nested tables in `hwmon` (as `hwmon.a.b.c`)
	--     - `a` is group id (like gpu or cpu)
	--     - `b` is point type (can be any string, but only `temp` and `power` are supported by `read_hwmon_all()` function)
	--     - `c` is (inside group) sensor id
	--  - `path` is path to file used to get point value
end

-----------------------------------
---   hwmon support functions   ---
-----------------------------------

function init_hwmon()
	local paths = io.popen(HWMON_CONFIG)
	while true do
		entry1 = paths:read("*l")
		if entry1 == nil then break end
		
		-- split to a.b.c notation key and path
		local entry2 = string.gmatch(entry1, "%S+")
		local k = entry2()
		local v = entry2()
		
		-- convert a.b.c notation into nested tables
		local ct = hwmon
		local kk = string.gmatch(k, "[^.]*")
		for x in kk do
			if not ct[x] then ct[x] = {} end
			ct = ct[x]
		end
		ct["path"] = v
	end
	
	-- init history tables
	for i = 1, HIST_SIZE do
		hist_gpu[i] = 0
	end
end

function read_hwmon_all(full)
	for _, dev in pairs(hwmon) do
		read_hwmon_group(dev.temp, 0.001)
		read_hwmon_group(dev.power, 0.000001)
	end
end

function read_hwmon_group(group, scale)
	if not group then return end
	local min = 1000
	local max = -1000
	for n, sensor in pairs(group) do
		if type(sensor) == "table" and sensor.path then
			local v = read_hwmon(sensor) * scale
			sensor.fval = v
			sensor.val = math.floor(v)
			if v > max then max = v end
			if v < min then min = v end
		end
	end
	group.fmax = max
	group.max = math.floor(max)
	group.fmin = min
	group.min = math.floor(min)
end

function read_hwmon(p)
	io.input(p.path)
	local v = io.read("*l")
	io.input():close()
	return v
end
