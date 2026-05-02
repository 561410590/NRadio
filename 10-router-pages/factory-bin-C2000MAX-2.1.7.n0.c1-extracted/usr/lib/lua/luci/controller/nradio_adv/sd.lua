
module("luci.controller.nradio_adv.sd", package.seeall)

local fs = require "nixio.fs"
local http = require "luci.http"
local util = require "luci.util"
local nixio = require "nixio"

local IMG_PATH = "/tmp/"
local IMG_NAME = "temp.bin"

local SD_DEV = "/dev/mmcblk0"
local SD_PATH = "/sys/block/mmcblk0"
local OVERLAY_PATH = "/overlay"
local TARGET_PARTITION = "/dev/mmcblk0p1"

local MTD_INFO = "/proc/mtd"
local ROOT_LABEL = "rootfs_data"
local ROOTFS_PATH = "/dev/mtdblock"
local FSTAB_ROOTFS_PATH = "/upper/etc/config"

function index()
	page = entry({"nradioadv", "system", "sd"}, template("nradio_adv/sd"), _("SdMaker"), 28, true)

	entry({"nradioadv", "system", "sd", "info"}, call("action_get_info"), nil, nil, true)
	entry({"nradioadv", "system", "sd", "mode"}, call("action_set_mode"), nil, nil, true)
	entry({"nradioadv", "system", "sd", "creat"}, call("action_creat_sysdisk"), nil, nil, true)
	entry({"nradioadv", "system", "sd", "partinfo"}, call("action_get_partinfo"), nil, nil, true)
	entry({"nradioadv", "system", "sd", "init"}, call("action_init_sd"), nil, nil, true)
	entry({"nradioadv", "system", "sd", "storage"}, call("action_set_overlay"), nil, nil, true)

	page.icon = 'nradio-sysmaker'
	page.show = true

	page = entry({"nradioadv", "system", "boot"}, template("nradio_adv/boot"), _("BootTitle"), 29, true)
	page.icon = 'nradio-sd'
	page.show = true

	page = entry({"nradioadv", "system", "expand"}, template("nradio_adv/expand"), _("SdExpand"), 30, true)
	page.icon = 'nradio-storage'
	page.show = true
end

local function get_flash_mount_path()
	local mount_path = ""
	local cmd = "df | grep " .. ROOTFS_PATH .. " | awk '{print$6}'"

	local exit, ret, err = pcall(util.exec, cmd)
	if exit and ret and #ret > 0 then
		mount_path = ret:gsub("\n", "")
	end

	return mount_path
end

local function get_partition_fstab()
	local status = false

	local uci = require "luci.model.uci".cursor()
	local MTD_BLOCK_PATH = get_flash_mount_path()

	if MTD_BLOCK_PATH ~= OVERLAY_PATH then
		local UCI_PATH = MTD_BLOCK_PATH .. FSTAB_ROOTFS_PATH
		if not fs.access(UCI_PATH) then
			return status
		end
		uci:set_confdir(UCI_PATH)
	end

	uci:foreach("fstab", "mount", function(s)
		if s.target == OVERLAY_PATH and s.enabled == "1" and s.device == TARGET_PARTITION then
			status = true
		end
	end)
	return status
end

--[[	get_partition_status;
status code:
	-1：	无目标分区。
	0:	格式化成功。有目标分区，有文件系统，能挂载能读写。
	1:	有目标分区，但有多分区。
	2： 符合单分区，无文件系统。
	3：	有文件系统，但损坏，无法正常挂载使用。
	4： 无法读写。
--]]

