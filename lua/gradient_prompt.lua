
-- prompt generation script meant for st+mksh

-- grab args

local opts = {
	pwd = "",
	seed = "0",
	cols = "40",
	status = "0",
	host_red = 0,
	host_green = 0,
	host_blue = 0,
	host = ""
}

for i, arg in pairs{...} do
	local key, value = arg:match "^([^=]*)=(.+)"
	if key then
		opts[key] = value
	end
end

-- safety wrapper
local function prompt()
	
	local cols = math.tointeger(opts.cols)
	local pos = 0
	
	-- color functions
	
	math.randomseed(math.tointeger(opts.seed))
	-- throw away a few random numbers for better mixing
	math.random() math.random() math.random()
	
	-- limit text color to more readable part of spectrum
	local color_root = math.random() --* 2/3 + 1/3
	
	local blend
	local ceil = math.ceil
	
	local function t()
		return pos/(cols-1)
	end

	local function wave()
		return math.sin(t() * math.pi)
	end
	
	local function sine(t)
		local value = (math.sin(t * math.pi * 2) + 1) / 2
		return ceil(value * 255)
	end
	
	local function sinebow(t)
		return {sine(t + 1/3), sine(t + 0/3), sine(t + 2/3)}
	end
	
	local host_color = {
		math.tointeger(opts.host_red),
		math.tointeger(opts.host_green),
		math.tointeger(opts.host_blue)
	}
	
	local function background()
		local fade = wave()/3 + 1/16
		local color = sinebow(color_root)
		local margin_color = {0,0,0}

		if t() < 0.5 and opts.host_red then
			color = blend(host_color, color, t() * 2)
			fade = 1/3 + 1/16
		end

		return blend(margin_color, color, fade)
	end

	local function foreground()
		return blend({255,255,255}, sinebow(color_root + t() + 0.5), wave()/2)
	end
	
	local function host_foreground()
		return blend({255,255,255}, host_color, 1/2)
	end
	
	-- queue output
	local buffer = {}

	-- pattern to set 24-bit colors on st, quoted for mksh
	local char_pattern = "\a\x1b[%d;2;%d;%d;%dm\a"
	local reset_pattern = "\a\x1b[0m\a"

	-- pattern to indicate using BEL to quote escape sequences in mksh
	local quote_pattern = "\a\r\a\x1b[1m\a"

	-- helper funcs

	function blend(a, b, t)
		local it = 1 - t
		return {
			ceil(a[1]*it + b[1]*t),
			ceil(a[2]*it + b[2]*t),
			ceil(a[3]*it + b[3]*t),
		}
	end

	local function color_putchar(char, fgcolor, bgcolor)
		buffer[#buffer + 1] = char_pattern:format(38, fgcolor[1], fgcolor[2], fgcolor[3])
		buffer[#buffer + 1] = char_pattern:format(48, bgcolor[1], bgcolor[2], bgcolor[3])
		buffer[#buffer + 1] = char
	end

	local function len(str)
		return utf8.len(str)
	end
	
	local function write(str, foreground, background)
		for char in str:gmatch(utf8.charpattern) do
			color_putchar(char, foreground(), background())
			pos = pos + 1
		end
	end
	
	local function pad(count, foreground, background)
		for t = 1, count do
			color_putchar(" ", foreground(), background())
			pos = pos + 1
		end
	end
	
	-- assemble prompt
	
	local space = cols
	
	local clip_pwd = opts.pwd:sub(utf8.offset(opts.pwd, -space) or 1)
	local pwd_len = len(clip_pwd)
	space = space - pwd_len
	
	local clip_host = space > 0 and opts.host:sub(utf8.offset(opts.host, -space) or 1) or ""
	local host_len = len(clip_host)
	space = space - host_len
	
	buffer[1] = quote_pattern
	
	write(clip_host, host_foreground, background)
	
	pad(space // 2, foreground, background)
	write(clip_pwd, foreground, background)
	pad(cols - pos, foreground, background)
	
	buffer[#buffer + 1] = reset_pattern
	-- print prompt

	local output = table.concat(buffer)
	io.write(output)

end

-- backup prompt for old Lua versions or bad inputs
local function backup_prompt()
	if opts.status == "0" then
		io.write(opts.pwd.." ▙ ")
	else
		io.write(opts.pwd.." "..opts.status.." ")
	end
	return
end

local ok, err = pcall(prompt)
if err then
	print(err)
	backup_prompt()
end
