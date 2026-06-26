-- SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
-- SPDX-License-Identifier: MIT

-------------------------
---   Configuration   ---
-------------------------

HIST_SIZE = 80
HWMON_CONFIG = nil -- use default (output of `hwmon_config.sh` script)
NETDEV = "eno1"
DISKDEV = "sda"

TIME_ZONES = {"UTC", "Europe/Warsaw"}
TIME_ZONES_MAX = 2

TOOLTIP_DELAY = 0.8


TERM  = { W=132,  H=55, X=2,               Y=0,  TOOLTIP_TIME=16 }
MEM   = { W=72,   H=55, X=TERM.X+TERM.W+1,  Y=0,  TOOLTIP_TIME=9 }
DISK  = { W=72,   H=55, X=MEM.X+MEM.W+1,    Y=0,  TOOLTIP_TIME=100 }
CPU   = { W=72,   H=55, X=DISK.X+DISK.W+1,  Y=0,  TOOLTIP_TIME=100 }
GPU   = { W=72,   H=55, X=CPU.X+CPU.W+1,    Y=0,  TOOLTIP_TIME=5 }
NET   = { W=72,   H=55, X=GPU.X+GPU.W+1,    Y=0,  TOOLTIP_TIME=8 }
CLOCK = { W=155,  H=52, X=NET.X+NET.W+5,    Y=0,  TOOLTIP_TIME=5 }

WIN_WIDTH = 669
WIN_HEIGHT = 58
WIN_HEIGHT_BIG_MODE = 400

function set_default_font(cr, bold)
	cairo_select_font_face(cr, "DejaVu Sans Mono", 0, bold)
	cairo_set_font_size(cr, 13)
end

------------------------
---   Dependencies   ---
------------------------

require "cairo"
pcall(require, 'cairo_xlib') -- for cairo_xlib_surface_create in conky 1.24.0

package.path = debug.getinfo(1).source:match("@?(.*/)") .. "?.lua;" .. package.path


require "clock"
require "stats"
require "hwmon"
require "utils"
require "data_history"

------------------------
---   Globals   ---
------------------------

updates = -1
te = nil

------------------------------------
---   Windows resize functions   ---
------------------------------------

-- conky_window.width / height are not update while resize window via xdotool, so keep own globals
win_width = nil
win_height = nil

xdg_session_type = os.getenv("XDG_SESSION_TYPE")

---------------------------------
---   Conky hooks functions   ---
---------------------------------

function conky_draw()
	if conky_window == nil then return end
	
	local new_updates = tonumber(conky_parse("${updates}"))
	if new_updates ~= updates then
		updates = new_updates
		-- update stats 2 times per second
		-- (this function is called 4 times per second due to update clock)
		if updates%2 == 0 then
			local full_update = (updates%4 == 0)
			update_data(full_update)
			if full_update then
				if (tooltip_visible == CPU) then
					update_cpu_tooltip()
				end
			end
		end
	end
	
	-- set window size
	if updates < 3 then
		resize_window(WIN_WIDTH, WIN_HEIGHT)
	end
	
	-- cairo surface
	local cs = nil
	local cs_own = false
	if conky_surface then
		cs = conky_surface() -- for conky 1.24.0
	end
	if cairo_xlib_surface_create and not cs then
		cs = cairo_xlib_surface_create( conky_window.display, conky_window.drawable, conky_window.visual, win_width, win_height ) -- for conky 1.18.3 and 1.24.0 on X11 due to BUG https://github.com/brndnmtthws/conky/issues/2388
		cs_own = true
	end
	
	if not cs then
		print("ERROR: No drawing surface")
		return
	end
	
	local cr = cairo_create(cs)
	
	te = cairo_text_extents_t:create()
	tolua.takeownership(te)
	
	cairo_set_antialias(cr, 1)
	
	CLOCK.Y = win_height-CLOCK.H
	NET.Y = win_height-NET.H
	GPU.Y = NET.Y
	CPU.Y = NET.Y
	DISK.Y = NET.Y
	MEM.Y = NET.Y
	TERM.Y = NET.Y
	
	if win_height ~= WIN_HEIGHT then
		draw_big_window_widgets(cr)
	end
	
	draw_clock(cr, CLOCK)
	draw_in_out(cr, NET, hist_down, hist_up)
	draw_gpu(cr, GPU)
	draw_cpu(cr, CPU)
	draw_in_out(cr, DISK, hist_rd, hist_wr)
	draw_mem(cr, MEM)
	draw_term(cr, TERM)
	draw_clock_tooltip(cr, CLOCK)
	draw_in_out_tooltip(cr, NET, NETDEV .. " down", NETDEV .. " up", hist_down, hist_up)
	draw_gpu_tooltip(cr, GPU)
	draw_cpu_tooltip(cr, CPU)
	draw_in_out_tooltip(cr, DISK, DISKDEV .. " read", DISKDEV .. " write", hist_rd, hist_wr)
	draw_mem_tooltip(cr, MEM)
	draw_term_tooltip(cr, TERM)
	
	tolua.releaseownership(te)
	cairo_text_extents_t:destroy(te)
	
	cairo_destroy(cr)
	if cs_own then
		-- do not destroy result of conky_surface(), but destroy result of cairo_xlib_surface_create
		cairo_surface_destroy(cs)
	end
end

function conky_event_handler(event)
	if clock_event(event) then
		return true
	elseif event.type == "mouse_move" then
		if (event.y > NET.Y and event.x > NET.X and event.x < NET.X + NET.W) then
			tooltip_show(NET, event.x, event.y)
		elseif (event.y > GPU.Y and event.x > GPU.X and event.x < GPU.X + GPU.W) then
			tooltip_show(GPU, event.x, event.y)
		elseif (event.y > CPU.Y and event.x > CPU.X and event.x < CPU.X + CPU.W) then
			if tooltip_show(CPU, event.x, event.y) then
				update_cpu_tooltip()
			end
		elseif (event.y > MEM.Y and event.x > MEM.X and event.x < MEM.X + MEM.W) then
			tooltip_show(MEM, event.x, event.y)
		elseif (event.y > DISK.Y and event.x > DISK.X and event.x < DISK.X + DISK.W) then
			tooltip_show(DISK, event.x, event.y)
		elseif (event.y > TERM.Y and event.x > TERM.X and event.x < TERM.X + TERM.W) then
			tooltip_show(TERM, event.x, event.y)
		else
			tooltip_visible = nil
		end
-- TODO / WIP: BROKEN in 1.24 on X11, lack of xdotool on Wayland
-- 	elseif event.type == "button_up" then
-- 		if win_height == WIN_HEIGHT then
-- 			resize_window(WIN_WIDTH, WIN_HEIGHT_BIG_MODE)
-- 		else
-- 			resize_window(WIN_WIDTH, WIN_HEIGHT)
-- 		end
	else
		tooltip_visible = nil
	end
	return true
end

----------------
---   Init   ---
----------------

clock_set_tz(2)


-- TODO / WIP

function draw_big_window_widgets(cr)
	cairo_set_source_rgba(cr, 1, 1, 1, 1)
	cairo_move_to(cr, 0, 0)
	cairo_line_to(cr, 50, 50)
	cairo_stroke(cr)
end
