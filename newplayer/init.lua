minetest.register_privilege("nointeract", "Can enter keyword to get interact")
minetest.register_privilege("spawn", "can use spawn command")

newplayer = {}

if type(minetest.colorize) == "function" then
	newplayer.colorize = minetest.colorize
else
	newplayer.colorize = function(color,text)
		return text
	end
end

local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-keywords.txt","r")
if f then
	local d = f:read("*all")
	newplayer.keywords = minetest.deserialize(d)
	f:close()
else
	newplayer.keywords = {}
end

newplayer.assigned_keywords = {}

newplayer.hudids = {}

local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-rules.txt","r")
if f then
	local d = f:read("*all")
	newplayer.rules = minetest.formspec_escape(d)
	f:close()
else
	newplayer.rules = "Rules file not found!\n\nThe file should be named \"newplayer-rules.txt\" and placed in the following location:\n\n"..minetest.get_worldpath()..DIR_DELIM
end

function newplayer.savekeywords()
	local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-keywords.txt","w")
	local d = minetest.serialize(newplayer.keywords)
	f:write(d)
	f:close()
end

local editformspec1 = "size[13,9]"..
	"label[0,-0.1;Editing Server Rules]"..
	"textarea[0.25,0.5;12.5,7;rules;;"
-- the rules get inserted between these two on demand
local editformspec2 = "]"..
	"button_exit[0.5,8.1;2,1;save;Save]"..
	"button_exit[5,8.1;2,1;quit;Cancel]"

