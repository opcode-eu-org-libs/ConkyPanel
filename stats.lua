-- SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
-- SPDX-License-Identifier: MIT

require "cairo"
require "stats_read"
require "utils"

-------------------------
---   Cairo widgets   ---
-------------------------

local graph_h = 40
local text_offset = 13

function draw_in_out(cr, conf, in_data, out_data)
	local ybase = init_graph(cr, conf.X, conf.Y, conf.W, graph_h, text_offset)
	
	local min_in, max_in, avg_in = min_max_avg(in_data, hist_ptr_inout, conf.W//2)
	local min_out, max_out, avg_out = min_max_avg(out_data, hist_ptr_inout, conf.W//2)
	
	local max_in_str = number_to_human(max_in, "B", 3)
	local max_out_str = number_to_human(max_out, "B", 3)
	
	set_default_font(cr, 1)
	cairo_text_extents(cr, max_in_str, te)
	local tw2 = te.width + 8
	cairo_text_extents(cr, max_out_str, te)
	local tw3 = tw2 + te.width
	local align = math.max(0, math.abs(math.floor((conf.W - tw3) / 2)))
	
	cairo_set_source_rgba(cr, 0.9, 0.9, 0, 1)
	draw_graph(cr, conf.X, ybase, conf.W, graph_h, in_data, hist_ptr_inout, max_in, 2)
	cairo_move_to(cr, conf.X + align, ybase + text_offset )
	cairo_show_text(cr, max_in_str)
	
	cairo_set_source_rgba(cr, 0, 0.9, 0.9, 1)
	draw_graph(cr, conf.X, ybase, conf.W-1, graph_h, out_data, hist_ptr_inout, max_out, 2)
	cairo_move_to(cr, conf.X + align+tw2, ybase + text_offset )
	cairo_show_text(cr, max_out_str)
end

function draw_in_out_tooltip(cr, conf, labe_in, label_out, in_data, out_data)
	if not is_tooltip_visible(conf) then return end
	
	local min_in, max_in, avg_in = min_max_avg(in_data, hist_ptr_inout, conf.W//2)
	local min_out, max_out, avg_out = min_max_avg(out_data, hist_ptr_inout, conf.W//2)
	
	local str = {
		labe_in,
		"cur: " .. number_to_human(in_data[hist_ptr_inout], "", 5) .. "B/s",
		"min: " .. number_to_human(min_in, "", 5) .. "B/s",
		"max: " .. number_to_human(max_in, "", 5) .. "B/s",
		"avg: " .. number_to_human(avg_in, "", 5) .. "B/s",
		label_out,
		"curr " .. number_to_human(out_data[hist_ptr_inout], "", 5) .. "B/s",
		"min: " .. number_to_human(min_out, "", 5) .. "B/s",
		"max: " .. number_to_human(max_out, "", 5) .. "B/s",
		"avg: " .. number_to_human(avg_out, "", 5) .. "B/s",
	}
	local colors = {
		{0.9, 0.9, 0, 1},
		{0.9, 0.9, 0, 1},
		{0.9, 0.9, 0, 1},
		{0.9, 0.9, 0, 1},
		{0.9, 0.9, 0, 1},
		{0, 0.9, 0.9, 1},
		{0, 0.9, 0.9, 1},
		{0, 0.9, 0.9, 1},
		{0, 0.9, 0.9, 1},
		{0, 0.9, 0.9, 1},
	}
	
	tooltip_draw(cr, str, colors, 608, 5)
end

function draw_cpu(cr, conf)
	local ybase = init_graph(cr, conf.X, conf.Y, conf.W, graph_h, text_offset)
	
	cairo_set_source_rgba(cr, 0.9, 0.45, 0, 1)
	draw_graph(cr, conf.X, ybase, conf.W, graph_h, hist_cpu, hist_ptr, 100)
	
	local usage_str = format_float(hist_cpu[hist_ptr], 4) .. "%"
	set_default_font(cr, 1)
	cairo_show_text_on_center(cr, conf.X, ybase + text_offset, conf.W, usage_str)
end

local cpu_top = {}

function update_cpu_tooltip()
	cpu_top = {
		conky_parse("${top name 1} ${top pid 1} ${top cpu 1}"),
		conky_parse("${top name 2} ${top pid 2} ${top cpu 2}"),
		conky_parse("${top name 3} ${top pid 3} ${top cpu 3}"),
	}
end

function draw_cpu_tooltip(cr)
	if not is_tooltip_visible(CPU) then return end
	
	min, max, avg = min_max_avg(hist_cpu, hist_ptr, CPU.W)
	local str = {
		cpu_top[1] .. "   | min: " .. format_float(min, 4) .. "%",
		cpu_top[2] .. "   | max: " .. format_float(max, 4) .. "%",
		cpu_top[3] .. "   | avg: " .. format_float(avg, 4) .. "%",
	}
	
	tooltip_draw(cr, str)
end

function draw_mem(cr, conf)
	local ybase = init_graph(cr, conf.X, conf.Y, conf.W, graph_h, text_offset)
	
	cairo_set_source_rgba(cr, 0.2, 0.5, 0, 1)
	draw_graph(cr, conf.X, ybase, conf.W, graph_h, hist_mem_with_buf, hist_ptr, mem_total, 1, true)
	
	cairo_set_source_rgba(cr, 0.6, 1.0, 0.012, 1)
	draw_graph(cr, conf.X, ybase, conf.W, graph_h, hist_mem, hist_ptr, mem_total)
	
	local usage_str = number_to_human(hist_mem[hist_ptr]*1024, "B", 4)
	set_default_font(cr, 1)
	cairo_show_text_on_center(cr, conf.X, ybase + text_offset, conf.W, usage_str)
end

function draw_mem_tooltip(cr, conf)
	if not is_tooltip_visible(conf) then return end
	
	min, max, avg = min_max_avg(hist_mem, hist_ptr, conf.W)
	local str = {
		"Used (with cache, ...): " .. number_to_human(hist_mem_with_buf[hist_ptr]*1024, "B", 6),
		"",
		"Used: " .. number_to_human(hist_mem[hist_ptr]*1024, "B", 6),
		"Total: " .. number_to_human(mem_total*1024, "B", 6),
		"min: " .. number_to_human(min*1024, "B", 6) .. " max: " .. number_to_human(max*1024, "B", 6) .. " avg: " .. number_to_human(avg*1024, "B", 6),
	}
	local colors = {
		{0.2, 0.5, 0, 1},
		{0.2, 0.5, 0, 1},
		{0.6, 1.0, 0.012, 1},
		{0.7, 0.7, 0.7, 1},
		{0.6, 1.0, 0.012, 1},
	}
	
	tooltip_draw(cr, str, colors, nil, 2)
end

