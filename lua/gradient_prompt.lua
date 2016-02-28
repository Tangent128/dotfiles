
-- prompt generation script meant for st+mksh

-- grab args

local pwd, status, shell_id, cols = ...

-- safety wrapper
local function prompt()
	
	local cols = math.tointeger(cols)
	local pos = 0
	
	-- color functions
	
	math.randomseed(shell_id)
	math.random() math.random() math.random()
	local color_root = math.random()
	
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
		return blend({0,0,0}, sinebow(color_root + 0.4), wave()/3 + 1/16)
	end

	local function foreground()
		return sinebow(color_root)
	end
	
	-- queue output
	local buffer = {}

	-- pattern to set 24-bit colors on st, quoted for mksh
	local char_pattern = "\a\x1b[%d;2;%d;%d;%dm\a"
	local reset_pattern = "\a\x1b[0m\a"

	-- pattern to indicate using BEL to quote escape sequences in mksh
	local quote_pattern = "\a\r"

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

	local clip_pwd = pwd:sub(utf8.offset(pwd, -cols) or 1)
	local pwd_len = len(clip_pwd)
	
	buffer[0] = quote_pattern
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
	if status == 0 then
		io.write(pwd.." ▙ ")
	else
		io.write(pwd.." "..status.." ")
	end
	return
end

local ok, err = pcall(prompt)
if err then
	print(err)
	backup_prompt()
end
