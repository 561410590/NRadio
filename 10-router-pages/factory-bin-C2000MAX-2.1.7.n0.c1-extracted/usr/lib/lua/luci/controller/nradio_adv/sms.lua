module("luci.controller.nradio_adv.sms", package.seeall)

local uci = require "luci.model.uci".cursor()
local lng = require "luci.i18n"
local util = require "luci.util"
local nr = require "luci.nradio"
local nx = require "nixio"
local cjson = require "cjson.safe"
local http = require "luci.http"
local luapdu = require("luci.luapdu")

function index()
	if not luci.nradio.support_ims() then
		return
	end
	page = entry({"nradio", "cellular","sms"}, template("nradio_sms/index"), _("SMSTile"), 80, true)
	entry({"nradio", "cellular","sms", "model"},call("get_cellular_template"), nil, nil, true).leaf = true
	entry({"nradio", "cellular","sms", "list"}, call("action_sms_list_http"), nil, nil, true).leaf = true
	entry({"nradio", "cellular","sms", "del"}, call("action_sms_del"), nil, nil, true).leaf = true
	entry({"nradio", "cellular","sms", "send"}, call("action_sms_send"), nil, nil, true).leaf = true
	entry({"nradio", "cellular","sms", "resend"}, call("action_sms_resend"), nil, nil, true).leaf = true
	entry({"nradio", "cellular","sms", "force_ims"}, call("action_sms_force_ims"), nil, nil, true).leaf = true
	entry({"nradio", "cellular","sms", "unread"}, call("action_sms_unread"), nil, nil, true).leaf = true
	page.icon = 'nradio-sms'
	page.show = true
end

function get_cellular_template()
	luci.nradio.get_cellular_template()
end

function action_sms_del()
    local channel = http.formvalue("channel")
	local ids = http.formvalue("ids")
	local sms_type = http.formvalue("type")
	return_code = nr.sms_del(ids,sms_type,channel)
	luci.nradio.luci_call_result(return_code)
end
function action_sms_send()
	local sms_msg = http.formvalue("msg")
	local phone_num = http.formvalue("phone_num")
	local channel = http.formvalue("channel")
    if channel then
        channel = channel:gsub("[;'\\\"]", "")
    end
	return_code = nr.sms_send(sms_msg,phone_num,channel)
	luci.nradio.luci_call_result(return_code)
end

function action_sms_resend()
	local channel = http.formvalue("channel")
	local resend_id = http.formvalue("id")
    if channel then
        channel = channel:gsub("[;'\\\"]", "")
    end
	local return_code = nr.sms_resend(resend_id,channel)
	luci.nradio.luci_call_result(return_code)
end

function action_sms_force_ims()
	local force_data = http.formvalue("force_ims")
	return_code = nr.sms_force_ims(force_data)
	luci.nradio.luci_call_result(return_code)
end

function action_sms_list_http()
	local channel = http.formvalue("channel")
    if channel then
        channel = channel:gsub("[;'\\\"]", "")
    end
	luci.nradio.luci_call_result(action_sms_list(channel))
end
function action_sms_list(channel)
    local model_str,cpe_section = nr.get_cellular_last(channel)
	local sms_type = http.formvalue("type")
    local force_ims = false
    local data = nr.sms_list(sms_type,channel)
    local module_disabled = uci:get("network",cpe_section,"disabled") or ""
    local cur_now = uci:get("cpesel","sim"..model_str,"cur") or "1"
    local force_ims = uci:get("cpecfg",cpe_section.."sim"..cur_now,"force_ims") or ""

    if force_ims == "1" then
        data.on = "1"
    else
        data.on = "0"
    end

	return data
end

