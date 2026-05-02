local io, tostring = io, tostring
local cjson = require "cjson"
local ubus = require "ubus"
local socket = require "socket"
local uci = require "uci".cursor()

module ("cloudd.cloudd")

local function cloudd_unused()
    -- for avoiding unused warning
end

local function cloudd_device_has_cloud(id)
  local cloud = false
  uci:foreach("cloudd", "device",
              function(s)
                if s.id == id and s.cloud and s.cloud == "1" then
                  cloud = true
                  return true
                end
              end
  )
  return cloud
end

function cloudd_parse_data()
  local data = cjson.decode(io.read("*a"))
  local did
  local sid
  local event
  local payload
  local proto
  local reply

  io.input():close()
  did = data["did"]
  sid = data["sid"]
  event = data["event"];
  payload = data["payload"]
  proto = data["proto"]
  reply = data["reply"]

  return did, sid, event, payload, proto, reply
end

function cloudd_send(p_did, p_topic, p_data, p_proto, is_reply)
  local conn = ubus.connect()
  local proto = "mqtt"
  local r_topic
  local r_json
  local rv
  local rst

  if conn == nil then
    return -1
  end

  if p_topic == nil or p_data == nil then
    return -1
  end

  if p_proto ~= nil then
    proto = p_proto
  end

  if is_reply == 1 then
    r_topic = "reply/" .. p_topic
  else
    r_topic = p_topic
  end

  -- add timestamp as unique id if not exist
  if p_data["uniq"] == nil then
    p_data["uniq"] = tostring(socket.gettime())
  end

  r_json = cjson.encode(p_data)

  if p_did ~= nil then
    if cloudd_device_has_cloud(p_did) then
      p_did = p_did.."ap"
    end
    rst, rv = conn:send(proto, { event = r_topic, did = p_did, payload = r_json })
  else
    rst, rv = conn:send(proto, { event = r_topic, payload = r_json })
  end

  cloudd_unused(rst)
  conn:close()
  return rv
end
