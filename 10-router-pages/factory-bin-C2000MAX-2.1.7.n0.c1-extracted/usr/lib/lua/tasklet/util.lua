
--
-- Copyright (C) spyder
--


local tasklet = require 'tasklet'
require 'tasklet.channel.stream'

-- DNS resolve function.
-- It blocks the current task instead of the process.
function tasklet.getaddrbyname(hostname, sec)
	local ch = tasklet.create_execl_channel(function ()
		for _, addr in ipairs(netdb.getaddrbyname(hostname) or NULL) do 
			print(addr)
		end
	end)
	local t = {}
	local line = ch:read(nil, sec)
	while line do
		table.insert(t, line)
		line = ch:read(nil, sec)
	end
	ch:close()
	return t
end

return tasklet
