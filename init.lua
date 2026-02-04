-- Copyright (c) 2021 Dmitry Kostenko. Licensed under AGPL v3

-- Parsing utilities

local function starts_with(str, prefix)
	return str:sub(1, #prefix) == prefix
end

local function skip_prefix(str, prefix)
	return str:sub(#prefix + 1)
end

local function string_split(str, char)
	result = {}
	for part in str:gmatch("[^"..char.."]+") do
		table.insert(result, part)
	end
	return result
end

local function is_in(item, set)
	for _,valid in ipairs(set) do
		if item == valid then return true end
	end
	return false
end

-- Position helpers

local position = {}
function position.save(player, slot)
	local state = { pos = player:get_pos(), look = { h = player:get_look_horizontal(), v = player:get_look_vertical() }}
	player:get_meta():set_string("cc_pos_"..slot, minetest.serialize(state))
end

function position.get(player, slot)
	local state = player:get_meta():get_string("cc_pos_"..slot)
	if state == nil then
		return nil, "Saved position not found"
	end

	state = minetest.deserialize(state)
	if state == nil then
		return nil, "Saved position could not be restored"
	end

	return state
end

function position.restore(player, slot)
	local state,message = position.get(player, slot)
	if state == nil then
		minetest.chat_send_player(player:get_player_name(), message)
		return
	end

	player:set_pos(state.pos)
	player:set_look_horizontal(state.look.h)
	player:set_look_vertical(state.look.v)
end

function position.clear(player, slot)
	player:get_meta():set_string("cc_pos_"..slot, "")
end

function position.list(player)
	local result = {}
  for key,_ in pairs(player:get_meta():to_table().fields) do
		if starts_with(key, "cc_pos_") then
			table.insert(result, skip_prefix(key, "cc_pos_"))
		end
	end
	return result
end

-- Waypoint helpers

local wp_storage = minetest.get_mod_storage()

local waypoint = {}
function waypoint.get_list(player)
	local raw = player:get_meta():get_string("cc_wp")
	if raw == nil or raw == "" then
		return {}
	end

	local list = minetest.deserialize(raw)
	if list == nil then
		return {}
	end

	return list
end

function waypoint.save_list(player, list)
	player:get_meta():set_string("cc_wp", minetest.serialize(list))
end

function waypoint.add_current(player, stop)
	local list = waypoint.get_list(player)
	table.insert(list, {
		pos = player:get_pos(),
		look = { h = player:get_look_horizontal(), v = player:get_look_vertical() },
		stop = stop,
	})
	waypoint.save_list(player, list)
	return #list
end

function waypoint.clear(player)
	player:get_meta():set_string("cc_wp", "")
end

function waypoint.playlist_list()
	local raw = wp_storage:get_string("wp_playlist_index")
	if raw == nil or raw == "" then
		return {}
	end

	local list = minetest.deserialize(raw)
	if list == nil then
		return {}
	end

	return list
end

function waypoint.playlist_get(name)
	local raw = wp_storage:get_string("wp_playlist:"..name)
	if raw == nil or raw == "" then
		return nil
	end

	local list = minetest.deserialize(raw)
	return list
end

function waypoint.playlist_save(name, list)
	wp_storage:set_string("wp_playlist:"..name, minetest.serialize(list))
	local index = waypoint.playlist_list()
	for _, entry in ipairs(index) do
		if entry == name then
			return
		end
	end
	table.insert(index, name)
	wp_storage:set_string("wp_playlist_index", minetest.serialize(index))
end

function waypoint.playlist_remove(name)
	wp_storage:set_string("wp_playlist:"..name, "")
	local index = waypoint.playlist_list()
	local next_index = {}
	for _, entry in ipairs(index) do
		if entry ~= name then
			table.insert(next_index, entry)
		end
	end
	wp_storage:set_string("wp_playlist_index", minetest.serialize(next_index))
end

-- Core API
local cinematic
cinematic = {
	motions = {},
	register_motion = function(name, definition)
		definition.name = name
		cinematic.motions[name] = definition
		table.insert(cinematic.motions, definition)
	end,

	commands = {},
	register_command = function(name, definition)
		definition.name = name
		cinematic.commands[name] = definition
		table.insert(cinematic.commands, definition)
	end,

	players = {},
	start = function(player, motion, params)
		local player_name = player:get_player_name()
		-- Stop previous motion and clean up
		if cinematic.players[player_name] ~= nil then
			player:set_fov(unpack(cinematic.players[player_name].fov))
			cinematic.players[player_name] = nil
		end

		local state = cinematic.motions[motion].initialize(player, params)
		-- motion can return nil from initialize to abort the process
		if state ~= nil then
			position.save(player, "auto")
			cinematic.players[player_name] = { player = player, motion = motion, state = state, fov = {player:get_fov()} }

			if params.fov == "wide" then
				params.fov = 1.4
			elseif params.fov == "narrow" then
				params.fov = 0.5
			elseif params.fov ~= nil then
				params.fov = tonumber(params.fov)
			end
			if params.fov ~= nil then
				player:set_fov(params.fov, true)
			end
		end
	end,
	stop = function(player)
		cinematic.start(player, "stop", {})
	end,
}

-- Update loop

minetest.register_globalstep(function(dtime)
	for _, entry in pairs(cinematic.players) do
		cinematic.motions[entry.motion].tick(entry.player, entry.state, dtime)
	end
end)

-- Motions

cinematic.register_motion("360", {
	initialize = function(player, params)
		local player_pos = player:get_pos()
		local center = vector.add(player_pos, vector.multiply(vector.normalize(player:get_look_dir()), params.radius or 50))
		return {
			center = center,
			distance = vector.distance(vector.new(center.x, 0, center.z), vector.new(player_pos.x, 0, player_pos.z)),
			angle = minetest.dir_to_yaw(vector.subtract(player_pos, center)) + math.pi / 2,
			height = player_pos.y - center.y,
			speed = params:get_speed({"l", "left"}, "right"),
		}
	end,
	tick = function(player, state)
		state.angle = state.angle + state.speed * math.pi / 3600
		if state.angle < 0 then state.angle = state.angle + 2 * math.pi end
		if state.angle > 2 * math.pi then state.angle = state.angle - 2 * math.pi end

		player_pos = vector.add(state.center, vector.new(state.distance * math.cos(state.angle), state.height, state.distance * math.sin(state.angle)))
		player:set_pos(player_pos)
		player:set_look_horizontal(state.angle + math.pi / 2)
	end
})

cinematic.register_motion("dolly", {
	initialize = function(player, params)
		return {
			speed = params:get_speed({"b", "back", "backwards", "out"}, "forward"),
			direction = vector.normalize(vector.new(player:get_look_dir().x, 0, player:get_look_dir().z)),
		}
	end,
	tick = function(player, state)
		local player_pos = player:get_pos()

		player_pos = vector.add(player_pos, vector.multiply(state.direction, state.speed * 0.05))
		player:set_pos(player_pos)
	end
})

cinematic.register_motion("truck", {
	initialize = function(player, params)
		return {
			speed = params:get_speed({"l", "left"}, "right"),
			direction = vector.normalize(vector.cross(vector.new(0,1,0), player:get_look_dir())),
		}
	end,
	tick = function(player, state)
		local player_pos = player:get_pos()

		player_pos = vector.add(player_pos, vector.multiply(state.direction, state.speed * 0.05))
		player:set_pos(player_pos)
	end
})

cinematic.register_motion("pedestal", {
	initialize = function(player, params)
		return {
			speed = params:get_speed({"d", "down"}, "up"),
			direction = vector.new(0,1,0)
		}
	end,
	tick = function(player, state)
		local player_pos = player:get_pos()

		player_pos = vector.add(player_pos, vector.multiply(state.direction, state.speed * 0.05))
		player:set_pos(player_pos)
	end
})

cinematic.register_motion("pan", {
	initialize = function(player, params)
		return {
			speed = params:get_speed({"l", "left"}, "right"),
			angle = player:get_look_horizontal()
		}
	end,
	tick = function(player, state)
		state.angle = state.angle - state.speed * math.pi / 3600
		if state.angle < 0 then state.angle = state.angle + 2 * math.pi end
		if state.angle > 2 * math.pi then state.angle = state.angle - 2 * math.pi end
		player:set_look_horizontal(state.angle)
	end
})

cinematic.register_motion("tilt", {
	initialize = function(player, params)
		return {
			speed = params:get_speed({"d", "down"}, "up"),
			angle = player:get_look_vertical()
		}
	end,
	tick = function(player, state)
		state.angle = state.angle - state.speed * math.pi / 3600
		if state.angle < 0 then state.angle = state.angle + 2 * math.pi end
		if state.angle > 2 * math.pi then state.angle = state.angle - 2 * math.pi end
		player:set_look_vertical(state.angle)
	end
})

cinematic.register_motion("zoom", {
	initialize = function(player, params)
		return {
			speed = params:get_speed({"out"}, "in"),
		}
	end,
	tick = function(player, state)
		-- Capture initial FOV at the tick
		-- This is not possible in initialize because the FOV modifier has not been applied yet
		if state.fov == nil then
			local fov = {player:get_fov()}
			minetest.chat_send_all(dump(fov,""))
			if fov[1] == 0 then
				fov[1] = 1
				fov[2] = true
			end
			fov[3] = 0
			state.fov = fov
		end
		state.fov[1] = state.fov[1] - 0.001 * state.speed
		player:set_fov(unpack(state.fov))
	end
})

cinematic.register_motion("stop", {initialize = function() end})
cinematic.register_motion("revert", {initialize = function(player) position.restore(player, "auto") end})

cinematic.register_motion("waypoints", {
	initialize = function(player, params)
		local list = params.list or waypoint.get_list(player)
		if #list == 0 then
			minetest.chat_send_player(player:get_player_name(), "No waypoints found. Use /wp add first.")
			return nil
		end

		local speed = params.speed or 4
		if speed <= 0 then speed = 4 end

		local start_pos = player:get_pos()
		local start_look = { h = player:get_look_horizontal(), v = player:get_look_vertical() }
		local target = list[1]
		local distance = vector.distance(start_pos, target.pos)
		local duration = distance / speed
		if duration < 0.1 then duration = 0.1 end

		return {
			list = list,
			index = 1,
			speed = speed,
			t = 0,
			duration = duration,
			from = { pos = start_pos, look = start_look },
			to = target,
		}
	end,
	tick = function(player, state, dtime)
		if dtime == nil then dtime = 0.05 end
		state.t = state.t + dtime
		local progress = state.t / state.duration
		if progress > 1 then progress = 1 end

		local eased = progress
		if state.to.stop ~= false then
			-- Smoothstep easing for cinematic movement when stopping
			eased = progress * progress * (3 - 2 * progress)
		end

		local from_pos = state.from.pos
		local to_pos = state.to.pos
		local new_pos = vector.new(
			from_pos.x + (to_pos.x - from_pos.x) * eased,
			from_pos.y + (to_pos.y - from_pos.y) * eased,
			from_pos.z + (to_pos.z - from_pos.z) * eased
		)
		player:set_pos(new_pos)

		local from_h = state.from.look.h
		local to_h = state.to.look.h
		local delta_h = (to_h - from_h + math.pi) % (2 * math.pi) - math.pi
		player:set_look_horizontal(from_h + delta_h * eased)

		local from_v = state.from.look.v
		local to_v = state.to.look.v
		player:set_look_vertical(from_v + (to_v - from_v) * eased)

		if progress >= 1 then
			state.index = state.index + 1
			if state.index > #state.list then
				cinematic.stop(player)
				return
			end

			state.t = 0
			state.from = state.to
			state.to = state.list[state.index]
			local distance = vector.distance(state.from.pos, state.to.pos)
			state.duration = distance / state.speed
			if state.duration < 0.1 then state.duration = 0.1 end
		end
	end
})

cinematic.register_command("pos", {
	run = function(player, args)
		local slot = args[2] or "default"

		if args[1] == "save" then
			position.save(player, slot)
			return true
		elseif args[1] == "restore" then
			position.restore(player, slot)
			return true
		elseif args[1] == "clear" then
			position.clear(player, slot)
		elseif args[1] == "list" then
			for _,slot in ipairs(position.list(player)) do
				minetest.chat_send_player(player:get_player_name(), slot)
			end
		else
			return false, "Unknown subcommand"..args[1]
		end
	end
})

cinematic.register_command("wp", {
	run = function(player, args)
		local sub = args[1]
		if sub == "add" then
			local mode = args[2]
			local stop = true
			if mode == "flow" or mode == "fluent" or mode == "continuous" or mode == "go" then
				stop = false
			elseif mode ~= nil and mode ~= "stop" then
				return false, "Unknown waypoint mode "..mode
			end

			local count = waypoint.add_current(player, stop)
			minetest.chat_send_player(player:get_player_name(), "Waypoint "..count.." added.")
			return true
		elseif sub == "clear" then
			waypoint.clear(player)
			minetest.chat_send_player(player:get_player_name(), "Waypoints cleared.")
			return true
		else
			return false, "Unknown subcommand "..(sub or "")
		end
	end
})

cinematic.register_command("playlist", {
	run = function(player, args)
		local sub = args[1]
		if sub == "save" then
			local name = args[2]
			if name == nil or name == "" then
				return false, "Missing playlist name"
			end
			local list = waypoint.get_list(player)
			if #list == 0 then
				return false, "No waypoints to save"
			end
			waypoint.playlist_save(name, list)
			minetest.chat_send_player(player:get_player_name(), "Playlist "..name.." saved.")
			return true
		elseif sub == "start" then
			local name = nil
			local params = {}
			for i = 2,#args do
				local parsed = false
				for _,setting in ipairs({ "speed", "v" }) do
					if not parsed and starts_with(args[i], setting.."=") then
						params[setting] = skip_prefix(args[i], setting.."=")
						parsed = true
					end
				end
				if not parsed and name == nil then
					name = args[i]
					parsed = true
				end
				if not parsed then
					return false, "Invalid parameter "..args[i]
				end
			end

			if name == nil or name == "" then
				return false, "Missing playlist name"
			end
			local list = waypoint.playlist_get(name)
			if list == nil or #list == 0 then
				return false, "Playlist not found: "..name
			end
			local first = list[1]
			player:set_pos(first.pos)
			player:set_look_horizontal(first.look.h)
			player:set_look_vertical(first.look.v)
			params.speed = params.speed or params.v
			params.speed = (params.speed and tonumber(params.speed))
			params.list = list
			cinematic.start(player, "waypoints", params)
			return true
		elseif sub == "remove" then
			local name = args[2]
			if name == nil or name == "" then
				return false, "Missing playlist name"
			end
			waypoint.playlist_remove(name)
			minetest.chat_send_player(player:get_player_name(), "Playlist "..name.." removed.")
			return true
		elseif sub == "list" then
			local list = waypoint.playlist_list()
			if #list == 0 then
				minetest.chat_send_player(player:get_player_name(), "No playlists saved.")
				return true
			end
			for _, entry in ipairs(list) do
				minetest.chat_send_player(player:get_player_name(), entry)
			end
			return true
		else
			return false, "Unknown subcommand "..(sub or "")
		end
	end
})

cinematic.register_command("cancel", {
	run = function(player)
		cinematic.stop(player)
		return true
	end
})

cinematic.register_command("start", {
	run = function(player, args)
		local params = {}
		local list_name = nil
		for i = 1,#args do
			local parsed = false
			for _,setting in ipairs({ "speed", "v" }) do
				if not parsed and starts_with(args[i], setting.."=") then
					params[setting] = skip_prefix(args[i], setting.."=")
					parsed = true
				end
			end
			if not parsed and list_name == nil then
				list_name = args[i]
				parsed = true
			end
			if not parsed then
				return false, "Invalid parameter "..args[i]
			end
		end

		params.speed = params.speed or params.v
		params.speed = (params.speed and tonumber(params.speed))

		local list = nil
		if list_name ~= nil then
			list = waypoint.playlist_get(list_name)
			if list == nil or #list == 0 then
				return false, "Playlist not found: "..list_name
			end
		else
			list = waypoint.get_list(player)
		end
		if #list == 0 then
			return false, "No waypoints found. Use /wp add first."
		end

		local first = list[1]
		player:set_pos(first.pos)
		player:set_look_horizontal(first.look.h)
		player:set_look_vertical(first.look.v)

		params.list = list
		cinematic.start(player, "waypoints", params)
		return true,""
	end
})

-- Chat command handler

minetest.register_chatcommand("cc", {
	params = "((360|tilt|pan|truck|dolly|pedestal) [direction=(right|left|in|out|up|down)] [speed=<speed>] [radius=<radius>] | pos ((save|restore|clear [<name>])|list)) | (stop|revert)",
	description = "Simulate cinematic camera motion",
	privs = { fly = true },
	func = function(name, cmdline)
		local player = minetest.get_player_by_name(name)
		local params = {}
		local parts = string_split(cmdline, " ")

		local command = parts[1]
		table.remove(parts, 1)
		-- Handle commands
		if command == "wp" or command == "start" or command == "cancel" or command == "playlist" then
			return false, "Waypoint commands moved to /wp"
		end
		if cinematic.commands[command] ~= nil then
			return cinematic.commands[command].run(player, parts)
		end

		if cinematic.motions[command] == nil then
			return false, "Invalid command or motion, see /help cc"
		end

		-- Parse command line
		for i = 1,#parts do
			local parsed = false
			for _,setting in ipairs({ "direction", "dir", "speed", "v", "radius", "r", "fov" }) do
				if not parsed and starts_with(parts[i], setting.."=") then
					params[setting] = skip_prefix(parts[i], setting.."=")
					parsed = true
				end
			end
			if not parsed then
				return false, "Invalid parameter "..parts[i]
			end
		end

		-- Fix parameters
		params.direction = params.direction or params.dir
		params.speed = params.speed or params.v
		params.radius = params.radius or params.r

		params.speed = (params.speed and tonumber(params.speed))
		params.radius = (params.radius and tonumber(params.radius))

		params.get_speed = function(self, negative_dirs, default_dir)
			return (self.speed or 1) * (is_in(self.direction or default_dir, negative_dirs) and -1 or 1)
		end

		cinematic.start(player, command, params)
		return true,""
	end
})

minetest.register_chatcommand("wp", {
	params = "(add [stop|flow] | clear | start [name] [speed=<speed>] | cancel | playlist (save <name> | start <name> [speed=<speed>] | remove <name> | list))",
	description = "Waypoint camera path control",
	privs = { fly = true },
	func = function(name, cmdline)
		local player = minetest.get_player_by_name(name)
		local parts = string_split(cmdline, " ")

		local command = parts[1]
		table.remove(parts, 1)

		if command == nil or command == "" then
			return false, "Missing subcommand, see /help wp"
		end

		if command == "start" or command == "cancel" then
			return cinematic.commands[command].run(player, parts)
		end

		if command == "add" or command == "clear" then
			return cinematic.commands["wp"].run(player, { command, unpack(parts) })
		end

		if command == "playlist" then
			return cinematic.commands["playlist"].run(player, parts)
		end

		return false, "Unknown subcommand "..command
	end
})
