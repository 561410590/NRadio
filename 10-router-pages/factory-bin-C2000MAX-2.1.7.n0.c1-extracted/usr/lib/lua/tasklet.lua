
--
-- Copyright (C) spyder
--

package.loaded.rbtree = nil
local rbtree = require 'rbtree'

local time = time
local pairs, type, assert = pairs, type, assert
local co_create, co_yield, co_resume, co_status = coroutine.create, coroutine.yield, coroutine.resume, coroutine.status
local ETIMEDOUT, EINTR = errno.ETIMEDOUT, errno.EINTR

local poll = poll
local READ = poll.IN
local WRITE = poll.OUT
local ERROR = poll.ERR
local EDGE = poll.ET

local NULL = NULL

local TERM = 3

-------------------------------------------------------------------------------
-- variables {

local poll_fd = -1

-- {[fd]=handler} for all the registered file descriptors.
local handler_set = {}

-- rbtree for timers
local rb_timer = rbtree.new()

-- The current task running
local current

-- Tasks that are ready to be resumed.
local ready_list = false

-- Running state
local state = 0

local cb_updatedtime = false

-- Modules not driven by I/O events.
-- Each element in the array is a callback function invoked before each I/O polling.
local nonevent_modules = {}

local M = {
	-- seconds since the system booted
	now = time.uptime(),

	-- seconds since the unix epoch
	now_unix = time.time(),

	-- non-event moudles
	_nonevent_modules = nonevent_modules,
}

-- } variables
------------------------------------------------------------------------------

-- Push a task into ready_list (and will be resumed later)
local function push_ready(task, err)
	if task.t_prev then return end

	-- append it into the ready list
	task.t_err = err or 0
	if ready_list then
		local tail = ready_list.t_prev
		task.t_prev = tail
		tail.t_next = task
		ready_list.t_prev = task
	else
		task.t_prev = task
		ready_list = task
	end
	task.t_next = false

	-- remove from the rbtree
	if task.rb_key then
		rb_timer:delete(task)
		task.rb_key = false
	end
	task.t_blockedby = false
end


local function do_yield(sec, accept_eintr)
	local basetime = M.now
	local tm_elapsed
	local sig, sighandler
	local err

	if current.t_sig then
		error('unable to block when handling a task signal')
	end

	if sec and sec >= 0 then
		if sec < 0.001 then
			require('log').info('block_task with sec = ', sec, ': ', debug.traceback())
			sec = 0.001
		end
	else
		sec = -1
	end
	
	while true do
		if sec > 0 then
			tm_elapsed = M.now - basetime
			if tm_elapsed >= sec then
				return ETIMEDOUT
			end
			current.rb_key = basetime + sec
			rb_timer:insert(current)
		end

		err = co_yield() or 0
		sig = current.t_sig
		if sig then
			current.t_sig = false
			sighandler = current.sighandler
			if sighandler then
				sighandler(current, sig)
			end

			if accept_eintr then
				return EINTR
			end
		else
			return err
		end
	end
end

local function do_resume(task)
	local co = task.t_co
	if not co then return end

	current = task
	local ok, msg = co_resume(co, task.t_err)
	current = nil

	if co_status(co) == 'dead' then
		task.t_co = false
		local parent = task.t_parent
		if parent then
			local nsubs = parent.t_nsubs
			if nsubs < 0 then
				nsubs = nsubs + 1
				parent.t_nsubs = nsubs
				if nsubs == 0 then
					push_ready(parent)
				end
			else
				nsubs = nsubs - 1
				parent.t_nsubs = nsubs
			end
		end
	end

	if not ok and not task.t_sig then
		local buf = tmpbuf:rewind()
		buf:putstr('exception occurred on task: \n')
		buf:dump(task, 1)
		buf:putstr('\n', debug.traceback(co, msg), '\n')
		error(buf:str())
	end
end

-- Resume all tasks in ready_list
local function resume_list()
	local task = ready_list
	ready_list = false

	local next
	while task do
		while task and not quit do
			next = task.t_next
			task.t_prev = false

			do_resume(task)

			task = next

			if state ==	TERM then return end
		end

		task = ready_list
		ready_list = false
	end
end

-- Get the current task
function M.current_task()
	return current
end

-- Start a new task.
-- The new task is not resumed immediately, but will be delayed.
-- However, all tasks will be executed in the order they are created
--
-- 'cb' is the callback function.
-- 'obj' is the prototype object of task or nil
--
-- Return the modified/created task object.
function M.start_task(cb, obj, joinable)
	local task
	if obj then
		task = type(obj) == 'string' and {t_name = obj} or obj
	else
		task = {}
	end

	if joinable and current then
		task.t_parent = current		-- parent task
		current.t_nsubs = current.t_nsubs + 1
	end
	task.t_nsubs = 0			-- number of children
	task.t_co = coroutine.create(cb)  -- the lua-coroutine handle
	task.t_prev = false
	task.t_next = false
	task.t_sig = false
	task.t_blockedby = false
	task.t_svcreq = false
	task.t_svcresp = false
	task.t_svcreqtime = false
	push_ready(task)
	return task
