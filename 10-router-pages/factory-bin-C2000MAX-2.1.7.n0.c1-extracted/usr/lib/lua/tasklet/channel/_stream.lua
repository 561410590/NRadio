
--
-- Copyright (C) spyder
--


local tasklet = require 'tasklet'

local function make_countdown_read(self, tm_total)
	local tm_baseline, tm_elapsed = tasklet.now, 0
	return function (n)
		local sec = tm_total 
		if sec > 0 then
			tm_elapsed = tasklet.now - tm_baseline
			if tm_elapsed >= tm_total then
				return nil, errno.ETIMEDOUT
			end
			sec = tm_total - tm_elapsed
		end
		return self:read(n, sec)
	end
end

local function make_countdown_write(self, tm_total)
	local tm_baseline, tm_elapsed = tasklet.now, 0
	return function (data)
		local sec = tm_total 
		if sec > 0 then
			tm_elapsed = tasklet.now - tm_baseline
			if tm_elapsed >= tm_total then
				return nil, errno.ETIMEDOUT
			end
			sec = tm_total - tm_elapsed
		end
		return self:write(data, sec)
	end
end

function tasklet._stream_channel_prototype()
	return {
		make_countdown_read = make_countdown_read,
		make_countdown_write = make_countdown_write,
	}
end

return tasklet
