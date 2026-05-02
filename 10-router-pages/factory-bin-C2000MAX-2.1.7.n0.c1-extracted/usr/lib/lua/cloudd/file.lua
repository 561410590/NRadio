local c_debug = require "cloudd.debug"

module (..., package.seeall)

local function unused()
    -- for avoiding unused warning...
end

local function apply_uci_file(sfile, sfile_data, mode, action, dfile)
	local tmpname
	local tmpfile
	local oscmd = nil

	unused(sfile)
	tmpname = os.tmpname()

	if mode == "m" then
		oscmd = "uci -m -f " .. tmpname .. " import " .. dfile
	elseif mode == "o" then
		oscmd = "uci -f " .. tmpname .. " import " .. dfile
	end

	if oscmd == nil then
		return -1
	end

	tmpfile = io.open(tmpname, "w+")

	if tmpfile == nil then
		return -1
	end

	tmpfile:write(sfile_data)
	tmpfile:close()

	c_debug.logger(oscmd)

	os.execute(oscmd)
	os.execute("uci commit")
	oscmd = "uci_fxiup " .. dfile
	os.execute(oscmd)
	if action ~= nil then
		os.execute(action)
	end

	os.remove(tmpname)

	return 0
end

local function apply_normal_file(sfile, sfile_data, mode, action, dfile)
	local d_file = nil

	unused(sfile)
	if mode == "a" then
		d_file = io.open(dfile, "a+")
	elseif mode == "o" then
		d_file = io.open(dfile, "w+")
	end

	if d_file == nil then
		return -1
	end

	d_file:write(sfile_data)
	d_file:close()

	if action ~= nil then
		os.execute(action)
	end

	return 0

end

local function apply_file(sfile, sfile_data, type, mode, action, dfile)
	if sfile == nil or sfile_data == nil or dfile == nil then
		c_debug.logger("file: file empty")
		return -1
	end

	if type == "u" then
		return apply_uci_file(sfile, sfile_data, mode, action, dfile)
	else
		return apply_normal_file(sfile, sfile_data, mode, action, dfile)
	end
end

function cloudd_apply_file(json_data)
	local c_json = require "cjson"
	local m_md5 = require "md5"
	local json_tab = c_json.decode(json_data)
	local ret

	if json_tab == nil then
		c_debug.logger("file: json format error")
		return -1
	end

	if json_tab["data"] == nil or json_tab["sfile"] == nil or json_tab["dfile"] == nil then
		c_debug.logger("file: json format error(lost key)")
		return -1
	end

	local f_md5 = m_md5.sumhexa(json_tab["data"])
	if json_tab["md5"] ~= f_md5 then
		c_debug.logger("file: data md5 error")
		return -1
	end

	ret = apply_file(json_tab["sfile"],
					 json_tab["data"],
					 json_tab["type"],
					 json_tab["mode"],
					 json_tab["action"],
					 json_tab["dfile"])
	return ret
end

function cloudd_push_file(sfile, type, mode, action, dfile, did, proto)
	local tab = {}
	local file = io.open(sfile, "r")

	if file ~= nil then
		local m_md5 = require "md5"
		local f_data = file:read("*a")
		local f_data_md5 = m_md5.sumhexa(f_data)
		local cloudd = require "cloudd.cloudd"
		local topic = "file"

		tab["sfile"] = sfile
		tab["type"] = type
		tab["mode"] = mode
		tab["action"] = action
		tab["dfile"] = dfile
		tab["data"] = f_data
		tab["md5"] = f_data_md5

		file:close()

		-- send to specific client
		cloudd.cloudd_send(did, topic, tab, proto, 0)
	end
end
