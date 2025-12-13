-- SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
-- SPDX-License-Identifier: MIT

require "stats_read"
require "hwmon_read"

---------------------------------
---   Stats collect globals   ---
---------------------------------

if not HIST_SIZE then
	HIST_SIZE = 30
end
HIST_INOUT_SIZE = HIST_SIZE // 2

mem_total = 1
hist_cpu = {}
hist_mem = {}
hist_mem_with_buf = {}
hist_down = {}
hist_up = {}
hist_rd = {}
hist_wr = {}
hist_ptr = 1
hist_ptr_inout = 1

-----------------------------------
---   Stats collect functions   ---
-----------------------------------

function update_data(full)
	hist_ptr = hist_ptr + 1
	if hist_ptr > HIST_SIZE then hist_ptr = 1 end
	hist_cpu[hist_ptr] = get_cpu_stats()
	hist_mem[hist_ptr], hist_mem_with_buf[hist_ptr] = get_mem_stats()
	if full then
		hist_ptr_inout = hist_ptr_inout + 1
		if hist_ptr_inout > HIST_INOUT_SIZE then hist_ptr_inout = 1 end
		-- in/out (network and disks) data is collected twice less frequently,
		-- because we the same width of graph and place up and down data on the same graph
		hist_down[hist_ptr_inout], hist_up[hist_ptr_inout] = get_net_stats(1, NETDEV)
		hist_rd[hist_ptr_inout], hist_wr[hist_ptr_inout] = get_disk_stats(1, DISKDEV)
		
		-- sensors data are read twice less frequently also, but with some exception ...
		read_hwmon_all()
		hist_gpu[hist_ptr] = hwmon.gpu.power.ppt.fval
	else
		hist_gpu[hist_ptr] = read_hwmon(hwmon.gpu.power.ppt) * 0.000001
	end
	
end

function init_stats()
	-- init history tables
	for i = 1, HIST_SIZE do
		hist_cpu[i] = 0
		hist_mem[i] = 0
		hist_mem_with_buf[i] = 0
	end
	for i = 1, HIST_INOUT_SIZE do
		hist_down[i] = 0
		hist_up[i] = 0
		hist_rd[i] = 0
		hist_wr[i] = 0
	end
	
	-- init cpu and net stat
	get_cpu_stats()
	init_net_stats(NETDEV)
	init_disk_stats(DISKDEV)
end

----------------
---   Init   ---
----------------

init_stats()
init_hwmon()
