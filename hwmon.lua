-- SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
-- SPDX-License-Identifier: MIT

require "cairo"
require "hwmon_read"
require "utils"

-------------------------
---   Cairo widgets   ---
-------------------------

local graph_h = 40
local text_offset = 13

function draw_gpu(cr, conf)
	local ybase = init_graph(cr, conf.X, conf.Y, conf.W, graph_h, text_offset)
	
	cairo_set_source_rgba(cr, 1.0, 0.25, 0, 1)
	draw_graph(cr, conf.X, ybase, conf.W, graph_h, hist_gpu, hist_ptr, 290)
	
	local usage_str = format_float(hist_gpu[hist_ptr], 4) .. "W"
	set_default_font(cr, 1)
	cairo_show_text_on_center(cr, conf.X, ybase + text_offset, conf.W, usage_str)
end

function draw_gpu_tooltip(cr, conf)
	if not is_tooltip_visible(conf) then return end
	
	min, max, avg = min_max_avg(hist_gpu, hist_ptr, conf.W)
	local str = {
		"min: " .. format_float(min, 4) .. "W  max: " .. format_float(max, 4) .. "W  avg: " .. format_float(avg, 4) .. "W",
	}
	tooltip_draw(cr, str)
end

function draw_term(cr, conf)
	set_default_font(cr)
	
	if hwmon.ram.temp.max > 50 then
		cairo_set_source_rgba(cr, 1.0, 0.2, 0.0, 1)
	else
		cairo_set_source_rgba(cr, 0.9, 0.9, 0.9, 1)
	end
	cairo_move_to(cr, conf.X, conf.Y+9)
	cairo_show_text(cr, "RAM: " .. tostring(hwmon.ram.temp.min) .. "°C  " .. tostring(hwmon.ram.temp.max) .. "°C")
	
	if hwmon.cpu.temp.max > 90 then
		cairo_set_source_rgba(cr, 1.0, 0.2, 0.0, 1)
	elseif hwmon.cpu.temp.max > 80 then
		cairo_set_source_rgba(cr, 0.9, 0.45, 0, 1)
	else
		cairo_set_source_rgba(cr, 0.9, 0.9, 0.9, 1)
	end
	cairo_move_to(cr, conf.X, conf.Y+23)
	cairo_show_text(cr, "CPU: " .. tostring(hwmon.cpu.temp.min) .. "°C  " .. tostring(hwmon.cpu.temp.max) .. "°C")
	
	if hwmon.gpu.temp.max > 90 then
		cairo_set_source_rgba(cr, 1.0, 0.2, 0.0, 1)
	else
		cairo_set_source_rgba(cr, 0.9, 0.9, 0.9, 1)
	end
	cairo_move_to(cr, conf.X, conf.Y+37)
	cairo_show_text(cr, "GPU: " .. tostring(hwmon.gpu.temp.min) .. "°C  " .. tostring(hwmon.gpu.temp.max) .. "°C")
	
	local mb_max = hwmon.mb.temp.max
	if hwmon.mdio.temp.c1.val > mb_max then
		mb_max = hwmon.mdio.temp.c1.val
	end
	if hwmon.mb.temp.max > 70 or hwmon.mdio.temp.c1.val > 90 then
		cairo_set_source_rgba(cr, 1.0, 0.2, 0.0, 1)
	else
		cairo_set_source_rgba(cr, 0.9, 0.9, 0.9, 1)
	end
	cairo_move_to(cr, conf.X, conf.Y+51)
	cairo_show_text(cr, " MB: " .. tostring(hwmon.mb.temp.min) .. "°C  " .. tostring(mb_max) .. "°C")
end

function draw_term_tooltip(cr, conf)
	if not is_tooltip_visible(conf) then return end
	
	local str = {
		"GPU: mem: " .. tostring(hwmon.gpu.temp.mem.val) .."°C  edge: " .. tostring(hwmon.gpu.temp.edge.val) .. "°C  junction: " .. tostring(hwmon.gpu.temp.junction.val) .. "°C"
			.. "     CPU: ".. tostring(hwmon.cpu.temp.ccd1.val) .. "°C  " .. tostring(hwmon.cpu.temp.ccd2.val) .. "°C  " .. tostring(hwmon.cpu.temp.gpu_edge.val) .. "°C  " .. tostring(hwmon.cpu.temp.ctl.val) .. "°C  ",
		"MDIO: " .. tostring(hwmon.mdio.temp.c1.val) .. "°C     SDA: " .. tostring(hwmon.disks.temp.sda.val) .. "°C"
			.. "     RAM: " .. tostring(hwmon.ram.temp.c1.val) .. "°C  " .. tostring(hwmon.ram.temp.c2.val) .. "°C",
		"MB: sysin: " .. tostring(hwmon.mb.temp.sysin.val) .."°C  cpuin: " .. tostring(hwmon.mb.temp.cpuin.val) .."°C  tsi0: " .. tostring(hwmon.mb.temp.tsi0.val) .. "°C aux: " .. tostring(hwmon.mb.temp.auxtin1.val) .. "°C  "
			.. tostring(hwmon.mb.temp.auxtin2.val) .. "°C  " .. tostring(hwmon.mb.temp.auxtin3.val) .. "°C  " .. tostring(hwmon.mb.temp.auxtin4.val) .. "°C  " .. tostring(hwmon.mb.temp.auxtin5.val) .. "°C",
	}
	tooltip_draw(cr, str)
end
