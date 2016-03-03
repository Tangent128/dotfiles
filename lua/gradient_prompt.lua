
-- prompt generation script meant for st+mksh

-- grab args

local opts = {
	pwd = "",
	seed = "0",
	cols = "40",
	status = "0"
}

for i, arg in pairs{...} do
	local key, value = arg:match "^([^=]*)=(.*)"
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
	
	local function t()
		return pos/(cols-1)
	end

	local function wave()
		return math.sin(t() * math.pi)
	end
	
	local function sine(t)
		local value = (math.sin(t * math.pi * 2) + 1) / 2
		return math.ceil(value * 255)
	end
	
	local function sinebow(t)
		return {sine(t + 1/3), sine(t + 0/3), sine(t + 2/3)}
	end
	
	local function background()
		--local hue = blend(sinebow(color_root + 0.4), sinebow(color_root + 0.6), wave())
		return blend({0,0,0}, sinebow(color_root), wave()/3 + 1/16)
		--return sinebow(color_root + t())
	end

	local function foreground()
		--return sinebow(color_root + t()/2)
		--return {255,255,255}
		return blend({255,255,255}, sinebow(color_root + t() + 0.5), wave()/2)
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
			math.ceil(a[1]*it + b[1]*t),
			math.ceil(a[2]*it + b[2]*t),
			math.ceil(a[3]*it + b[3]*t),
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

	local clip_pwd = opts.pwd:sub(utf8.offset(opts.pwd, -cols) or 1)
	local pwd_len = len(clip_pwd)
	
	buffer[1] = quote_pattern
	pad((cols - pwd_len) >> 1, foreground, background)
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
