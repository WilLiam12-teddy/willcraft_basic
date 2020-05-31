
local S = mobs.intllib

-- name tag
minetest.register_craftitem("mobs:nametag", {
	description = S("Name Tag"),
	inventory_image = "mobs_nametag.png",
	groups = {flammable = 2},
})

if minetest.get_modpath("dye") and minetest.get_modpath("farming") then
	minetest.register_craft({
		type = "shapeless",
		output = "mobs:nametag",
		recipe = {"default:paper", "dye:black", "farming:string"},
	})
end

-- leather
minetest.register_craftitem("mobs:leather", {
	description = S("Leather"),
	inventory_image = "mobs_leather.png",
	groups = {flammable = 2},
})

-- raw meat
minetest.register_craftitem("mobs:meat_raw", {
	description = S("Raw Meat"),
	inventory_image = "mobs_meat_raw.png",
	on_use = minetest.item_eat(3),
	groups = {food_meat_raw = 1, flammable = 2},
})

-- cooked meat
minetest.register_craftitem("mobs:meat", {
	description = S("Meat"),
	inventory_image = "mobs_meat.png",
	on_use = minetest.item_eat(8),
	groups = {food_meat = 1, flammable = 2},
})

minetest.register_craft({
	type = "cooking",
	output = "mobs:meat",
	recipe = "mobs:meat_raw",
	cooktime = 5,
})

-- lasso
minetest.register_tool("mobs:lasso", {
	description = S("Lasso (right-click animal to put in inventory)"),
	inventory_image = "mobs_magic_lasso.png",
	groups = {flammable = 2},
})

if minetest.get_modpath("farming") then
	minetest.register_craft({
		output = "mobs:lasso",
		recipe = {
			{"farming:string", "", "farming:string"},
			{"", "default:diamond", ""},
			{"farming:string", "", "farming:string"},
		}
	})
end

minetest.register_alias("mobs:magic_lasso", "mobs:lasso")

-- net
minetest.register_tool("mobs:net", {
	description = S("Net (right-click animal to put in inventory)"),
	inventory_image = "mobs_net.png",
	groups = {flammable = 2},
})

if minetest.get_modpath("farming") then
	minetest.register_craft({
		output = "mobs:net",
		recipe = {
			{"group:stick", "", "group:stick"},
			{"group:stick", "", "group:stick"},
			{"farming:string", "group:stick", "farming:string"},
		}
	})
end

-- shears (right click to shear animal)
minetest.register_tool("mobs:shears", {
	description = S("Steel Shears (right-click to shear)"),
	inventory_image = "mobs_shears.png",
	groups = {flammable = 2},
})

minetest.register_craft({
	output = 'mobs:shears',
	recipe = {
		{'', 'default:steel_ingot', ''},
		{'', 'group:stick', 'default:steel_ingot'},
	}
})

-- saddle
minetest.register_craftitem("mobs:saddle", {
	description = S("Saddle"),
	inventory_image = "mobs_saddle.png",
	groups = {flammable = 2},
})

minetest.register_craft({
	output = "mobs:saddle",
	recipe = {
		{"mobs:leather", "mobs:leather", "mobs:leather"},
		{"mobs:leather", "default:steel_ingot", "mobs:leather"},
		{"mobs:leather", "default:steel_ingot", "mobs:leather"},
	}
})

-- items that can be used as fuel
minetest.register_craft({
	type = "fuel",
	recipe = "mobs:nametag",
	burntime = 3,
})

minetest.register_craft({
	type = "fuel",
	recipe = "mobs:lasso",
	burntime = 7,
})

minetest.register_craft({
	type = "fuel",
	recipe = "mobs:net",
	burntime = 8,
})

minetest.register_craft({
	type = "fuel",
	recipe = "mobs:leather",
	burntime = 4,
})

minetest.register_craft({
	type = "fuel",
	recipe = "mobs:saddle",
	burntime = 7,
})

-- this tool spawns same mob and adds owner, protected, nametag info
-- then removes original entity, this is used for fixing any issues.

local tex_obj

minetest.register_tool(":mobs:mob_reset_stick", {
	description = "Mob Reset Stick",
	inventory_image = "default_stick.png^[colorize:#ff000050",
	stack_max = 1,
	groups = {not_in_creative_inventory = 1},

	on_use = function(itemstack, user, pointed_thing)

		if pointed_thing.type ~= "object" then
			return
		end

		local obj = pointed_thing.ref

		local control = user:get_player_control()
		local sneak = control and control.sneak

		if obj and not sneak then

			local self = obj:get_luaentity()
			local obj2 = minetest.add_entity(obj:get_pos(), self.name)

			if obj2 then

				local ent2 = obj2:get_luaentity()

				ent2.protected = self.protected
				ent2.owner = self.owner
				ent2.nametag = self.nametag
				ent2.gotten = self.gotten
				ent2.tamed = self.tamed
				ent2.health = self.health
				ent2.order = self.order

				if self.child then
					obj2:set_velocity({x = 0, y = self.jump_height, z = 0})
				end

				obj2:set_properties({nametag = self.nametag})

				obj:remove()
			end
		end

		if obj and sneak then

			tex_obj = obj

			local name = user:get_player_name()
			local tex = ""

			minetest.show_formspec(name, "mobs_texture", "size[8,4]"
			.. "field[0.5,1;7.5,0;name;"
			.. minetest.formspec_escape(S("Enter texture:")) .. ";" .. tex .. "]"
			.. "button_exit[2.5,3.5;3,1;mob_texture_change;"
			.. minetest.formspec_escape(S("Change")) .. "]")
		end
	end,
})

minetest.register_on_player_receive_fields(function(player, formname, fields)

	-- right-clicked with nametag and name entered?
	if formname == "mobs_texture"
	and fields.name
	and fields.name ~= "" then

		local name = player:get_player_name()

		if not tex_obj then
			return
		end

		-- make sure nametag is being used to name mob
		local item = player:get_wielded_item()

		if item:get_name() ~= "mobs:mob_reset_stick" then
			return
		end

		-- limit name entered to 64 characters long
		if string.len(fields.name) > 64 then
			fields.name = string.sub(fields.name, 1, 64)
		end

		-- update texture
		local self = tex_obj:get_luaentity()

		self.base_texture = {fields.name}

		tex_obj:set_properties({textures = {fields.name}})

		-- reset external variable
		tex_obj = nil
	end
end)
