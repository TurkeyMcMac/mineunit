mineunit("common/vector")
mineunit("game/misc")
mineunit("world")

local VoxelManip = {}

local function pos2blockpos(p)
	return vector.floor(vector.divide(p, core.MAP_BLOCKSIZE))
end

local function block_min_pos(bp)
	return vector.multiply(bp, core.MAP_BLOCKSIZE)
end

local function block_max_pos(bp)
	return vector.add(block_min_pos(bp), core.MAP_BLOCKSIZE - 1)
end

local function sort_box(minp, maxp)
	minp.x, maxp.x = math.min(minp.x, maxp.x), math.max(minp.x, maxp.x)
	minp.y, maxp.y = math.min(minp.y, maxp.y), math.max(minp.y, maxp.y)
	minp.z, maxp.z = math.min(minp.z, maxp.z), math.max(minp.z, maxp.z)
end

local ignore_node = {name = "ignore", param1 = 0, param2 = 0}

-- This must be a separate object from ignore_node.
local unloaded_node = {name = "ignore", param1 = 0, param2 = 0}

local nodes_mt = {
	__index = function() return unloaded_node end,
	-- This prevents addition of nodes outside loaded areas:
	__newindex = function() end,
}

--
-- VoxelManip public API
--

function VoxelManip:get_emerged_area()
	return vector.new(self._emin), vector.new(self._emax)
end

function VoxelManip:read_from_map(p1, p2)
	local bpmin = pos2blockpos(p1)
	local bpmax = pos2blockpos(p2)
	sort_box(bpmin, bpmax)

	local minp = block_min_pos(bpmin)
	local maxp = block_max_pos(bpmax)

	self._emin.x = math.min(self._emin.x, minp.x)
	self._emin.y = math.min(self._emin.y, minp.y)
	self._emin.z = math.min(self._emin.z, minp.z)
	self._emax.x = math.max(self._emax.x, maxp.x)
	self._emax.y = math.max(self._emax.y, maxp.y)
	self._emax.z = math.max(self._emax.z, maxp.z)

	local p = vector.new(minp)
	while p.z <= maxp.z do
		while p.y <= maxp.y do
			while p.x <= maxp.x do
				local hash = core.hash_node_position(p)
				rawset(self._nodes, hash, world.nodes[hash] or ignore_node)
				p.x = p.x + 1
			end
			p.x = minp.x
			p.y = p.y + 1
		end
		p.y = minp.y
		p.z = p.z + 1
	end

	return self:get_emerged_area()
end

function VoxelManip:write_to_map()
	local emin, emax = self._emin, self._emax
	local p = vector.new(emin)
	while p.z <= emax.z do
		while p.y <= emax.y do
			while p.x <= emax.x do
				local hash = core.hash_node_position(p)
				local node = self._nodes[hash]
				if node ~= unloaded_node then
					world.nodes[hash] = node
				end
				p.x = p.x + 1
			end
			p.x = emin.x
			p.y = p.y + 1
		end
		p.y = emin.y
		p.z = p.z + 1
	end
end

function VoxelManip:update_liquids()
end

function VoxelManip:update_map()
end

function VoxelManip:get_node_at(pos)
	local node = self._nodes[core.hash_node_position(pos)]
	return {name = node.name, param1 = node.param1, param2 = node.param2}
end

function VoxelManip:set_node_at(pos, node)
	local nodedef = core.registered_nodes[node.name]
	if nodedef == nil then
		error("Invalid node name '" .. tostring(node.name) .. "'")
	end
	self._nodes[core.hash_node_position(pos)] = {
		name = nodedef.name,
		param1 = node.param1 or 0,
		param2 = node.param2 or 0,
	}
end