local function get_partition_status()
	local status = -1
	local fstype = ""
	local supported_fs = {['ext2'] = true, ['ext3'] = true, ['ext4'] = true, ['f2fs'] = true, ['ubifs'] = true, ['jffs2'] = true}

	if not fs.access(TARGET_PARTITION) then
		return status
	end

	status = 1
	local part_cmd = "cat /proc/partitions | grep -E 'mmcblk0p[0-9]+' | wc -l"
	local exit_part, ret_part = pcall(util.exec, part_cmd)

	if exit_part and ret_part and #ret_part > 0 then
		local cnt = tonumber((ret_part or "")) or 0
		if cnt > 1 then
			return status
		end
	end

	status = 2
	local blkid_cmd = string.format("blkid -o export %s | grep ^TYPE=", TARGET_PARTITION)
	local exit_blkid, ret_blkid = pcall(util.exec, blkid_cmd)

	if exit_blkid and ret_blkid and #ret_blkid > 0 then
		fstype = ret_blkid:match("TYPE=(.+)")
		fstype = fstype:gsub("[^%w]", "")
	end
	if not fstype or not supported_fs[fstype] then
		return status
	end

	status = 3
	local mount_cmd = "mount | grep " .. TARGET_PARTITION
	local exit_mount, ret_mount = pcall(util.exec, mount_cmd)

	if exit_mount and ret_mount and #ret_mount > 0 then
		local mp = ret_mount:match(" on ([^ ]+) ")
		if mp and #mp > 0 then
			local test_file = mp .. "/.sd_write_test"
			local write_cmd = "echo 1 > " .. test_file .. " 2>&1"
			pcall(util.exec, write_cmd)
			if not fs.access(test_file) then
				status = 4
				return status
			end
			pcall(util.exec, "rm -f " .. test_file .. " 2>&1")
		end
		return 0
	end

	local verify_dir = "/tmp/.sd_verify_mount"
	local mkdir_cmd = "mkdir -p " .. verify_dir
	pcall(util.exec, mkdir_cmd)
	local try_mount_cmd = string.format("mount %s %s 2>&1", TARGET_PARTITION, verify_dir)
	pcall(util.exec, try_mount_cmd)

	local check_cmd = "mount | grep " .. verify_dir
	local exit_check, ret_check = pcall(util.exec, check_cmd)

	if exit_check and ret_check and #ret_check > 0 then
		local test_file = verify_dir .. "/.sd_write_test"
		local write_cmd = "echo 1 > " .. test_file .. " 2>&1"
		pcall(util.exec, write_cmd)

		if not fs.access(test_file) then
			status = 4
		else
			status = 0
			pcall(util.exec, "rm -f " .. test_file .. " 2>&1")
		end

		pcall(util.exec, "umount " .. verify_dir .. " 2>&1")
		pcall(util.exec, "rmdir " .. verify_dir .. " 2>&1")
		return status
	end

	pcall(util.exec, "rmdir " .. verify_dir .. " 2>&1")

	return status
end

local function get_sd_status()
	local name = ""
	local size = 0
	local mounted = false

	if fs.access(SD_PATH) then
		mounted = true
		name = fs.readfile(SD_PATH .. "/device/name") or ""
		name = name:gsub("\n", "")
		local blocks = tonumber(util.exec("cat " .. SD_PATH .. "/size")) or 0
		size = blocks * 512 / 1024
	end

	return name, mounted, size
end

local function adapt_extroot_config(src, dst)
	local FLASH_CONFIG = src .. FSTAB_ROOTFS_PATH
	local TFCARD_CONFIG = dst .. FSTAB_ROOTFS_PATH

	local uci_flash = require "luci.model.uci".cursor()
	local uci_tf = require "luci.model.uci".cursor(TFCARD_CONFIG)

	uci_tf:load("oem")
	local external_mac = uci_tf:get("oem", "board", "id")
	local native_mac = uci_flash:get("oem", "board", "id")

	if native_mac and external_mac and native_mac == external_mac then
		return true
	elseif native_mac and external_mac and native_mac ~= external_mac then
		local farmat_mac = native_mac:gsub(":", "")
		if fs.access(TFCARD_CONFIG .. "/cloudd") then
			uci_tf:load("cloudd")
			uci_tf:set("cloudd", "d0", "id", farmat_mac)
			uci_tf:set("cloudd", "d0", "name", farmat_mac)
			uci_tf:commit("cloudd")
		end

		local oem_cmd = string.format("cp -f '%s/oem' '%s' 2>&1", FLASH_CONFIG, TFCARD_CONFIG)
		pcall(util.exec, oem_cmd)
		local mosquitto_cmd = string.format("cp -f '%s/mosquitto' '%s' 2>&1", FLASH_CONFIG, TFCARD_CONFIG)
		pcall(util.exec, mosquitto_cmd)
		return true
	end

	return false
end

