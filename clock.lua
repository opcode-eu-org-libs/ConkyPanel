-- SPDX-FileCopyrightText: Robert Ryszard Paciorek <rrp@opcode.eu.org>
-- SPDX-License-Identifier: MIT

require "cairo"
require "utils"

local stdlib = require "posix.stdlib"
local time   = require "posix.time"

local tz = 1

-------------------------
---   Cairo widgets   ---
-------------------------

function clock_set_tz(timezone_idx)
	tz = timezone_idx
	stdlib.setenv("TZ", TIME_ZONES[tz], 1)
	time.tzset()
end

function clock_event(event)
	if (event.y > CLOCK.Y and event.x > CLOCK.X and event.x < CLOCK.X + CLOCK.W) then
		if event.type == "mouse_move" then
			tooltip_show(CLOCK, event.x, event.y)
		elseif event.type == "button_up" then
			tooltip_until = os.time() + 2
			os.execute([[
				cmd='yad --calendar --show-weeks --posx=-55 --posy=-60 --on-top --undecorated --no-buttons --skip-taskbar --title ConkyCalendarWidget'
				pids=$(ps -o pid= -C "$cmd")
				if [ "$pids" != "" ]; then
					kill $pids
				else
					$cmd &
				fi
			]])
		elseif event.type == "mouse_scroll" then
			if event.direction == "up" then
				tz = tz + 1
				if (tz > TIME_ZONES_MAX) then tz = 1 end
			else
				tz = tz - 1
				if (tz == 0) then tz = TIME_ZONES_MAX end
			end
			clock_set_tz(tz)
		end
		return true
	end
	return false
end

function draw_clock(cr, conf)
	cairo_set_source_rgba(cr, 1, 1, 1, 1)
	cairo_select_font_face(cr, "DejaVu Sans", 0, 1)
	
	cairo_set_font_size(cr, 18)
	local str = os.date("%T %Z")
	cairo_text_extents(cr, str, te)
	local align = math.max(0, math.abs(math.floor((conf.W - te.width) / 2)))
	local y = conf.Y + te.height
	cairo_move_to(cr, conf.X+align, y)
	cairo_show_text(cr, str)
	
	cairo_set_font_size(cr, 14)
	local str = os.date("%F")
	cairo_text_extents(cr, str, te)
	local align = math.max(0, math.abs(math.floor((conf.W - te.width) / 2)))
	y = y + te.height+7
	cairo_move_to(cr, conf.X+align, y)
	cairo_show_text(cr, os.date(str))
	
	local str = os.date("%A")
	cairo_text_extents(cr, str, te)
	local align = math.max(0, math.abs(math.floor((conf.W - te.width) / 2)))
	y = y + te.height+3
	cairo_move_to(cr, conf.X+align, y)
	cairo_show_text(cr, os.date(str))
end

function draw_clock_tooltip(cr, conf)
	if not is_tooltip_visible(conf) then return end
	
	local tm = time.localtime(time.time())
	local str = {
		time.strftime("%B", tm),
		time.strftime("%j day of year, %u day of %V week", tm),
		time.strftime("epoch: %s,   TZ: UTC%z", tm),
	}
	
	tooltip_draw(cr, str)
end
