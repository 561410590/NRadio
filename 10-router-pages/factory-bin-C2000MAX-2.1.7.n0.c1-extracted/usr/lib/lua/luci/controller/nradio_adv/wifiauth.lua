-- Copyright 2017-2018 NRadio

module("luci.controller.nradio_adv.wifiauth", package.seeall)

local util = require "luci.util"
local http = require "luci.http"
local sys  = require "luci.sys"
local uci  = require "luci.model.uci"
local uci = uci.cursor()
local msg_sms_code = {
    SMS_SUCCESS = 0,
    SMS_ERR_PARAM = 1,
    SMS_ERR_NET = 2,
    SMS_ERR_MAX = 3,
    SMS_ERR_BUSY = 4,
    SMS_ERR_OTHER = 5,
}

local msg_auth_code = {
    AUTH_SUCCESS = 0,
    AUTH_ERR_PARAM = 1,
    AUTH_ERR_NET = 2,
    AUTH_ERR_OTHER = 3,
    AUTH_ERR_INNER = 4
}
local Telecom_COMPANY_TYPE=0
local Mobile_COMPANY_TYPE=1
function index()
    local uci  = require "luci.model.uci"
    local uci = uci.cursor()
    local nr = require "luci.nradio"
    local fs = require "nixio.fs"
    local portal = uci:get("luci", "main", "portal") or "0"
    local wifiauth_auto = uci:get("luci", "main", "wifiauth_auto") or "1"

    page = entry({"nradioadv", "system", "auth"}, template("nradio_adv/wifiauth"), _("WiFi Auth"), 100, true)
    page.icon = 'nradio-wifiauth'
    
    entry({"nradioadv", "auth", "keep"}, call("action_keep_info"), nil, nil, true)
    entry({"nradioadv", "auth", "device"}, call("action_device_info"), nil, nil, true)
    entry({"nradioadv", "auth", "auth"}, function () return action_request('auth') end, nil, nil, true)
    entry({"nradioadv", "auth", "sms"}, function () return action_request('sms') end, nil, nil, true)
    entry({"nradioadv", "auth", "enabled"}, call("action_disabled"), nil, nil, true)
    entry({"nradioadv", "auth"}, template("nradio_adv/wifiauth"), _("WiFi Auth"), 10, true)

    if fs.access("/usr/sbin/terminal_trackd") then
	    entry({ "authcheck"}, template("nradio_authcheck/index"), _("Status"), 45, true)
        if portal ~= "1" and wifiauth_auto == "0" then
            page.show = false
        else
            page.show = true
        end
    else
        entry({ "authcheck"}, call("redirect_page"),nil, nil, true)
    end
	entry({ "authcheck","success"}, template("nradio_authcheck/success"), _("Status"), 45, true)
	entry({ "authcheck","fail"}, template("nradio_authcheck/fail"), _("Status"), 45, true)
	entry({ "authcheck","getmsg"}, call("get_cloud_msg"), nil, nil, true).leaf = true
	entry({ "authcheck","checkmsg"}, call("check_cloud_msg"), nil, nil, true).leaf = true
end

function redirect_page()
    luci.http.redirect(luci.dispatcher.build_url("nradio/qsetup"))
end

