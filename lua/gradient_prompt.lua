
-- prompt generation script meant for st+mksh

-- colors

local TEXT = {255,192,128}

local START_BG = {128, 128, 128}
local PWD_BG = {0, 128, 255}
local SPACE_BG = {192, 192, 192}
local END_BG = {128, 0, 196}

-- grab args

local pwd, status, cols = ...

-- safety wrapper
local function prompt()
	
	local cols = math.tointeger(cols)
	
	-- queue output
	local buffer = {}

	-- pattern to set 24-bit colors on st, quoted for mksh
	local char_pattern = "\a\x1b[%d;2;%d;%d;%dm\a"
	local reset_pattern = "\a\x1b[0m\a"

	-- pattern to indicate using BEL to quote escape sequences in mksh
	local quote_pattern = "\a\r"

	-- helper funcs

	local function blend(a, b, t)
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
		return utf8.len(str) or #str
	end

	-- assemble prompt

	local pos
	local pwd_start_bg = START_BG
	local pwd_end_bg = PWD_BG
	local pwd_len = len(pwd)

	local left_len = pwd_len

	local space_start_bg = SPACE_BG
	local space_end_bg = END_BG
	local space_len = cols - left_len

	buffer[0] = quote_pattern

	pos = 0
	for char in pwd:gmatch(utf8.charpattern) do
		color_putchar(char, TEXT, blend(pwd_start_bg, pwd_end_bg, pos/pwd_len))
		pos = pos + 1
	end
	
	--color_putchar("▒", pwd_end_bg, space_start_bg)

	for t = 1, space_len do
		color_putchar(" ", TEXT, blend(space_start_bg, space_end_bg, t/space_len))
	end

	buffer[#buffer + 1] = reset_pattern
	buffer[#buffer + 1] = "\n$"

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