local function make_sysupgrade_backup(cover)
	local result = -1
	local mount_point = ""
	local mount_cmd = "mount | grep " .. TARGET_PARTITION

	if cover == "2" then
		return 0
	end

	local exit_mount, ret_mount = pcall(util.exec, mount_cmd)
	if exit_mount and ret_mount and #ret_mount > 0 then
		mount_point = ret_mount:match(" on ([^ ]+) ")
	end

	if not mount_point or #mount_point == 0 then
		return result
	end

	-- local uuid_path = mount_point .. "/etc/.extroot-uuid"
	local extroot = mount_point .. FSTAB_ROOTFS_PATH
	local src_upper = OVERLAY_PATH .. "/upper"
	local src_work = OVERLAY_PATH .. "/work"
	local dst_upper = mount_point .. "/upper"
	local dst_work = mount_point .. "/work"

	if not fs.access(extroot) or cover == "0" then
		local rmupper_cmd = string.format("rm -rf '%s' 2>&1", dst_upper)
		pcall(util.exec, rmupper_cmd)
		local rmwork_cmd = string.format("rm -rf '%s' 2>&1", dst_work)
		pcall(util.exec, rmwork_cmd)

		local cp_upper_cmd = string.format("cp -a '%s' '%s' 2>&1", src_upper, dst_upper)
		pcall(util.exec, cp_upper_cmd)
		local cp_work_cmd = string.format("cp -a '%s' '%s' 2>&1", src_work, dst_work)
		pcall(util.exec, cp_work_cmd)

		if fs.access(extroot) then
			result = 0
		else
			pcall(util.exec, rmupper_cmd)
			pcall(util.exec, rmwork_cmd)
		end
	elseif fs.access(extroot) and cover == "1" then
		if adapt_extroot_config(OVERLAY_PATH, mount_point) then
			result = 0
		else
			result = 1
		end
	end

	return result
end

function action_get_partinfo()
	local effect = false
	local fstab = get_partition_fstab()
	local partition = get_partition_status()
	local mount_out = util.exec("mount | grep ' on /overlay '")

	if mount_out and #mount_out > 0 and mount_out:match(TARGET_PARTITION) then
		effect = true
	end

	http.prepare_content("application/json")
	http.write_json({
		fstab = fstab,
		inited = partition,
		effect = effect
	})
end

function action_get_info()
	local mode, avai_size
	local name, mounted, size = get_sd_status()

	local command = "ubenv -o 1 -s boot_from_sd"
	local exit, ret = pcall(util.exec, command)

	if exit and ret and #ret >0 then
		mode = tonumber(string.match(ret, "=%s*(%d+)") or 0)
	else
		mode = 0
	end

	command = "df " .. IMG_PATH .. " | awk 'NR==2{print $4}'"
	avai_size = tonumber(util.exec(command) or 0)

	http.prepare_content("application/json")
	http.write_json({
		mode = mode,
		name = name,
		size = size,
		mounted = mounted,
		avai_size = avai_size
	})
end

function action_set_mode()
	local msgcode, status = 1, 1
	local mode = http.formvalue("mode")

	if not mode or ( mode ~= "0" and mode ~= "1" ) then
		msgcode = 2
	else
		local command = "ubenv -o 0 -s boot_from_sd -v " .. mode .. " 2>/dev/null"
		util.exec(command)

		msgcode = 0
		status = 0
	end

	http.prepare_content("application/json")
	http.write_json({status = status, msgcode = msgcode})
end

function action_creat_sysdisk()
	local IMG = IMG_PATH .. IMG_NAME
	local status, msgcode = 1, 1
	http.prepare_content("application/json")

	if not fs.access(SD_PATH) then
		fs.unlink(IMG)
		http.write_json({status = status, msgcode = msgcode})
		return
	end

	local is_last = tonumber(http.formvalue("is_last") or "0")
	local chunk_offset = tonumber(http.formvalue("chunk_offset") or "0")
	local chunk_total = tonumber(http.formvalue("chunk_total") or "0")
	local chunk_index = tonumber(http.formvalue("chunk_index") or "0")

	local fp, failed, wrote = nil, false, 0

	if chunk_offset == 0 and fs.access(IMG) then
		fs.unlink(IMG)
	end

	http.setfilehandler(function(meta, chunk, eof)
		if not fp and meta and meta.name == "boot_creat_sd_file" then
			if chunk_offset > 0 then
				fp = io.open(IMG, "r+b")
				if fp then fp:seek("set", chunk_offset) end
			else
				fp = io.open(IMG, "wb")
			end
			if not fp then
				failed = true
			end
		end
		if fp and chunk then
			local ok = fp:write(chunk)
			if not ok then
				failed = true
			else
				wrote = wrote + #chunk
			end
		end
		if fp and eof then
			fp:close()
			util.exec("sync")
			if not failed and wrote > 0 then
				status = 0
				msgcode = 0
			end
		end
	end)

	if not luci.dispatcher.test_post_security() then
		failed = true
	end

	if failed then
		status = 1
		msgcode = 2
	else
		if is_last == 1 then
			local st = fs.stat(IMG)
			local img_size = st and st.size or 0
			if chunk_total > 0 and img_size ~= chunk_total then
				fs.unlink(IMG)
				status = 1
				msgcode = 3
			else
				local cmd = "umount /dev/mmcblk0p* > /dev/null 2>&1"
				util.exec(cmd)

				cmd = "dd if=" .. IMG .. " of=" .. SD_DEV .. " bs=512K"
				util.exec(cmd)

				fs.unlink(IMG)

				status = 0
				msgcode = 0
			end
		end
	end

	http.write_json({status = status, msgcode = msgcode})
