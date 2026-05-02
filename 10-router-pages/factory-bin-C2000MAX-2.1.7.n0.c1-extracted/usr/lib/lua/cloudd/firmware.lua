local os, string = os, string
local fs = require "nixio.fs"
local socket = require "socket"
local type = type
local lock = require "cloudd.lock"
local httpfile = require "cloudd.httpfile"
local l_md5file = require "cloudd.md5file"
local c_debug = require "cloudd.debug"

local FIRMWARE_DIRECTORY = "/tmp/firmware"
local FIRMWARE_FILE = FIRMWARE_DIRECTORY .. "/firmware.bin"

module ("cloudd.firmware")

local ERROR_CODE = {
  E_OKAY = 0,
  E_FORMAT = 1,         --Image Format error
  E_MD5 = 2,            --MD5 sum dismatched.
  E_HTTP = 3,           --Something went wrong during downloading firmware, refers to http(s) errors.
  E_BUSY = 4,           --upgrade is running.
}

local e = ERROR_CODE

local ERROR_STRING = {
  [e.E_OKAY] = "ok",
  [e.E_FORMAT] = "image format error",
  [e.E_MD5] = "image md5 dismatched",
  [e.E_HTTP] = "http download error",
  [e.E_BUSY] = "upgrade is runnig",
}

local function clean_firmware_file()
  fs.remove(FIRMWARE_FILE)
end

local function rom_verify(rom_path)
  if (0 ~= os.execute(
    "sysupgrade -T " .. rom_path .." &>/dev/null"
    )) then
    return e.E_FORMAT, ERROR_STRING[e.E_FORMAT]
  end
  return e.E_OKAY, ERROR_STRING[e.E_OKAY]
end

local function download_and_verify(param, file, md5)
  local ret
  for i = 0, 3, 1 do
    ret = httpfile.download_file2(param, file)
    if type(ret) == "number" and ret == 200 then
      if md5 == nil then
        break
      end

      local actual_md5 = l_md5file.md5file(file)
      if actual_md5 == md5 then
        break
      end
    end

    socket.select(nil, nil, 3)
    if i == 2 then
      param = param .. "?param=" .. os.time()
    end
  end

  if type(ret) ~= "number" or ret ~= 200 then
    c_debug.syslog("info", "Failed to download firmware", 1)
    return e.E_HTTP, ret
  end

  if md5 ~= nil then
    local actual_md5 = l_md5file.md5file(file)
    if actual_md5 ~= md5 then
      c_debug.syslog("info", "The MD5SUM from downloaded firmware is different from the server's")
      return e.E_MD5, string.format("Size: %d, MD5: %s", fs.stat(file, "size"), actual_md5)
    end
  end

  return e.E_OKAY, "Download OK."
end


local function do_download(url, md5,no_verify)
  fs.mkdir(FIRMWARE_DIRECTORY)
  clean_firmware_file()
  c_debug.syslog("info", "Download firmware", 1)
  c_debug.syslog("info", url, 1)
  if md5 ~= nil then
    c_debug.syslog("info", md5, 1)
  end
  local ret, err_text = download_and_verify(url, FIRMWARE_FILE, md5)
  if ret == e.E_OKAY and not no_verify then
    ret, err_text = rom_verify(FIRMWARE_FILE)
  end

  if ret ~= e.E_OKAY then
    clean_firmware_file()
  end

  return ret, err_text
end

function download_upgrade(url, md5, command,download_path,download_file,no_verify)
  local up_lk = lock.trylock("upgrade")
  local exec_comd
  if up_lk == nil then
    c_debug.syslog("info", "cloudd firmware is running now.", 1)
    return e.E_BUSY
  end
  local fw_lk = lock.flock("firmware")

  if download_path and #download_path > 0 then
    FIRMWARE_DIRECTORY = download_path
  end
  if download_file and #download_file > 0 then
    FIRMWARE_FILE = FIRMWARE_DIRECTORY.."/"..download_file
  end  
  c_debug.syslog("info", "cloudd firmware start running.", 1)
  local ret, err_text = do_download(url, md5,no_verify)
  if ret ~= e.E_OKAY then
    lock.unlock(fw_lk)
    lock.unlock(up_lk)
    return ret, err_text
  end

  if command == nil then
    exec_comd = "sysupgrade" .. " " .. FIRMWARE_FILE
  else
    exec_comd = command .. " " .. FIRMWARE_FILE
  end

  c_debug.syslog("info", "cloudd firmware start flashing.", 1)
  os.execute(exec_comd);
  lock.unlock(fw_lk)
  lock.unlock(up_lk)
  return ret, err_text
end
