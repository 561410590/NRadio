
require 'std'
package.loaded.rbtree = nil

local M = {}

M.__index = M

-- 1 -> RED, 0 -> BLACK

local function left_rotate(self, root, node)
	local tmp, left
	
	tmp = node.rb_right
	node.rb_right = tmp.rb_left
	
	left = tmp.rb_left
	if not left then
		os.writeb(1, self:dump(tmpbuf:rewind()))
	end
	if left ~= self then
		left.rb_parent = node
	end
	
	local parent = node.rb_parent
	tmp.rb_parent = parent
	
	if node == root then
		self.root = tmp
		root = tmp
	elseif node == parent.rb_left then
		parent.rb_left = tmp
	else
		parent.rb_right= tmp
	end
	
	tmp.rb_left = node
	node.rb_parent = tmp
	
	return root
end

local function right_rotate(self, root, node)
	local tmp, right
	
	tmp = node.rb_left
	node.rb_left = tmp.rb_right
	
	right = tmp.rb_right
	if right ~= self then
		right.rb_parent = node
	end
	
	local parent = node.rb_parent
	tmp.rb_parent = parent
	
	if node == root then
		self.root = tmp
		root = tmp
	elseif node == parent.rb_right then
		parent.rb_right = tmp
	else
		parent.rb_left = tmp
	end
	
	tmp.rb_right = node
	node.rb_parent = tmp
	
	return root
end

function M.insert(self, node)
	local root = self.root
	if root == self then
		node.rb_parent = false
		node.rb_left = self
		node.rb_right = self
		node.rb_color = 0
		self.root = node
		self.count = 1
		return
	end
	
	local parent = root
	local branch, child
	while true do 
		branch = node.rb_key < parent.rb_key and 'rb_left' or 'rb_right'
		child = parent[branch]
		if child == self then   -- reach the sentinel
			break
		end
		parent = child
	end
	
	parent[branch] = node
	node.rb_parent = parent
	node.rb_left = self
	node.rb_right = self
	node.rb_color = 1 
	
	local grandpa, uncle
	
	while node ~= root and node.rb_parent.rb_color == 1 do
		parent = node.rb_parent
		grandpa = parent.rb_parent
		
		if parent == grandpa.rb_left then
			uncle = grandpa.rb_right
			if uncle.rb_color == 1 then
				parent.rb_color = 0
				uncle.rb_color = 0
				grandpa.rb_color = 1
				node = grandpa
			else
				if node == parent.rb_right then
					node = parent
					root = left_rotate(self, root, node)
					parent = node.rb_parent
					grandpa = parent.rb_parent
				end
				
				parent.rb_color = 0
				grandpa.rb_color = 1
				root = right_rotate(self, root, grandpa)
			end
		else
			uncle = grandpa.rb_left
			if uncle.rb_color == 1 then
				parent.rb_color = 0
				uncle.rb_color = 0
				grandpa.rb_color = 1
				node = grandpa
			else
				if node == parent.rb_left then
					node = parent
					root = right_rotate(self, root, node)
					parent = node.rb_parent
					grandpa = parent.rb_parent
				end
				
				parent.rb_color = 0
				grandpa.rb_color = 1
				root = left_rotate(self, root, grandpa)
			end
		
		end
	end
	root.rb_color = 0
	self.count = self.count + 1
end

