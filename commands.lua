local http = require("socket.http")

local helplist = { }
local function define_help(cmd, ...)
	helplist[cmd] = table.pack(...)
end

local function spacetext(...)
	local t = table.pack(...)
	local r = ""
	for i=1,#t do
		r = r .. " " .. tostring(t[i])
	end
	return r:sub(2)
end

define_help("help",
	"help       - shows all available commands",
	"help [cmd] - shows a description for the given command."
)
function command.help(cmd)
	if not cmd then
		context:echo("Available commands are:")
		local list = ""
		for cmd in pairs(command) do
			list = list .. ", " .. tostring(cmd)
		end
		context:echo(list:sub(3))
	elseif cmd == "me" then
		context:self("can't help you right now.")
	elseif helplist[cmd] then
		local l = helplist[cmd]
		for i=1,#l do
			context:privmsg(l[i])
		end
	else
		context:privmsg("No help for command " .. cmd .. ".")
	end
end

function command.echo(...)
	local t = table.pack(...)
	local list = ""
	for _,cmd in ipairs(t) do
		list = tostring(list) .. ", '" .. tostring(cmd) .. "'"
	end
	context:echo(list:sub(3))
end

define_help("fortune", "fortune - gives a small, random piece of text.")
function command.fortune()
	local function capture(cmd, raw)
		local f = assert(io.popen(cmd, 'r'))
		local s = assert(f:read('*a'))
		f:close()
		if raw then return s end
		s = string.gsub(s, '^%s+', '')
		s = string.gsub(s, '%s+$', '')
		s = string.gsub(s, '[\n\r]+', ' ')
		return s
	end

	context:echo(capture("fortune -s"))
end

define_help("rng",
	"rng                 - gives a random number between 0.0 and 1.0",
	"rng [top]           - gives a random integer between 1 and [top].",
	"rng [low] [high]    - gives a random integer between [low] and [high].",
	"rng [str1] [str2] … - gives a random item from the list of strings."
)
function command.rng(a, b, ...)
	if not tonumber(a) then
		local t = { a, b, ... }
		context:echo(t[math.random(#t)])
	else
		if a and b then
			context:echo(math.random(a, b))
		elseif a and not b then
			context:echo(math.random(a))
		else
			context:echo(math.random())
		end
	end
end

command.rnd = command.rng

--[[
define_help("join",
	"join [chan] - let's the bot join a the channel [chan]."
)
function command.join(chan)
	IRC:join(chan)
end
--]]

--[[
define_help("part",
	"part [chan] - let's the bot part the channel [chan]."
)
function command.part(chan)
	IRC:part(chan)
end
--]]

local function make_giver(cmd, text)
	define_help(cmd,
		("%s        - The bot gives the invoker a %s"):format(cmd, cmd),
		("%s [nick] - The bot gives [nick] a %s"):format(cmd, cmd)
	)
	command[cmd] = function (user)
		local msg = text
		if type(msg) == "table" then
			msg = msg[math.random(#msg)]
		end
		if not user then
			context:self(msg:format(context.user.nick))
		else
			context:self(msg:format(user))
		end
	end
end

make_giver("coffee", "gives %s a cup of coffee!")
make_giver("tea", {
	"gives %s a cup of finest tea!",
	"gives %s a cup of earl gray!",
	"gives %s a cup of green tea!",
})
make_giver("cookie", {
	"gives %s a cookie!",
	"gives %s a chocolate cookie!",
	"gives %s an oat cookie!",
	"gives %s a cookie with smarties!",
})
make_giver("beer", "gives %s a jug of beer!")
make_giver("mate", "gives %s a bottle of ClubMate!")

define_help("suicide",
	"suicide - Helps a user with their suicide"
)
function command.suicide()
	context:self("watches ", context.user.nick, " kill himself...")
end

define_help("say",
	"(from private chat) say [chan] ... - Sends the Message ... to channel [chan]",
	"(from public chat)  say ...        - Sends the Message ... to the current channel"
)
function command.say(...)
	local t = table.pack(...)
	if #t == 0 then
		return
	end

	print("Channel=", context.channel)
	print("First=", t[1])
	local target = context.channel
	if context.channel:sub(1,1) ~= "#" then
		target = t[1]
		table.remove(t, 1)
	end

	print("Send to", target)

	local list = ""
	for _,cmd in ipairs(t) do
		list = tostring(list) .. " " .. tostring(cmd)
	end
	if #list > 0 then
		context:sendto(target, list:sub(2))
	end
end

define_help("lua",
	"say ... - Executes the Lua code ..."
)
function command.lua()
	context:echo("Did you really think i would do something THAT stupid?")
end

define_help("info",
	"info - Prints information about this bot"
)
function command.info()
	context:echo("This bot was created for #zfx on irc.euirc.net by MasterQ32.")
	context:echo("Read the logs at https://log.mq32.de")
end

define_help("remember",
	"remember               - Remembers the last told sentence in the current channel by the key of the user who wrote it.",
	"remember [key]         - Remembers the last told sentence in the current channel by the key [key].",
	"remember [key] [value] - Remembers [value] by the key [key]."
)
function command.remember(where, ...)
	local what = spacetext(...)

	if #what > 0 then
		STORAGE[where] = what
	else
		if not where then
			where = context.log[2].sender
		end
		STORAGE[where] = context.log[2].message
	end
end

define_help("forget",
	"forget [key] - Forgets the value remembered by key [key]."
)
function command.forget(where)
	STORAGE[where] = nil
end

define_help("recall",
	"recall [key] - Recalls the value remembered by key [key]."
)
function command.recall(where)
	if not where then
		where = context.log[1].sender
	end

	local what = STORAGE[where]
	if what then
		context:echo(where, ": ", what)
	else
		context:echo("I cannot remember ", where)
	end
end


define_help("memories",
	"memory - Lists all available memories"
)
function command.memories()
	local list = ""
	for key in pairs(STORAGE) do
		list = tostring(list) .. ", '" .. tostring(key) .. "'"
	end
	context:echo("Available memories are:")
	context:echo(list:sub(3))
end


define_help("log",
	"log            - Resends the last 5 messages.",
	"log [n]        - Resends the last [n] messages for the current channel.",
	"log [chan]     - Resends the last 5 messages for the channel [chan].",
	"log [chan] [n] - Resends the last [n] messages for the channel [chan]."
)
function command.log(chan, n)
	local log = context.log

	if chan and n then
		log = LOG(chan)
		n = tonumber(n)
		if not n then
			return
		end
	elseif chan then
		n = tonumber(chan)
		if not n then
			log = LOG(chan)
			n = 5
		end
	else
		n = 5
	end

	for i=n,1,-1 do
		if log[i] then
			context:privmsg(log[i].sender, ": ", log[i].message)
		else
			break
		end
	end
end
