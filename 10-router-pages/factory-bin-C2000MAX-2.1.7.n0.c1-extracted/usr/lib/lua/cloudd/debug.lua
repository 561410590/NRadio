local nixio = require "nixio"
local fs = require "nixio.fs"

local io = io

local debug_file = "/var/log/cloudd.log"

local debug_flag = "/var/run/cloudd-debug"

module ("cloudd.debug")

--- 向debug_file中打log
 -- @string str
function logger(str)
	-- NOTICE: truncate the log file when it needs rotation
	local fp = io.open(debug_file, "a+")
	if fp:seek("end") >= 2048 * 10 then
		fp:close()
		fp = io.open(debug_file, "w")
	end
	if fp then
		fp:write(str)
		fp:write("\n")
		fp:flush()
		fp:close()
	end
end

--- 向syslog中打log
 -- @string type log type
 -- @string data
 -- @int force(force log to syslog)
function syslog(type, data, force)
  local cloudd_log_tag = "cloudd_lua"

  if fs.access(debug_flag) ~= nil or force == 1 then
    nixio.openlog(cloudd_log_tag)
    nixio.syslog(type,data)
    nixio.closelog()
  end
end