function action_sms_unread()
    local sms_type = 'new'
    local iface_data = {}
    local sms_iface = {}

    uci:foreach("network", "interface",
        function(s)
            if (s.proto == "wwan" or s.proto == "tdmi") and s["disabled"] ~= "0" then
                iface_data[#iface_data+1] = s[".name"]
            end
        end
    )

    if iface_data and #iface_data > 0 then
        for _, iface in ipairs(iface_data) do
            local groups = {}
            local data = nr.sms_list(sms_type, iface) or {}
            local smslist = (data and data.smslist) or {}
            local cnt = 0
            for _, item in ipairs(smslist) do
                local mid = tonumber(item.multi_sms_id) or 0
                if mid == 0 then
                    cnt = cnt + 1
                else
                    local key = item.contact .. "#" .. tostring(mid) .. "#" .. iface
                    if not groups[key] then
                        groups[key] = true
                        cnt = cnt + 1
                    end
                end
            end
            sms_iface[#sms_iface+1] = {iface = iface, count = cnt, max = data.total or 0, used = data.count or 0}
        end
    end

    luci.nradio.luci_call_result(sms_iface)
end

--[[

function encodeToPDU(smsc, phoneNumber, message)
    local function TONGen(input,isPhonenum)
        local TONBegin="91"
        local orinInput=input
        if #input % 2 == 1 then
            input = input .. 'F'
        end
        -- 交换数位
        local transformed = {}
        for i = 1, #input, 2 do
            local firstChar = input:sub(i, i)
            local secondChar = input:sub(i + 1, i + 1)
            transformed[#transformed + 1] = secondChar
            transformed[#transformed + 1] = firstChar
        end
        local TONStr=TONBegin..table.concat(transformed)
        local TONLength=0
        if(isPhonenum==false) then
             TONLength=string.len(TONStr)/2
        else
             TONLength=string.format("%02X",string.len(orinInput))
        end
        if(string.len(TONLength)<2) then --当短信中心号码过短时，最开头需要补0
            TONLength="0"..TONLength
        end
        return TONLength..TONStr
    end

    local TPMTI="01" --TP-MTI/VFP，同样搞不懂，11和01最好都试一下
    local TPMR="00" --TP-MR消息基准， 搞不懂，但应该都是00
    local phoneNumEncode=TONGen(phoneNumber,true)
    if(string.len(smsc)==0)then
        pdu="00"..TPMTI..TPMR..phoneNumEncode
    else
        pdu=TONGen(smsc,false)..TPMTI..TPMR..phoneNumEncode
    end
    local TPPID="00" --TP-PID
    local TPDCS="19"  --Msg Class 1
    local MSG=encodeToUCS2(message)
    local MSGLen=string.format("%02X",string.len(MSG)/2)
    local AllMsgLen=7+string.len(phoneNumEncode)/2+string.len(MSG)/2-2
    pdu=AllMsgLen.." "..pdu..TPPID..TPDCS..MSGLen..MSG

    return pdu
end

function encodeToUCS2(text)
    local ucs2 = {}
    local index = 1
    local length = string.len(text)

    while index <= length do
        local byte1 = string.byte(text, index)

        if byte1 < 128 then
            ucs2[#ucs2 + 1] = string.format("%04X", byte1)
            index = index + 1
        elseif byte1 >= 192 and byte1 < 224 then
            local byte2 = string.byte(text, index + 1)
            ucs2[#ucs2 + 1] = string.format("%04X", (byte1 - 192) * 64 + (byte2 - 128))
            index = index + 2
        elseif byte1 >= 224 then
            local byte2 = string.byte(text, index + 1)
            local byte3 = string.byte(text, index + 2)
            ucs2[#ucs2 + 1] = string.format("%04X", (byte1 - 224) * 4096 + (byte2 - 128) * 64 + (byte3 - 128))
            index = index + 3
        else
            return nil
        end
    end

    return table.concat(ucs2)
end
--]]
--[[
{
    "type": 100,
    "protocol": 0,
    "timestamp": "23111614143032",
    "smsc": {
        "len": 9,
        "type": 145,
        "num": "+460030934261200"
    },
    "msg": {
        "len": 136,
        "multipart": false,
        "content": "Ԁ̷ԁ【服务提醒】尊敬的客户，您订购的5G畅享融合399元套餐套餐含国内（含本地：请留意业务协议约定）通话时长1900分钟，无线上网流量"
    },
    "dcs": 8,
    "sender": {
        "len": 5,
        "type": 161,
        "num": "10001"
    }
}

function decode_pdu(pduString)
	nixio.syslog("err","start decode")
	local decoded = luapdu.decode(pduString)
	nixio.syslog("err",cjson.encode(decoded))
	return decoded
end
--]]
--[[
	{
    "result": {
        "smslist": [
            {
                "contact": "10001",
                "undeal": 0,
                "list": [
                    {
                        "role": "0",
                        "index": "0",
                        "timestamp": "2023\/11\/16 14:14:30\n",
                        "content": "Ԁ̷ԁ【服务提醒】尊敬的客户，您订购的5G畅享融合399元套餐套餐含国内（含本地：请留意业务协议约定）通话时长1900分钟，无线上网流量",
                        "stat": "1"
                    },
                    {
                        "role": "0",
                        "index": "1",
                        "timestamp": "2023\/11\/16 14:14:30\n",
                        "content": "Ԁ̷Ԃ204GB。截至11月15日23时59分，本机已使用国内通话时长0分钟，无线上网流量29.6GB。套餐内共使用国内通话时长0分钟，",
                        "stat": "1"
                    },
                    {
                        "role": "0",
                        "index": "2",
                        "timestamp": "2023\/11\/16 14:14:31\n",
                        "content": "Ԁ̷ԃ无线上网流量29.6GB。以上信息可能存在延时，具体以详单为准。更多使用信息，可微信关注“广东电信”公众号查询。如您不需要",
                        "stat": "1"
                    }
                ]
            }
        ]
    }
}
--]]



--[[lua PDU解码逻辑接口
function sms_list()
	local data= {}
	local contact_array= {}
	uci:foreach("network", "interface",
		function(s)
			if s.proto == "wwan" then
				name=s[".name"]
				sms_result = util.exec("cpetools.sh -i "..name.." -c sms")
				nixio.syslog("err","get sms")
				if sms_result and #sms_result  > 0 then
					local sms_info = cjson.decode(sms_result)
					if sms_info and sms_info.smslist then
						for i = 1, #sms_info.smslist do
							curdata = decode_pdu(sms_info.smslist[i].sms_data)
							if curdata then
								local contact_item= {contact="",undeal=0,list={}}
								local item = {content="",timestamp="",index="",stat=""}
								local stat = sms_info.smslist[i]["stat"]

								if curdata.timestamp then
									local time_buffer = curdata.timestamp
									local date_recgpre = time_buffer:sub(1,-5)
									date_recgpre = date_recgpre.."."..time_buffer:sub(-4,-3)
									item.timestamp = util.exec("date -d \""..date_recgpre.."\" +%s")
								end

								item.content = curdata.msg.content
								item.index = sms_info.smslist[i]["index"]
								item.stat = "0"
								local contact_num=""
								if stat == "0" or stat == "1" then
									item.role = "0"
									if stat == "1" then
										item.stat = "1"
									else
										contact_item["undeal"] = 1
									end
									if curdata.sender.num then
										contact_num = curdata.sender.num
									end
								else
									item.role = "1"
									if stat == "3" then
										item.stat = "1"
									else
										contact_item["undeal"] = 1
									end
									if curdata.recipient.num then
										contact_num = curdata.recipient.num
									end
								end
								if contact_num and #contact_num > 0 then
									contact_num=contact_num:gsub("+", "")
									if not contact_array[contact_num] then
										contact_item.contact = contact_num
										contact_item.list[#contact_item.list+1] = item
										contact_array[contact_num] = contact_item
									else
										contact_array[contact_num].list[#contact_array[contact_num].list+1] = item
									end
								end
							end
						end
					end
				end
			end
		end
	)

	for key,item in pairs(contact_array) do
		data[#data+1] = item
	end
	return {smslist=data}
end
--]]