local function http_header_md5(imei)
    local nixio = require "nixio"
    local util = require "luci.util"
    

    local factory = 'cmiot' --可换配置写
    local pname = uci:get("oem", "board", "pname") or ""
    local cmd = string.format("echo -n '%s' | md5sum | awk '{print $1}' | tr -d '\r\n'", factory .. '.' .. pname)
    local key =  util.exec(cmd)

    if key and #key == 32 then
        key = string.sub(key, math.max(1, #key - 15))
        cmd = string.format("echo -n '%s' | md5sum | awk '{print $1}' | tr -d '\r\n'", key .. '.' .. imei)
        local signature = util.exec(cmd)
        nixio.syslog("err","signature:"..signature)
        if signature and #signature == 32 then
            return signature
        end
    end
    return nil
end

local function param_format(body)
    local nixio = require "nixio"
    local util = require "luci.util"
    local target_param=""

    local keys = {}
    for k in pairs(body) do
        table.insert(keys, k)
    end

    table.sort(keys)
    for _,k in ipairs(keys) do
        if #target_param > 0 then
            target_param=target_param.."&"
        end
        target_param=target_param..k.."="..body[k]
    end
    return target_param
end
local function header_format(header)
    local nixio = require "nixio"
    local target_param=""

    for key,val in pairs(header) do
        target_param=target_param.." -H '"..key..":"..val.."'"
    end
    return target_param
end
local function http_post(url, body, name,header)
    local nixio =  require "nixio"
    local util = require "luci.util"
    local cjson = require "cjson.safe"
    local uci = uci.cursor()
    local cmd = ""
    local header_str = ""
    local body_json = ""
    local method = ""
    if body then
        body_json = " -d '"..cjson.encode(body).."'"
        method=" -X POST "
    end
    if header then
        header_str = header_format(header)
    end
    if name ~= "onecyber" then
        cmd = "curl -k "..method .."'"..url .. "' -H 'accept: */*' -H 'Content-Type: application/json;charset=utf-8'" ..header_str.. body_json
    else
        local cellular_prefix,cellular_default = luci.nradio.get_cellular_prefix()
        local imei = uci:get("cellular_init", cellular_default, "imei") or ''
        local sign = http_header_md5(imei)                
        local imei_header = string.format(" -H 'imei:%s'", imei)
        local sign_header = string.format(" -H 'Ocb-Device-Register-Signature:%s'", sign)

        cmd = "curl -k ".. method .."'"..url.. "' -H 'accept: */*' -H 'Content-Type: application/json;charset=utf-8'" .. imei_header .. sign_header ..header_str.. body_json
    end

    local response = util.exec(cmd)
    nixio.syslog("err",cmd)
    if response then
        nixio.syslog("err",response)
    end
    --response="{\"status\": \"0\",\"message\": \"成功\",\"result\": {\"codeToken\": \"c7cfbfc4ef2a4394966802041c3e3c4a\"}}"
    
    return cjson.decode(response)
end

function action_all_data()
    local util = require "luci.util"
    local cur_work = uci:get("luci", "main", "portal") or "0"
    local return_data = util.ubus("terminal","all") or { list={},enabled=0}
    return_data.enabled = tonumber(cur_work)
    return return_data
end
function action_disabled()
    local nr = require "luci.nradio"
	local enabled = luci.http.formvalue("enabled") or nil;
	local cur_work = uci:get("luci", "main", "portal") or "0"
	if enabled and cur_work ~= enabled then
		uci:set("luci", "main", "portal", enabled)
		uci:commit("luci")
        os.execute("/etc/init.d/terminal_trackd restart >/dev/null 2>/dev/null")
        os.execute("/etc/init.d/wifidogx restart >/dev/null 2>/dev/null")
        if tonumber(enabled) ~= 1 then
                os.execute("wifidogx -D >/dev/null 2>/dev/null")
        end
	end

	nr.luci_call_result({code = 0})
end
function action_device_info()
    local nr = require "luci.nradio"
	local data = action_all_data()
	nr.luci_call_result(data)
end
function action_keep_info()
    local nr = require "luci.nradio"
    util.ubus("terminal", "keep")
    nr.luci_call_result({code=0})
end
function action_request(flag)
    local http = require "luci.http"
    local cjson = require "cjson.safe"
    local nixio = require "nixio"
    local ltn12 = require "luci.ltn12"
    local uci = uci.cursor()
    local return_code = {}
    http.prepare_content("application/json")
    local info_json = http.content()

    if not info_json then
        http.write_json({success = false})
        return nil
    end

    local info_table = cjson.decode(info_json)

    if info_table and #info_table ~= 0 then
        http.write_json({success = false})
        return nil
    else
        local msg = nil
        if flag == 'auth' then   
            msg = auth_msg(info_table)
            return_code = deal_auth_response(msg)
            if return_code.code == msg_sms_code.SMS_SUCCESS then
                local rv = util.ubus("terminal", "authed",{mac=info_table.mac,type=1}) or { code = -1}
                if not rv or rv.code ~= 0 then
                     return_code.code = msg_auth_code.AUTH_ERR_INNER
                end
            end
        elseif flag == 'sms' then
            msg = get_msg_code(info_table)
            return_code = deal_msg_response(msg,info_table,true)
        end

        http.write_json(return_code)
    end
end

function get_base_data()
    local mac =  uci:get('oem', 'board', 'id')
    mac = string.gsub(mac, ':', '-')
    return {mac=mac}
end
function telecom_sign(params,body,secret,timestr)
    local key =  util.exec("echo -n '"..params..body .. secret..timestr.."' | md5sum | awk '{print $1}'|tr -d '\r\n'|hexdump -v -e '/1 \"%.2x\"'")
    return key
end
function auth_msg(info_table)
    local url = ''
    local body ={ }
    local base_table = get_base_data()
    local name = ""
    local rv = util.ubus("terminal", "token") or {}
    local header = nil
    body = {
        mac = base_table.mac,
        terminalMac = string.gsub(info_table.mac, ':', '-'):upper(),
        phoneNum = info_table.phone,
        verifyCode = info_table.code
    }
    
    if rv.code == 0 then
        url = rv.terminal_auth
        body["iccid"] = rv.iccid

        if rv.company == Telecom_COMPANY_TYPE then
            local os = require "os"
            local timestr=os.date("%Y%m%d%H%M%S")
            local params=""
            local sign=""
            body["mac"] = string.gsub(body["mac"], '-', ''):lower()
            body["terminalMac"] = string.gsub(body["terminalMac"], '-', ''):lower()
            params=param_format(body)            
            sign=telecom_sign(params,"",rv.app_secret,timestr)
            header = {Timestamp=timestr,AppKey=rv.appid,Sign=sign}
            url=url.."?"..params
            body=nil
        else
            if rv.type ~= 2 then
                body["token"] = rv.token
                body["transid"] = rv.transid
            end
        end
        name = rv.name

    else
        return nil
    end
    return http_post(url, body, name,header)
end
function get_msg_code(info_table)
    local url = ''
    local body ={ }
    local base_table = get_base_data()
    local name = ""
    local header = nil
    body = {
        mac = base_table.mac,
        phoneNum = info_table.phone,
        terminalMac = string.gsub(info_table.mac, ':', '-'):upper()
    }
    local rv = util.ubus("terminal", "token") or {}
    if rv.code == 0 then
        url = rv.send_sms
        name = rv.name
        body["iccid"] = rv.iccid

        if rv.company == Telecom_COMPANY_TYPE then
            local os = require "os"
            local timestr=os.date("%Y%m%d%H%M%S")
            local params=""
            local sign=""
            body["mac"] = string.gsub(body["mac"], '-', ''):lower()
            body["terminalMac"] = string.gsub(body["terminalMac"], '-', ''):lower()
            params=param_format(body)
            sign=telecom_sign(params,"",rv.app_secret,timestr)
            header = {Timestamp=timestr,AppKey=rv.appid,Sign=sign}
            url=url.."?"..params
            body=nil
        else
            if rv.type ~= 2 then
                body["token"] = rv.token
                body["transid"] = rv.transid
            end
        end
    else
        return nil
    end

    return http_post(url, body, name,header)
end

function deal_msg_response(msg,info_table,try)
    local return_code = {code=msg_sms_code.SMS_ERR_OTHER}
    if not msg then
        return_code.code = msg_sms_code.SMS_ERR_OTHER
    else
        if msg.status == '0' or msg.code == '0' or (msg.reqStatus and msg.reqStatus.code == '0000') then
            return_code.code = msg_sms_code.SMS_SUCCESS
        elseif msg and msg.reqStatus and msg.reqStatus.code == '0000' then
            return_code.code = msg_sms_code.SMS_SUCCESS
        elseif msg and (msg.code == '902017' or msg.status == '902017') then
            return_code.code = msg_sms_code.SMS_ERR_MAX
            if msg.message then
               return_code.detail = msg.message
            end
        elseif msg and (msg.code == '902016' or msg.status == '902016' or msg.code == '900016' or msg.status == '900016') then
            return_code.code = msg_sms_code.SMS_ERR_BUSY
        elseif msg and (msg.code == '12004' or msg.status == '12004') then
            if msg.message then
                return_code.detail = msg.message
            end
            if try then
                local rv = util.ubus("terminal", "token",{action="refresh"}) or {}            
                nixio.nanosleep(4)
                msg = get_msg_code(info_table)
                return deal_msg_response(msg,info_table)
            end
        elseif msg and msg.code == '11011' then
            if msg.message then
                return_code.detail = msg.message
            end
        end
        if msg.reqStatus and msg.reqStatus.detail and (type(msg.reqStatus.detail) == "string")  and #msg.reqStatus.detail > 0 then
            return_code.detail = msg.reqStatus.detail
        elseif msg.reqStatus and msg.reqStatus.message and (type(msg.reqStatus.message) == "string")  and #msg.reqStatus.message > 0 then
            return_code.detail = msg.reqStatus.message
        elseif msg and msg.message and (type(msg.message) == "string")  and #msg.message > 0 then
            return_code.detail = msg.message
        end
    end
    return return_code
end

function deal_auth_response(msg)
    local return_code = {code=msg_auth_code.SMS_ERR_OTHER}
    if not msg then
        return_code.code = msg_auth_code.AUTH_ERR_OTHER
    else
        if msg.status == '0' or msg.code == '0' or (msg.reqStatus and msg.reqStatus.code == '0000') then
            return_code.code = msg_auth_code.AUTH_SUCCESS
        else
            if msg.reqStatus and msg.reqStatus.detail and (type(msg.reqStatus.detail) == "string") and #msg.reqStatus.detail > 0 then
                return_code.detail = msg.reqStatus.detail
            elseif msg.reqStatus and msg.reqStatus.message and (type(msg.reqStatus.message) == "string")  and #msg.reqStatus.message > 0 then
                return_code.detail = msg.reqStatus.message
            elseif msg.message and (type(msg.message) == "string")  and #msg.message > 0 then
                return_code.detail = msg.message
            end
        end
    end
    return return_code
end
function get_cloud_msg()
    local phone_num = http.formvalue("phone_num")
    local mac = http.formvalue("mac")
	local return_code = {code=msg_sms_code.SMS_ERR_OTHER}
    local info_table = {phone_num="",mac=""}
    local msg = nil

    info_table.phone = phone_num
    info_table.mac = mac

    if not info_table.phone or #info_table.phone == 0 then
        return_code.code = msg_sms_code.SMS_ERR_PARAM
    end
    if not info_table.mac or #info_table.mac == 0 then
        return_code.code = msg_sms_code.SMS_ERR_PARAM
    end

    if return_code.code ~= msg_sms_code.SMS_ERR_PARAM then
        msg = get_msg_code(info_table)
    end

    return_code = deal_msg_response(msg,info_table,true)

	luci.nradio.luci_call_result(return_code)
end
function check_cloud_msg()
    local lan_section = uci:get("network", "globals", "default_lan") or "lan"
    local localip = uci:get("network", lan_section, "ipaddr") or '192.168.66.1'
    local phone_num = http.formvalue("phone_num")
	local phone_msg = http.formvalue("phone_msg")
    local mac = http.formvalue("mac")

	local return_code = {code=msg_auth_code.SMS_ERR_OTHER}
    local info_table = {phone_num="",mac="",code=""}
    local msg = nil

    info_table.phone = phone_num:gsub("[;'\\\"]", "")
    info_table.mac = mac:gsub("[;'\\\"]", "")
    info_table.code = phone_msg:gsub("[;'\\\"]", "")

    if not info_table.phone or #info_table.phone == 0 then
        return_code.code = msg_auth_code.AUTH_ERR_PARAM
    end
    if not info_table.mac or #info_table.mac == 0 then
        return_code.code = msg_auth_code.AUTH_ERR_PARAM
    end
    if not info_table.code or #info_table.code == 0 then
        return_code.code = msg_auth_code.AUTH_ERR_PARAM
    end
    if return_code.code ~= msg_auth_code.AUTH_ERR_PARAM then
        msg = auth_msg(info_table)
        return_code = deal_auth_response(msg)
        if return_code.code == msg_sms_code.SMS_SUCCESS then
            local rv = util.ubus("terminal", "authed",{mac=mac}) or { code = -1}
            if rv and rv.code ==  0 then
                if msg.result and msg.result.codeToken then
                    return_code.session = msg.result.codeToken
                elseif msg.data and msg.data.codeToken then
                    return_code.session = msg.data.codeToken
                end
            else
                return_code.code = msg_auth_code.AUTH_ERR_INNER
            end
        end
    end    

    if return_code.code == msg_auth_code.AUTH_SUCCESS and not return_code.session then
	    return_code.session = sys.uniqueid(16)
    end
	luci.nradio.luci_call_result(return_code)
end