function M.delete(self, node)
	local root = self.root
	local red
	local tmp, subst, w
	local parent, left, right
	
	self.count = self.count - 1
	
	if node.rb_left == self then
		tmp = node.rb_right
		subst = node
	elseif node.rb_right == self then
		tmp = node.rb_left
		subst = node
	else
		subst = node.rb_right
		while true do 
			left = subst.rb_left
			if left == self then break end
			subst = left
		end
		
		if subst.rb_left ~= self then
			tmp = subst.rb_left
		else
			tmp = subst.rb_right
		end
	end
	
	if subst == root then
		self.root = tmp
		tmp.rb_color = 0
		return
	end
	
	red = subst.rb_color == 1
	
	parent = subst.rb_parent
	if subst == parent.rb_left then
		parent.rb_left = tmp
	else
		parent.rb_right = tmp
	end
	
	if subst == node then
		tmp.rb_parent = parent
	else
		if parent == node then
			tmp.rb_parent = subst
		else
			tmp.rb_parent = parent
		end
		
		subst.rb_left = node.rb_left
		subst.rb_right = node.rb_right
		subst.rb_parent = node.rb_parent
		subst.rb_color = node.rb_color
		
		if node == root then
			self.root = subst
			root = subst
		else
			parent = node.rb_parent
			if node == parent.rb_left then
				parent.rb_left = subst
			else
				parent.rb_right = subst
			end
		end
		
		left = subst.rb_left
		if left ~= self then
			left.rb_parent = subst
		end
		
		right = subst.rb_right
		if right ~= self then
			right.rb_parent = subst
		end
	end
	
	if red then return end
	
	-- a delete fixup
	
	while tmp ~= root and tmp.rb_color == 0 do 
		parent = tmp.rb_parent
		
		if tmp == parent.rb_left then
			w = parent.rb_right
			
			if w.rb_color == 1 then
				w.rb_color = 0
				parent.rb_color = 1
				root = left_rotate(self, root, parent)
				parent = tmp.rb_parent
				w = parent.rb_right
			end
			
			left = w.rb_left
			right = w.rb_right
			if left.rb_color == 0 and right.rb_color == 0 then
				w.rb_color = 1
				tmp = parent
			else
				if right.rb_color == 0 then
					left.rb_color = 0
					w.rb_color = 1
					root = right_rotate(self, root, w)
					parent = tmp.rb_parent
					w = parent.rb_right
					right = w.rb_right
				end
				
				w.rb_color = parent.rb_color
				parent.rb_color = 0
				right.rb_color = 0
				root = left_rotate(self, root, parent)
				tmp = root
			end
		else
			w = parent.rb_left
			
			if w.rb_color == 1 then
				w.rb_color = 0
				parent.rb_color = 1
				root = right_rotate(self, root, parent)
				parent = tmp.rb_parent
				w = parent.rb_left
			end
			
			left = w.rb_left
			right = w.rb_right
			if left.rb_color == 0 and right.rb_color == 0 then
				w.rb_color = 1
				tmp = parent
			else
				if left.rb_color == 0 then
					right.rb_color = 0
					w.rb_color = 1
					root = left_rotate(self, root, w)
					parent = tmp.rb_parent
					w = parent.rb_left
					left = w.rb_left
				end
				
				w.rb_color = parent.rb_color
				parent.rb_color = 0
				left.rb_color = 0
				root = right_rotate(self, root, parent)
				tmp = root
			end
		end
	end
	
	tmp.rb_color = 0
end

function M.min(self)
	local node = self.root
	if node == self then
		return 
	end
	
	while node.rb_left ~= self do 
		node = node.rb_left
	end
	return node
end

function M.max(self)
	local node = self.root
	if node == self then
		return 
	end
	
	while node.rb_right ~= self do 
		node = node.rb_right
	end
	return node
end

local tostring = tostring
local function dump(self, node, indent, buf)
	if node and node ~= self then
		for i = 0, indent do 
			buf:putstr('\t')
		end
		buf:putstr(
			'(', tostring(node.rb_key), ', ', 
			tostring(node.t_name or node.name or 'unnamed'), ', ', 
			node.rb_color == 1 and 'RED' or 'BLACK', ')\n')
		dump(self, node.rb_left, indent + 1, buf)
		dump(self, node.rb_right, indent + 1, buf)
	end
end

function M.dump(self, buf)
	dump(self, self.root, 0, buf)
	return buf
end

local function height(self, node, h)
	if self == node then return h end
	
	local h1 = height(self, node.rb_left, h + 1)
	local h2 = height(self, node.rb_right, h + 1)
	return h1 > h2 and h1 or h2
end

function M.height(self)
	return height(self, self.root, 0)
end

function M.new()
	local tree = setmetatable({
		root = false,
		count = 0,
		rb_color = 0, -- the tree itself is a sentinel
		
		-- frequently used methods
		insert = M.insert,
		delete = M.delete,
		min = M.min,
		max = M.max,
	}, M)
	tree.root = tree
	return tree
end

return M
