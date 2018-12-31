local function patch(text)
	return text:gsub("%$%((%w+)%)", function(i)
		return STORAGE[i] or "$("..i..")"
	end):gsub("%$(%w+)", function(i)
		return STORAGE[i] or "$("..i..")"
	end)
end

function parse_and_exec_cmd(user, channel, message)
	context = {
		user = user,
		channel = channel,
		message = message,
		log = LOG(channel)
	}
	local function packtext(...)
		local t = table.pack(...)
		local r = ""
		for i=1,#t do
			r = r .. tostring(t[i])
		end
		return r
	end

	local function verify(str, errLevel)
		if str:find("^:") or str:find("%s%z") then
			error(("malformed parameter '%s' to irc command"):format(str), errLevel)
		end

		return str
	end

	function context:echo(...)
		local r = packtext(...)
		if channel == IRC.nick then
			-- we are in our private chat
			-- echo to the sender
			IRC:sendChat(user.nick, r)
		else
			IRC:sendChat(channel, r)
			DO_LOG {
				channel=channel,
				nick=IRC.nick,
				message=r
			}
		end
	end

	function context:self(...)
		local r = packtext(...)
		if channel == IRC.nick then
			-- we are in our private chat
			-- echo to the sender
			IRC:send("PRIVMSG %s :\001ACTION %s\001", verify(user.nick, 3), r)
		else
			IRC:send("PRIVMSG %s :\001ACTION %s\001", channel, r)
			DO_LOG {
				channel=channel,
				nick=IRC.nick,
				message=("\001ACTION %s\001"):format(r)
			}
		end
	end

	function context:privmsg(...)
		local r = packtext(...)
		IRC:sendChat(user.nick, r)
	end

	function context:sendto(target, msg)
		IRC:sendChat(target, msg)
		if target:sub(1,1) == "#" then
			DO_LOG { channel=target, nick=IRC.nick, message=msg}
		end
	end

	-- remove '!' if exists
	if message:sub(1,1) == "!" then
		message = message:sub(2)
	end

	local list = { }
	while #message > 0 do
		message = message:gsub("^%s*", ""):gsub("%s*$", "")
		if #message == 0 then
			break
		end
		local part
		if message:sub(1,1) == '"' then
			part = message:match('^"[^"]*"')
			if part then
				part = part:sub(2, #part - 1)
				message = message:sub(#part + 3)
			else
				break
			end
		else
			part = message:match("^%S+")
			if part then
				message = message:sub(#part + 1)
			else
				break
			end
		end
		list[#list + 1] = patch(part)
	end

	local cmd = list[1]
	if cmd then
		table.remove(list, 1)

		if cmd and command[cmd] then
			local success, errmsg = pcall(function()
				command[cmd](table.unpack(list))
			end)
			if not success then
				if errmsg then
					context:echo(errmsg)
				else
					context:echo("I can't let you do that, ", context.user.nick)
				end
			end
		else
			context:echo("Command " .. cmd .. " not found!")
		end
	end
end
