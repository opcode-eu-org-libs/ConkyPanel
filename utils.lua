-- SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
-- SPDX-License-Identifier: MIT

local time   = require "posix.time"

---------------------------------------------
---   Utils functions for Cairo widgets   ---
---------------------------------------------

function init_graph(cr, x, y, width, graph_h, text_offset)
	cairo_rectangle(cr, x, y, width+1, graph_h+text_offset)
	cairo_set_source_rgba(cr, 0.15, 0.15, 0.15, 0.6)
	cairo_fill(cr)
	
	cairo_set_source_rgba(cr, 1, 1, 1, 1)
	cairo_set_line_width(cr, 1)
	cairo_rectangle(cr, x, y, NET.W, graph_h)
	cairo_stroke(cr)
	
	return y + graph_h - 1
end

function draw_graph(cr, x, ybase, start_x_offset, graph_h, data, data_ptr, max_val, graph_step, line)
	if not graph_step then
		graph_step = 1
	end

	local scale = 1
	if max_val > 0 then
		scale = graph_h / max_val
	end
	
	local min_x_offset = math.max(start_x_offset - #data*graph_step + 1, 1)
	for i = start_x_offset, min_x_offset, -graph_step do
		local v = data[data_ptr] * scale
		if line and v > 0 then
			cairo_move_to(cr, x+i, ybase - v + 1)
		else
			cairo_move_to(cr, x+i, ybase)
		end
		cairo_line_to(cr, x+i, ybase - v)
		
		data_ptr = data_ptr - 1
		if data_ptr < 1 then data_ptr = #data end
	end
	
	cairo_stroke(cr)
end

tooltip_visible = nil
tooltip_timer = -1
tooltip_x = 0
tooltip_y = 0

function is_tooltip_visible(id)
	if (tooltip_visible ~= id) then
		return false
	end
	
	local t = get_time()
	if (tooltip_timer + TOOLTIP_DELAY > t) then
		return false
	end
	if (tooltip_timer + id.TOOLTIP_TIME < t) then
		tooltip_visible = nil
		return false
	end
	
	return true
end

function tooltip_show(id, x, y)
	tooltip_x = x
	tooltip_y = y
	if (tooltip_visible ~= id) then
		tooltip_visible = id
		tooltip_timer = get_time()
		return true
	end
	return false
end

function tooltip_draw(cr, str, colors, maxwidth, columns)
	local padding_h = 3
	local padding_w = 5
	local line_height = 16
	local line_margin = 4
	
	set_default_font(cr)
	
	if not maxwidth then
		maxwidth = 0
		for i, s in ipairs(str) do
			cairo_text_extents(cr, s, te)
			if te.width > maxwidth then maxwidth = te.width end
		end
	end
	local total_w = maxwidth + padding_w * 2
	local lines_count = #str
	if columns then lines_count = math.ceil(lines_count/columns) end
	local total_h = lines_count * line_height + padding_h * 2
	
	local x = math.max(2, tooltip_x - total_w)
	local y = math.max(1, tooltip_y - total_h/2)
	y = math.min(tooltip_visible.Y + tooltip_visible.H - total_h - 1, y)
	
	-- frame
	cairo_set_source_rgba(cr, 1, 1, 1, 0.8)
	cairo_set_line_width(cr, 2)
	draw_rounded_rect(cr, x, y, total_w, total_h, 5)
	cairo_stroke(cr)
	
	-- background
	cairo_set_source_rgba(cr, 0, 0, 0, 0.8)
	draw_rounded_rect(cr, x, y, total_w, total_h, 5)
	cairo_fill(cr)
	
	-- text
	cairo_set_source_rgba(cr, 1, 1, 1, 1)
	y = y + padding_h - line_margin
	for i, s in ipairs(str) do
		if colors then
			cairo_set_source_rgba(cr, colors[i][1], colors[i][2], colors[i][3], colors[i][4])
		end
		if not columns or i%columns == 1 then
			y = y + line_height
			cairo_move_to(cr, x + padding_w, y)
		else
			cairo_move_to(cr, x + padding_w + ((i-1)%columns) * maxwidth/columns, y)
		end
		cairo_show_text(cr, s)
	end
end

function draw_rounded_rect(cr, x, y, w, h, r)
	cairo_move_to(cr, x + r, y)
	cairo_line_to(cr, x + w - r, y)
	cairo_arc(cr, x + w - r, y + r, r, -math.pi/2, 0)
	cairo_line_to(cr, x + w, y + h - r)
	cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi/2)
	cairo_line_to(cr, x + r, y + h)
	cairo_arc(cr, x + r, y + h - r, r, math.pi/2, math.pi)
	cairo_line_to(cr, x, y + r)
	cairo_arc(cr, x + r, y + r, r, math.pi, 3*math.pi/2)
end

function cairo_show_text_on_center(cr, x, y, width, text)
	cairo_text_extents(cr, text, te)
	local align = math.max(0, math.abs(math.floor((width - te.width) / 2)))
	
	cairo_move_to(cr, x + align, y)
	cairo_show_text(cr, text)
end


----------------------
---   Mics utils   ---
----------------------

SURFIXES = {B=1, K=1024, M=1048576, G=1073741824}
function human_to_number(v)
	local s = v.sub(v, -1)
	return tonumber(v.sub(v, 1, -2)) * SURFIXES[s]
end

function format_float(f, p)
	s = string.sub(string.format("%f", f), 0, p)
	if string.sub(s, -1) == "." then s = string.sub(s, 1, -2) end
	return s
end

function number_to_human(v, s, p)
	if v > 1073741824 then
		v = v / 1073741824
		return format_float(v, p) .. "G"
	elseif v > 1048576 then
		v = v / 1048576
		return format_float(v, p) .. "M"
	elseif v > 1024 then
		v = v / 1024
		return format_float(v, p) .. "k"
	else
		return format_float(v, p) .. s
	end
end

function min_max_avg(data, data_ptr, data_len)
	local min = data[data_ptr]
	local max = data[data_ptr]
	local avg = 0
	for i = 1, data_len do
		if data[data_ptr] > max then max = data[data_ptr] end
		if data[data_ptr] < min then min = data[data_ptr] end
		avg = avg + data[data_ptr]
		
		data_ptr = data_ptr - 1
		if data_ptr < 1 then data_ptr = #data end
	end
	avg = avg / data_len
	return min, max, avg
end

function get_time()
	local tt = time.clock_gettime(time.CLOCK_REALTIME)
	return tt.tv_sec + tt.tv_nsec/1000000000
end

function resize_window(width, height)
	win_width = width
	win_height = height
	os.execute(
		"win_width=" .. tostring(win_width) .. "; win_height=" .. tostring(win_height) .. [[;
			xdotool getdisplaygeometry | (
				read dw dh
				w=$(xdotool search --class ConkyBottomPanel)
				xdotool windowsize $w $win_width $win_height
				xdotool windowmove $w $(($dw - $win_width)) $(($dh - $win_height))
			)
		]]
	)
end


---------------------------------
---   Conky text mode utils   ---
---------------------------------

function conky_oncenter(size,  ...)
	local out = conky_parse(table.concat({...}, " "))
	local pad = math.floor((size - out:len()) / 2)
	return string.rep(" ", math.max(0, pad)) .. out
end
