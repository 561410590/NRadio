local nixio = require "nixio"
local fs = require "nixio.fs"
local type = type

module "cloudd.lock"

local PATH = "/tmp/flock"

local function get_lock_file_name(name)
  return PATH .. "/" .. name
end

local function do_lock(name, command)
  fs.mkdirr(PATH)
  local file = nixio.open(get_lock_file_name(name), "w+")
  file:lock(command)
end

function lock(name)
  do_lock(name, "lock")
end

function unlock(name)
  if type(name) == "string" then
    do_lock(name, "ulock")
  else
    name:lock("ulock")
    name:close()
  end
end

function flock(name)
  fs.mkdirr(PATH)
  local file = nixio.open(get_lock_file_name(name), "w+")
  file:lock("lock")
  return file
end


function trylock(name)
  fs.mkdirr(PATH)
  local file = nixio.open(get_lock_file_name(name), "w+")

  if file then
    local ret = file:lock("tlock")
    if ret == false then
      file:close()
      return nil
    end
    return file
  end

  return nil
end