function VoxelManip:get_data(buf)
	buf = buf or {}

	local emin, emax = self._emin, self._emax
	local i = 1
	local p = vector.new(emin)
	while p.z <= emax.z do
		while p.y <= emax.y do
			while p.x <= emax.x do
				buf[i] = core.get_content_id(self._nodes[core.hash_node_position(p)].name)
				i = i + 1
				p.x = p.x + 1
			end
			p.x = emin.x
			p.y = p.y + 1
		end
		p.y = emin.y
		p.z = p.z + 1
	end

	return buf
end

function VoxelManip:get_light_data()
	local buf = {}

	local emin, emax = self._emin, self._emax
	local i = 1
	local p = vector.new(emin)
	while p.z <= emax.z do
		while p.y <= emax.y do
			while p.x <= emax.x do
				buf[i] = self._nodes[core.hash_node_position(p)].param1
				i = i + 1
				p.x = p.x + 1
			end
			p.x = emin.x
			p.y = p.y + 1
		end
		p.y = emin.y
		p.z = p.z + 1
	end

	return buf
end

function VoxelManip:get_param2_data(buf)
	buf = buf or {}

	local emin, emax = self._emin, self._emax
	local i = 1
	local p = vector.new(emin)
	while p.z <= emax.z do
		while p.y <= emax.y do
			while p.x <= emax.x do
				buf[i] = self._nodes[core.hash_node_position(p)].param2
				i = i + 1
				p.x = p.x + 1
			end
			p.x = emin.x
			p.y = p.y + 1
		end
		p.y = emin.y
		p.z = p.z + 1
	end

	return buf
end

function VoxelManip:set_data(buf)
	local emin, emax = self._emin, self._emax
	local i = 1
	local p = vector.new(emin)
	while p.z <= emax.z do
		while p.y <= emax.y do
			while p.x <= emax.x do
				local hash = core.hash_node_position(p)
				local oldnode = self._nodes[hash]
				self._nodes[hash] = {
					name = core.get_name_from_content_id(buf[i]),
					param1 = oldnode.param1,
					param2 = oldnode.param2,
				}
				i = i + 1
				p.x = p.x + 1
			end
			p.x = emin.x
			p.y = p.y + 1
		end
		p.y = emin.y
		p.z = p.z + 1
	end

	return buf
end

function VoxelManip:set_light_data(buf)
	local emin, emax = self._emin, self._emax
	local i = 1
	local p = vector.new(emin)
	while p.z <= emax.z do
		while p.y <= emax.y do
			while p.x <= emax.x do
				local hash = core.hash_node_position(p)
				local oldnode = self._nodes[hash]
				self._nodes[hash] = {
					name = oldnode.name,
					param1 = buf[i],
					param2 = oldnode.param2,
				}
				i = i + 1
				p.x = p.x + 1
			end
			p.x = emin.x
			p.y = p.y + 1
		end
		p.y = emin.y
		p.z = p.z + 1
	end

	return buf
end

function VoxelManip:set_param2_data(buf)
	local emin, emax = self._emin, self._emax
	local i = 1
	local p = vector.new(emin)
	while p.z <= emax.z do
		while p.y <= emax.y do
			while p.x <= emax.x do
				local hash = core.hash_node_position(p)
				local oldnode = self._nodes[hash]
				self._nodes[hash] = {
					name = oldnode.name,
					param1 = oldnode.param1,
					param2 = buf[i],
				}
				i = i + 1
				p.x = p.x + 1
			end
			p.x = emin.x
			p.y = p.y + 1
		end
		p.y = emin.y
		p.z = p.z + 1
	end

	return buf
end

mineunit.export_object(VoxelManip, {
	name = "VoxelManip",
	constructor = function(self, p1, p2)
		local vm = {
			-- These nodes must not mutate.
			_nodes = setmetatable({}, nodes_mt),
			_emin = vector.new(1, 1, 1),
			_emax = vector.new(0, 0, 0),
		}
		setmetatable(vm, self)
		if type(p1) == "table" and type(p2) == "table" then
			vm:read_from_map(p1, p2)
		end
		return vm
	end,
})

function core.get_voxel_manip(p1, p2)
	return VoxelManip(p1, p2)
end
