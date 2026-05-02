local cl = require "luci.model.cloudd".init()
local ca = require "cloudd.api"
local nr = require "luci.nradio"

nr.fork_exec(function()
  local id = ca.cloudd_get_self_id()
  local cdev = cl.get_device(id, "master")
  if nr.support_mesh() then
    ca.sync_wifi_config()
  end
  cdev:send_config()
end)