end

function action_init_sd()
	http.prepare_content("application/json")
	local status = -1

	if not fs.access(SD_DEV) then
		http.write_json({status = status, msgcode = 2})
		return
	end

	status = 1
	util.exec("umount " ..  SD_DEV .. "p*")
	util.exec('echo -e "o\nn\np\n1\n\n\nw\n" | fdisk ' .. SD_DEV .. " 2>&1")
	util.exec("sync && sleep 1")
	util.exec("umount " ..  SD_DEV .. "p*")

	if not fs.access(TARGET_PARTITION) then
		http.write_json({status = status})
		return
	end

	util.exec('mkfs.f2fs -l nradio_tf_overlay ' .. TARGET_PARTITION .. " 2>&1")
	util.exec("sync")

	local blkid_cmd = string.format("blkid -o export %s | grep ^TYPE=", TARGET_PARTITION)
	local exit_blkid, ret_blkid = pcall(util.exec, blkid_cmd)

	if exit_blkid and ret_blkid and #ret_blkid > 0 and ret_blkid:match("TYPE=f2fs") then
		local mount_point = "/tmp/storage/mmcblk0p1"
		local mkdir_cmd = "mkdir -p " .. mount_point
		pcall(util.exec, mkdir_cmd)

		local umount_mp_cmd = "umount " .. mount_point .. " 2>&1"
		pcall(util.exec, umount_mp_cmd)

		local mount_cmd = string.format("mount -t f2fs %s %s 2>&1", TARGET_PARTITION, mount_point)
		pcall(util.exec, mount_cmd)

		local check_cmd = "mount | grep ' on " .. mount_point .. " '"
		local exit_check, ret_check = pcall(util.exec, check_cmd)

		if exit_check and ret_check and #ret_check > 0 then
			local test_file = mount_point .. "/.sd_init_test"
			local write_cmd = "echo 1 > " .. test_file .. " 2>&1"
			pcall(util.exec, write_cmd)

			if fs.access(test_file) then
				pcall(util.exec, "rm -f " .. test_file .. " 2>&1")
				status = 0
			end
		else
			status = 3
		end
	else
		status = 2
	end
	http.write_json({status = status})
end

function action_set_overlay()
	http.prepare_content("application/json")
	local uci = require "luci.model.uci".cursor()

	local cover  = http.formvalue("cover")
	local enabled = http.formvalue("enabled")

	if not enabled or (enabled ~= "1" and enabled ~= "0") then
		http.write_json({status = -1})
		return
	end
	if not cover or (cover ~= "0" and cover ~= "1" and cover ~= "2") then
		http.write_json({status = -1})
		return
	end

	local section = nil
	local MTD_BLOCK_PATH = get_flash_mount_path()

	if MTD_BLOCK_PATH ~= OVERLAY_PATH then
		local UCI_PATH = MTD_BLOCK_PATH .. FSTAB_ROOTFS_PATH
		if not fs.access(UCI_PATH) then
			http.write_json({status = 1})
			return
		end
		uci:set_confdir(UCI_PATH)
	end

	uci:foreach("fstab", "mount", function(s)
		if s.target == OVERLAY_PATH and s.device == TARGET_PARTITION then
			section = s[".name"]
		end
	end)

	if not section then
		section = uci:add("fstab", "mount")
		uci:set("fstab", section, "device", TARGET_PARTITION)
		uci:set("fstab", section, "target", OVERLAY_PATH)
		uci:set("fstab", section, "ignore_uuid", "1")
		uci:set("fstab", section, "option", "noatime,nodiratime,fsync_mode=posix,sync")
	end

	uci:set("fstab", section, "enabled", enabled)
	uci:commit("fstab")

	local sys_back = make_sysupgrade_backup(cover)
	if sys_back ~= 0 then
		uci:set("fstab", section, "enabled", 0)
		uci:commit("fstab")
		http.write_json({status = 2, msgcode = sys_back})
		return
	end

	http.write_json({status = 0})
end