function newplayer.showrulesform(name)

	-- Word-wrap the file
	local strstart = 1
	local charpos = 0
	local linelen = 0
	local tline = 1
	local lastbreak = 1

	newplayer.rules_formspec_buffer = ""

	while charpos < #newplayer.rules do
		charpos = charpos + 1
		linelen = linelen + 1
		local c = string.sub(newplayer.rules, charpos, charpos)
		if c == " " or c == "\t" or c == "\n" or c == "\r" then lastbreak = charpos end
		if linelen > 70 or c == "\n" or c == "\r" then
			newplayer.rules_formspec_buffer = newplayer.rules_formspec_buffer..","..string.sub(newplayer.rules, strstart, lastbreak-1)
			tline = tline + 1
			strstart = lastbreak + 1
			charpos = strstart
			linelen = 0
		end
	end

	if #newplayer.keywords > 0 then
		newplayer.assigned_keywords[name] = newplayer.keywords[math.random(1,#newplayer.keywords)]
		newplayer.rules_subbed = string.gsub(newplayer.rules_formspec_buffer,"@KEYWORD",newplayer.assigned_keywords[name])
	else
		newplayer.rules_subbed = newplayer.rules_formspec_buffer
	end
	if #newplayer.keywords > 0 and minetest.check_player_privs(name,{interact=true}) and not minetest.check_player_privs(name,{server=true}) then
		newplayer.rules_subbed_interact = string.gsub(newplayer.rules_formspec_buffer,"@KEYWORD",minetest.formspec_escape("[Hidden because you already have interact]"))
	else
		newplayer.rules_subbed_interact = newplayer.rules_formspec_buffer
	end		
	local form_interact = "size[13,9]"..
				"label[0,-0.1;Server Rules]"..
				"textlist[0.25,0.5;12.5,6.25;rules;"..newplayer.rules_subbed_interact.."]"
	local form_nointeract = "size[13,9]"..
				"label[0,-0.1;Server Rules]"..
				"textlist[0.25,0.5;12.5,6.25;rules;"..newplayer.rules_subbed.."]"..
				"button[1,8;2,1;yes;I agree]"..
				"button[5,8;2,1;no;I do not agree]"
	if #newplayer.keywords > 0 then
		form_nointeract = form_nointeract.."field[0.5,7.6;8,1;keyword;Enter keyword from rules above:;]"
	end
	local hasinteract = minetest.check_player_privs(name,{interact=true})
	if hasinteract then
		if minetest.check_player_privs(name,{server=true}) then
			form_interact = form_interact.."button_exit[0.4,8.1;2,1;quit;OK]"
			form_interact = form_interact.."button[4,8.1;2,1;edit;Edit]"
		else
			form_interact = form_interact.."button_exit[0.4,8.1;2,1;quit;OK]"
		end
		minetest.show_formspec(name,"newplayer:rules_interact",form_interact)
	else
		minetest.show_formspec(name,"newplayer:rules_nointeract",form_nointeract)
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if minetest.check_player_privs(name,{interact=true}) then
		return
	end
	local nointeractspawn = minetest.setting_get_pos("spawnpoint_no_interact")
	if nointeractspawn then
		player:setpos(nointeractspawn)
	end
	if minetest.get_player_privs(name).nointeract and not minetest.get_player_privs(name).interact then
		newplayer.hudids[name] = player:hud_add({
			hud_elem_type = "text",
			position = {x=0.5,y=0.5},
			scale = {x=100,y=100},
			text = "BUILDING DISABLED\nYou must agree to\nthe rules before building!\nUse the /rules command\nto see them.",
			number = 0xFF6666,
			alignment = {x=0,y=0},
			offset = {x=0,y=0}
		})
	end
	if minetest.get_player_privs(name).nointeract then
		
		minetest.after(0,newplayer.showrulesform,name)
		if not minetest.get_player_privs(name).interact then
			player:set_nametag_attributes({color = { a=255,r=255,g=0,b=0 },text = name.." (Guest)",})
		end
	end
end)

minetest.register_on_player_receive_fields(function(player,formname,fields)
	local name = player:get_player_name()
	if formname == "newplayer:rules_nointeract" then
		if fields.yes and minetest.get_player_privs(name).nointeract then
			if  #newplayer.keywords == 0 or (not newplayer.assigned_keywords[name]) or string.lower(fields.keyword) == string.lower(newplayer.assigned_keywords[name]) then
				local privs = minetest.get_player_privs(name)
				local keyword_privs = minetest.string_to_privs(minetest.setting_get("keyword_interact_privs") or "interact,shout,fast")
					for priv, state in pairs(keyword_privs,privs) do
						privs[priv] = state
					end
					privs.nointeract = nil
				minetest.set_player_privs(name, privs)
				player:set_nametag_attributes({color = {a=255, r=255, g=255,b=255},text = name,}) --return tag to normal
				if newplayer.hudids[name] then
					minetest.get_player_by_name(name):hud_remove(newplayer.hudids[name])
					minetest.get_player_by_name(name):hud_remove(newplayer.hudids[name]-1)
					newplayer.hudids[name] = nil
				end
				local spawn = minetest.setting_get_pos("spawnpoint_interact")
				if spawn then
					minetest.chat_send_player(name,"Teleporting to spawn...")
					player:setpos(spawn)
				else
					minetest.chat_send_player(name,newplayer.colorize("#FF0000","ERROR: ").."The spawn point is not set!")
				end
				local form =    "size[6,3]"..
						"label[1,0;Thank you for agreeing]"..
						"label[1,0.5;to the rules!]"..
						"label[1,1;You are now free to play normally.]"..
						"label[1,1.5;You can also use /spawn to return here.]"..
						"button_exit[1.5,2;2,1;quit;OK]"
				minetest.show_formspec(name,"newplayer:agreethanks",form)
			else
				local form =    "size[5,3]"..
						"label[1,0;Incorrect keyword!]"..
						"button[1.5,2;2,1;quit;Try Again]"
				minetest.show_formspec(name,"newplayer:tryagain",form)
			end
		
		elseif fields.yes and not minetest.get_player_privs(name).nointeract then 
			minetest.chat_send_player(name,"You are forbidden from getting interact!")
			local form =    "size[5,3]"..
						"label[1,0;Thank you for agreeing]"..
						"label[1,0.5;to the rules!]"..
						"label[1,1;However you will need.]"..
						"label[1,1.5;to contact an admin to play.]"..
						"button_exit[1.5,2;2,1;quit;OK]"
				minetest.show_formspec(name,"newplayer:nointeract",form)
		
		elseif fields.no then
			local form =    "size[5,3]"..
					"label[1,0;You may remain on the server,]"..
					"label[1,0.5;but you may not dig or build]"..
					"label[1,1;until you agree to the rules.]"..
					"button_exit[1.5,2;2,1;quit;OK]"
			minetest.show_formspec(name,"newplayer:disagreewarning",form)
		end
		return true
	elseif formname == "newplayer:tryagain" then
		newplayer.showrulesform(name)
		return true
	elseif formname == "newplayer:editrules" then
		if minetest.check_player_privs(name, {server=true}) then
			if fields.save then
				local f = io.open(minetest.get_worldpath()..DIR_DELIM.."newplayer-rules.txt","w")
				f:write(fields.rules)
				f:close()
				newplayer.rules = minetest.formspec_escape(fields.rules)
				minetest.chat_send_player(name,newplayer.colorize("#55FF55","Success: ").."Rules/keyword updated.")
			end
		else
			minetest.chat_send_player(name,"You hacker you... nice try!")
		end
	elseif formname == "newplayer:rules_interact" then
		if fields.edit and minetest.check_player_privs(name,{server=true}) then
			minetest.show_formspec(name,"newplayer:editrules",editformspec1..newplayer.rules..editformspec2)
		end
	elseif formname == "newplayer:agreethanks" or formname == "newplayer:disagreewarning" then
		return true
	elseif formname == "newplayer:help" then
		if fields.yes then
			newplayer.showrulesform(name)
		end
		return true
	else
		return false
	end
end)

minetest.register_chatcommand("rules",{
	params = "",
	description = "View the rules",
	func = newplayer.showrulesform
	}
)

minetest.register_chatcommand("editrules",{
	params = "",
	description = "Edit the rules",
	privs = {server=true},
	func = function(name)
		minetest.show_formspec(name,"newplayer:editrules",editformspec1..newplayer.rules..editformspec2)
		return true
	end}
)

minetest.register_chatcommand("set_no_interact_spawn",{
	params = "",
	description = "Set the spawn point for players without interact to your current position",
	privs = {server=true},
	func = function(name)
		local pos = minetest.get_player_by_name(name):getpos()
		minetest.setting_set("spawnpoint_no_interact",string.format("%s,%s,%s",pos.x,pos.y,pos.z))
		minetest.setting_save()
		return true, newplayer.colorize("#55FF55","Success: ").."Spawn point for players without interact set to: "..newplayer.colorize("#00FFFF",minetest.pos_to_string(pos))
	end}
)

minetest.register_chatcommand("set_interact_spawn",{
	params = "",
	description = "Set the spawn point for players with interact to your current position",
	privs = {server=true},
	func = function(name)
		local pos = minetest.get_player_by_name(name):getpos()
		minetest.setting_set("spawnpoint_interact",string.format("%s,%s,%s",pos.x,pos.y,pos.z))
		minetest.setting_save()
		return true, newplayer.colorize("#55FF55","Success: ").."Spawn point for players with interact set to: "..newplayer.colorize("#00FFFF",minetest.pos_to_string(pos))
	end}
)

minetest.register_chatcommand("getkeywords",{
	params = "",
	description = "Gets the list of keywords used to obtain the interact privilege",
	privs = {server=true},
	func = function(name)
		local out = ""
		if #newplayer.keywords > 0 then
			out = "Currently configured keywords:"
			for _,kw in pairs(newplayer.keywords) do
				out = out.."\n"..newplayer.colorize("#00FFFF",kw)
			end
		else
			out = "No keywords are currently set."
		end
		return true, out
	end}
)

minetest.register_chatcommand("addkeyword",{
	params = "<keyword>",
	description = "Add a keyword to the list of keywords used to obtain the interact privilege",
	privs = {server=true},
	func = function(name,param)
		if (not param) or param == "" then
			return true, newplayer.colorize("#FF0000","ERROR: ").."No keyword supplied"
		end
		table.insert(newplayer.keywords,param)
		newplayer.savekeywords()
		return true, string.format("Keyword \"%s\" added",param)
	end}
)

minetest.register_chatcommand("delkeyword",{
	params = "<keyword>",
	description = "Remove a keyword from the list of keywords used to obtain the interact privilege",
	privs = {server=true},
	func = function(name,param)
		if (not param) or param == "" then
			return true, newplayer.colorize("#FF0000","ERROR: ").."No keyword supplied"
		end
		for k,v in pairs(newplayer.keywords) do
			if v == param then
				newplayer.keywords[k] = nil
				newplayer.savekeywords()
				return true, "Keyword "..newplayer.colorize("#00FFFF",param).." removed"
			end
		end
		return true, newplayer.colorize("#FF0000","ERROR: ").."Keyword "..newplayer.colorize("#00FFFF",param).." not found"
	end}
)

minetest.register_chatcommand("spawn",{
	params = "",
	description = "Teleport to the spawn",
	privs = {spawn=true},
	func = function(name)
		local hasinteract = minetest.check_player_privs(name,{interact=true})
		local player = minetest.get_player_by_name(name)
		if hasinteract then
			local pos = minetest.setting_get_pos("spawnpoint_interact")
			if pos then
				player:setpos(pos)
				return true, "Teleporting to spawn..."
			else
				return true, newplayer.colorize("#FF0000","ERROR: ").."The spawn point is not set!"
			end
		else
			local pos = minetest.setting_get_pos("spawnpoint_no_interact")
			if pos then
				player:setpos(pos)
				return true, "Teleporting to spawn..."
			else
				return true, newplayer.colorize("#FF0000","ERROR: ").."The spawn point is not set!"
			end
		end
	end}
)

minetest.register_on_chat_message(function(name, message)
	if minetest.check_player_privs(name,{interact=true}) then
		return
	end
	if message:lower():find("rules") then
		newplayer.showrulesform(name)
	elseif message:lower():find("help") then
		local fs =      "size[5,3]"..
				"label[0,0;In order to build,]"..
				"label[0,0.5;you must read and agree to the rules.]"..
				"label[0,1;View them now?]"..
				"button[0,2;2,1;yes;Yes]"..
				"button_exit[3,2;2,1;quit;No]"
		minetest.show_formspec(name,"newplayer:help",fs)
	end
end)
