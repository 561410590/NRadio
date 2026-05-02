local pduString    = require('luci.luapdu.string')
local pduSmsObject = require('luci.luapdu.smsobject')
-- Valuable addresses
-- http://www.sendsms.cn/download/SMS_PDU-mode.PDF
-- http://www.smartposition.nl/resources/sms_pdu.html
-- https://en.wikipedia.org/wiki/User_Data_Header
-- https://en.wikipedia.org/wiki/Concatenated_SMS
-- http://mobiletidings.com/2009/02/18/combining-sms-messages/
-- https://github.com/tladesignz/jsPduDecoder
function decodePduSms(pduSmsString)
    local pduStr = pduString.new(pduSmsString)
    return pduStr:decodePDU()
end

local _G = _G

local _ENV = nil

local luapdu = {
    _VERSION = "0.1",
    _DESCRIPTION = "LuaPDU : SMS PDU encoder/decoder",
    _COPYRIGHT = "Copyright (c) 2016 Linards Jukmanis <Linards.Jukmanis@0x4c4a.com>",
    decode = decodePduSms,
    newTx = pduSmsObject.newTx,
    newRx = pduSmsObject.newRx,
}

_G.luapdu = luapdu

return luapdu