end

-- Reap a task
-- The target task will never be resumed again and the resource is released.
function M.reap_task(task)
	if current == task then
		error('can\'t reap yourself')
	end

	if task.t_co then
		task.t_sig = true
		task.sighandler = M.exit

		if not task.t_prev then
			push_ready(task)
		end
	end
end

function M.kill_task(task, sig)
	if task.t_co then
		if task ~= current then
			task.t_sig = sig
			if not task.t_prev then
				task.t_err = EINTR
				push_ready(task)
			end
		else
			local sighandler = task.sighandler
			if sighandler then
				sighandler(task, sig)
			end
		end
	end
end

function M.join_tasks(sec)
	local nsubs = current.t_nsubs
	if nsubs > 0 then
		current.t_nsubs = -nsubs
		local err = do_yield(sec)
		nsubs = current.t_nsubs
		if nsubs < 0 then
			current.t_nsubs = -nsubs
		end
		return err
	else
		assert(nsubs == 0)
	end
end


M._block = do_yield
M._block_task = do_yield -- DEPRECATED

function M.exit()
	current.t_sig = true
	error('')
end

-- Make the current task sleeping until time expires or gets a signal.
--
-- 'sec' indicates how long should the task sleep in seconds.
function M.sleep(sec)
	return do_yield(sec, true)
end

M._resume_task = push_ready


-- Register an event handler
--
-- 'fd' should be a valid file descriptor.
-- 'events' is the combination of EVT_XXXX flags.
-- 'handler' is the callback function when event happens, the prototype is 'func(fd, revents)'.
--		the return value is ignored.
--  Note that 'revents' may not exactly equal to 'events'
function M.add_handler(fd, events, handler)
	if poll_fd < 0 then
		poll_fd = poll.create()
	end
	poll.add(poll_fd, fd, events)
	handler_set[fd + 1] = handler
end

-- Modified an event handler
function M.mod_handler(fd, events, handler)
	poll.mod(poll_fd, fd, events)
	if handler then
		handler_set[fd + 1] = handler
	end
end

-- Delete an event handler
function M.del_handler(fd)
	poll.del(poll_fd, fd)
	handler_set[fd + 1] = false
end

M.quit = os.exit
M.term = os.exit

local function update_time()
	local now = time.uptime()
	M.now = now
	local now_unix = time.time()
	M.now_unix = now_unix
	M.now_4log = time.strftime('%m-%d %H:%M:%S ', now_unix)
	if cb_updatedtime then
		cb_updatedtime(now)
	end
end

function M.set_cbupdatedtime(cb)
	cb_updatedtime = cb
end

local function resume_timedout()
	local task

	while true do
		task = rb_timer:min()
		if not task or task.rb_key > M.now then
			break
		end
		rb_timer:delete(task)
		task.rb_key = false
		task.t_err = ETIMEDOUT
		do_resume(task)
	end
	if ready_list then
		resume_list()
	end
end

local function calc_waittime()
	local tm_nearest = rb_timer:min()
	if not tm_nearest then
		return 0.1
	end

	local tm_wait = tm_nearest.rb_key - M.now

	-- expire timers immediately if they are less than 0.001 second.
	while tm_wait <= 0 do
		resume_timedout()
		update_time()
		tm_nearest = rb_timer:min()
		if not tm_nearest then
			return 0.1
		end
		tm_wait = tm_nearest.rb_key - M.now
	end

	return tm_wait
end

function M.loop()
	local wait_ret

	if poll_fd < 0 then
		poll_fd = poll.create()
	end
	
	update_time()
	time.setitimer(time.ITIMER_PROF, 0.01, 0.01)
	signal.signal(signal.SIGPROF, update_time)
	
	if ready_list then
		resume_list()
	end

	local nemod = M._nonevent_modules
	while state < TERM do
		-- exhaust all nonevent-blocked tasks until they are events-blocked or timer-blocked.
		for _, module in pairs(nemod) do
			module()
			while ready_list do
				resume_list()
				module()
			end
		end

		if state == TERM then break end

		-- schedule by events
		update_time()
		wait_ret = poll.wait(poll_fd, calc_waittime())
		update_time()
		if wait_ret then
			for fd, revents in pairs(wait_ret) do
				local handler = handler_set[fd + 1]
				if handler then
					handler(fd, revents)
				end
			end
			resume_list()
		end

		if state == TERM then break end

		resume_timedout()
	end
end

M.rb_timer = rb_timer
M.EVT_READ = READ
M.EVT_WRITE = WRITE
M.EVT_ERROR = ERROR
M.EVT_EDGE = EDGE

return M
