require "irc"

-- Lua 5.1 compatibility:
if _VERSION == "Lua 5.1" then
	function table.pack(a, ...)
		if not a then
			return { }
		else
			local t = table.pack(...)
			table.insert(t, 1, a)
			return t
		end
	end

	function table.unpack(t, n)
		n = n or 1
		if n > #t then
			return
		end
		if n == #t then
			return t[n]
		else
			return t[n], table.unpack(t, n + 1)
		end
	end
end

local sqlite3 = require "sqlite3"
local sleep = require "socket".sleep
local http_server = require "http.server"
local http_headers = require "http.headers"

local cfg = dofile("config.lua")

if not cfg then
	print("Failed to initialize logger: no config.lua present!")
	return
end

DB = sqlite3.open(arg[1] or cfg.database or "chatlog.db3")

do
	local name = DB:first_row [[
		SELECT name
			FROM sqlite_master
			WHERE type='table' AND name='chatlog'
	]]
	if not name or name == "" then
		DB:exec [[
			CREATE TABLE `chatlog` (
				`channel`	TEXT NOT NULL,
				`nick`	TEXT NOT NULL,
				`message`	TEXT NOT NULL,
				`timestamp`	DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		);
		]]
	end
end

IRC = irc.new(cfg.botname or {
	nick = "zfx-logger-v3",
	username = "zfx-logger",
	realname = "log.mq32.de"
})

CHANNELS = { }
STORAGE  = { }
QUIT     = false

local get_log_stmt = DB:prepare [[
	SELECT nick, message FROM chatlog WHERE channel = :channel ORDER BY timestamp DESC LIMIT 20
]]
function LOG(chan)
	local log = { }

	for row in get_log_stmt:bind{channel=chan}:rows(query) do
		log[#log + 1] = {
			sender = row.nick,
			message = row.message
		}
	end

	return log
end

local log_msg_stmt = DB:prepare [[
	INSERT INTO chatlog (channel, nick, message)
		VALUES (:channel, :nick, :message)
]]
IRC:hook("OnChat", function(_user, _channel, _message)
	local function process(user, channel, message)
		-- if private chat and message is not a command
		if channel == IRC.nick and message:sub(1,1) ~= "!" then
			message = "!" .. message
		end

		print(("[%s] %s: %s"):format(channel, user.nick, message))

		if message == "!reload" then
			local success, errmsg = pcall(function()
				command = { }
				dofile "parse-cmd.lua"
				dofile "commands.lua"
				dofile "http.lua"
				print "reloaded"
			end)
			if not success then
				print("Failed to reload:")
				print(errmsg)
			end
		elseif channel:sub(1,1) ~= "#" and message == "!restart" then
			QUIT = true
		elseif message:sub(1,1) == '!' then
			parse_and_exec_cmd(user, channel, message)
		end
		if channel:sub(1,1) == "#" and message:sub(1,1) ~= "!" then
			log_msg_stmt:bind{ channel=channel, nick=user.nick, message=message}:exec()
		end
	end
	local success, errmsg = pcall(process, _user, _channel, _message)
	if not success then
		print("error in OnChat: ", errmsg)
	end
end)

IRC:hook("OnJoin", function(user, channel)
	CHANNELS[channel] = CHANNELS[channel] or { }
	CHANNELS[channel][user] = true
	print(("%s joined %s"):format(user.nick, channel))
end)

IRC:hook("OnPart", function(user, channel)
	CHANNELS[channel] = CHANNELS[channel] or { }
	CHANNELS[channel][user] = true
	print(("%s left %s"):format(user.nick, channel))
end)




print("Loading command parser")
dofile("parse-cmd.lua")

command = { }

print("Loading commands")
dofile("commands.lua")

print("Loading http handler")
dofile("http.lua")

print("Starting HTTP server")
HTTP = assert(http_server.listen {
	host = cfg.http_server or "localhost";
	port = cfg.http_port or 8080;
	onstream = function(myserver, stream)
		HTTP_reply(myserver, stream)
	end;
	onerror = function(myserver, context, op, err, errno) -- luacheck: ignore 212
		local msg = op .. " on " .. tostring(context) .. " failed"
		if err then
			msg = msg .. ": " .. tostring(err)
		end
		assert(io.stderr:write(msg, "\n"))
	end;
})

-- Manually call :listen() so that we are bound before calling :localname()
assert(HTTP:listen())
do
	local bound_port = select(3, HTTP:localname())
	assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end

print("Connecting...")
IRC:connect(cfg.irc_server, cfg.irc_port)


IRC:send(("MODE %s +B"):format(IRC.nick))

for _,chan in ipairs(cfg.channels) do
	print("Joining " .. chan .. "...")
	IRC:join(chan)
end

print("Ready")

while not QUIT do
	IRC:think()
	HTTP:step(0.01)
	sleep(0.01)
end

IRC:disconnect("Restarting...");
DB:close()


--[[
CREATE TABLE `chatlog` (
		`channel`	TEXT NOT NULL,
		`nick`	TEXT NOT NULL,
		`message`	TEXT NOT NULL,
		`timestamp`	DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
]]
