-- =============================================================================
-- 🤠 MOD HARDCORE SUPREMO - VERSÃO EXPANSÃO (VILAS, SONO E FARMS PORTÁTEIS)
-- =============================================================================

local S = minetest.get_translator("ai_players")
local available_names = {
    "Junior", "Mind", "CrazyZebraABC", "MathPro", "1subaltern", "ChinaUserFromCanada", 
    "TheBestMiner", "ChocolateBee", "OrangeLover", "Luigi", "Mario", "BestPVPuser1",
    "ChickenNugget4", "Hamburger0192", "Friend", "CorridorOfEverything", "AngryUser1", "LongLegs", "ChickFarm"
}

local prohibited_blocks = {
    ["mcl_chests:chest"] = true, ["default:chest"] = true,
    ["mcl_furnaces:furnace"] = true, ["default:furnace"] = true,
    ["mcl_beds:bed"] = true, ["default:bed"] = true,
    ["mcl_doors:door"] = true, ["default:door"] = true,
    ["mcl_core:torch"] = true, ["default:torch"] = true
}

-- =============================================================================
-- 🏗️ BLOCOS DE FARM PORTÁTIL AFK (GERADORES AUTOMÁTICOS)
-- =============================================================================

-- 1. Farm AFK de Monstros Simples (generates monsters items each 10 seconds)
minetest.register_node("ai_players:afk_monsters_farm", {
    description = "§c[Portable Afk Farm] Mobs Generator",
    tiles = {"mcl_core_gold_block.png"}, -- styled gold block
    groups = {pickaxey = 1, cracky = 1},
    on_construct = function(pos)
        -- Starts the farm timer
        local timer = minetest.get_node_timer(pos)
        timer:start(10)
    end,
    on_timer = function(pos, elapsed)
        local itens_mob = {"mcl_mobitems:rotten_flesh", "mcl_mobitems:bone", "mcl_mobitems:string", "mcl_mobitems:gunpowder"}
        local item_sorteado = itens_mob[math.random(#itens_mob)]
        -- Drops the item on the block
        minetest.add_item({x=pos.x, y=pos.y+1, z=pos.z}, item_sorteado .. " " .. math.random(1, 2))
        return true -- keeps the timer looping forever
    end,
})

-- 2. Farm AFK de Ferro (Gera ferro se houver villagers/camas por perto, simula a regra)
minetest.register_node("ai_players:iron_block_generator", {
    description = "§7[Portable Afk Farm] Iron Generator",
    tiles = {"mcl_core_iron_block.png"}, -- Iron Block
    groups = {pickaxey = 1, cracky = 1},
    on_construct = function(pos)
        local timer = minetest.get_node_timer(pos)
        timer:start(12)
    end,
    on_timer = function(pos, elapsed)
        -- Checa se tem vilas ou entidades perto simulando a necessidade de villagers
        local objetos = minetest.get_objects_inside_radius(pos, 15)
        local tem_gente = #objetos > 0 -- No Luanti/Mineclonia, qualquer entidade/villager ativa
        
        if tem_gente then
            minetest.add_item({x=pos.x, y=pos.y+1, z=pos.z}, "mcl_core:iron_ingot " .. math.random(1, 3))
        end
        return true
    end,
})

-- =============================================================================
-- 📦 ITEM DE SPAWN ILIMITADO DO BOT
-- =============================================================================
minetest.register_craftitem("ai_players:ai_spawn_egg", {
    description = "AI Spawner (Unlimited)",
    inventory_image = "mcl_tools_diamond_pickaxe.png^[colorize:#ff0000:100",
    on_place = function(itemstack, placer, pointed_thing)
        if pointed_thing.type ~= "node" then return end
        local pos = pointed_thing.above
        pos.y = pos.y + 0.5
        local name_got = available_names[math.random(#available_names)]
        local ent = minetest.add_entity(pos, "ai_players:ai_friend")
        if ent then
            local lua_ent = ent:get_luaentity()
            lua_ent.bot_name = name_got
            ent:set_properties({nametag = name_got, nametag_color = "#00ff00"})
            minetest.chat_send_all("<" .. name_got .. S("> Hello, i came to help you with your journey!"))
        end
        return itemstack
    end,
})

minetest.register_on_joinplayer(function(player)
    local inv = player:get_inventory()
    if not inv:contains_item ("main", "ai_players:ai_spawn_egg") then
        inv:add_item ("main", "ai_players:ai_spawn_egg")
    end
end)

-- =============================================================================
-- 🤖 ENTIDADE DO BOT INTELIGENTE EXPANDIDO
-- =============================================================================
minetest.register_entity ("ai_players:ai_friend", {
    initial_properties = {
        hp_max = 100,
        physical = true,
        collisionbox = {-0.3, -1.0, -0.3, 0.3, 0.8, 0.3},
        visual = "mesh",
        mesh = "character.b3d",
        textures = {"character.png"},
        makes_footstep_sound = true,
    },

    bot_name = "Friend",
    tool_durability = 100,
    has_tool = true,
    velocidade_andar = 4.5,
    fome = 20,
    timer_fome = 0,
    timer_vila = 0,

    on_activate = function(self, staticdata, dtime_s)
        if staticdata and staticdata ~= "" then
            local data = minetest.deserialize(staticdata)
            if data then
                self.bot_name = data.name or self.bot_name
                self.fome = data.fome or self.fome
                self.tool_durability = data.tool_durability or self.tool_durability
                self.object:set_hp(data.hp or 20)
                self.object:set_properties({nametag = self.bot_name, nametag_color = "#00FF00"})
            end
        end
        
        local inv_id = "bot_inv_" .. tostring(self.object:get_pos().x) .. "_" .. tostring(self.object:get_pos().z)
        self.inv_id = inv_id
        self.inv = minetest.create_detached_inventory(inv_id, {
            allow_move = function() return 1 end, allow_put = function() return 1 end, allow_take = function() return 1 end,
        })
        self.inv:set_size("main", 16)
        self.inv:add_item("main", "mcl_farming:bread 3")
    end,

    get_staticdata = function(self)
        local data = {name = self.bot_name, fome = self.fome, hp = self.object:get_hp(), tool_durability = self.tool_durability}
        return minetest.serialize(data)
    end,

    on_rightclick = function(self, clicker)
        if clicker and clicker:is_player() then
            local formspec = "size[8,9]" ..
                "label[0,0;Inventory from " .. self.bot_name .. "]" ..
                "list[detached:" .. self.inv_id .. ";main;0,0.5;4,4;]" ..
                "label[0,4.8;Your Inventory]" ..
                "list[current_player;main;0,5.3;8,4;]"
            minetest.show_formspec(clicker:get_player_name(), "ai_players:bot_menu", formspec)
        end
    end,

    on_step = function(self, dtime)
        local pos = self.object:get_pos()
        if not pos then return end

        local yaw = self.object:get_yaw() or 0
        local dir = {x = -math.sin(yaw), y = 0, z = math.cos(yaw)}

        -- =====================================================================
        -- 🌙 SISTEMA DE NOITE (DORMIR / FOGUEIRA)
        -- =====================================================================
        local hour = minetest.get_timeofday()
        if hour < 0.2 or hour > 0.8 then -- Night
            -- Searches for bed near player
            local bed = minetest.find_node_near(pos, 5, {"group:bed", "mcl_beds:bed"})
            if bed and math.random(1, 100) == 5 then
                self.object:set_velocity({x=0, y=0, z=0})
                if math.random(1, 50) == 1 then
                    minetest.chat_send_all("<" .. self.bot_name .. S("> Oh no, it's night, i'll sleep to reset the day."))
                end
                return -- Stops everything to simulate sleeping
            end
        end

        -- =====================================================================
        -- 🏘️ SISTEMA DE SAQUEAR VILAS AUTOMÁTICO
        -- =====================================================================
        self.timer_vila = self.timer_vila + dtime
        if self.timer_vila >= 15 then
            self.timer_vila = 0
            -- Procura blocos típicos de vilas (como plantações ou caminhos de terra)
            local na_vila = minetest.find_node_near(pos, 10, {"mcl_core:farmland", "mcl_farming:wheat"})
            if na_vila then
                minetest.chat_send_all("<" .. self.bot_name .. S("> Holy Cow, a village! i will loot it rn and get the farms, bro!"))
                -- Simula o saque adicionando itens aleatórios de vila no baú dele
                local loots_vila = {"mcl_core:apple", "mcl_farming:wheat", "mcl_core:emerald", "mcl_core:potato"}
                self.inv:add_item("main", loots_vila[math.random(#loots_vila)] .. " " .. math.random(1, 3))
            end
        end

        -- =====================================================================
        -- 🍖 FOME (MANTIDO)
        -- =====================================================================
        self.timer_fome = self.timer_fome + dtime
        if self.timer_fome >= 30 then
            self.timer_fome = 0
            self.fome = self.fome - 1
            if self.fome <= 0 then
                self.fome = 0
                self.object:set_hp(self.object:get_hp() - 1)
                minetest.chat_send_all("<" .. self.bot_name .. S("> Bro, im hungry, give me food or i will be defeated by hunger!"))
            end
        end

        -- =====================================================================
        -- ⚔️ COMBATE (MANTIDO)
        -- =====================================================================
        local alvo_combate = nil
        for _, enemy in pairs(minetest.get_objects_inside_radius(pos, 8)) do
            local lua_enemy = enemy:get_luaentity()
            if lua_enemy and enemy ~= self.object and not enemy:is_player() then
                if string.find(lua_enemy.name, "mob") or string.find(lua_enemy.name, "monster") or (self.fome < 5) then
                    alvo_combate = enemy
--Use o código com cuidado.
break
end
end
end
if alvo_combate then
local e_pos = alvo_combate:get_pos()
local dist_enemy = vector.distance(pos, e_pos)
local dx = e_pos.x - pos.x; local dz = e_pos.z - pos.z
self.object:set_yaw(math.atan2(-dx, dz))
if dist_enemy > 1.5 then
local dir_e = vector.direction(pos, e_pos)
local vel = self.object:get_velocity() or {x=0, y=0, z=0}
self.object:set_velocity({x=dir_e.x * 5.5, y=vel.y, z=dir_e.z * 5.5})
else
local vel = self.object:get_velocity() or {x=0, y=0, z=0}
self.object:set_velocity({x=0, y=vel.y, z=0})
if math.random(1, 10) == 1 then
alvo_combate:punch(self.object, 1.0, {full_punch_interval=1.0, damage_groups={fleshy=4}}, nil)
if self.fome < 5 then self.fome = self.fome + 4 end
end
end
return
end
-- =====================================================================
-- 🏃 SEGUIR E TELEPORTE FRONTAL (45 BLOCOS)
-- =====================================================================
local perigo_de_queda = false
local pos_frente = {x = pos.x + dir.x, y = pos.y, z = pos.z + dir.z}
local profundidade_buraco = 0
for i = 0, 5 do
local checa_no = minetest.get_node({x = pos_frente.x, y = pos_frente.y - i, z = pos_frente.z}).name
if checa_no == "air" or checa_no == "mapgen_air" or string.find(checa_no, "water") then profundidade_buraco = profundidade_buraco + 1 else break end
end
if profundidade_buraco >= 4 then
perigo_de_queda = true
local vel_atual = self.object:get_velocity() or {x=0, y=0, z=0}
self.object:set_velocity({x = -dir.x * 2.0, y = vel_atual.y, z = -dir.z * 2.0})
end
if not perigo_de_queda then
local jogador_proximo = nil
for _, obj in pairs(minetest.get_objects_inside_radius(pos, 45)) do
if obj:is_player() then jogador_proximo = obj; break end
end
if jogador_proximo then
local ppos = jogador_proximo:get_pos()
local dist = vector.distance(pos, ppos)
if dist >= 45.0 then
local p_yaw = jogador_proximo:get_look_horizontal() or 0
local p_dir = {x = -math.sin(p_yaw), y = 0, z = math.cos(p_yaw)}
self.object:set_pos({x = ppos.x + (p_dir.x * 5.0), y = ppos.y + 0.5, z = ppos.z + (p_dir.z * 5.0)})
return
end
local dx = ppos.x - pos.x; local dz = ppos.z - pos.z
self.object:set_yaw(math.atan2(-dx, dz))
if dist > 3.0 then
local dir_jog = vector.direction(pos, ppos)
local vel_atual = self.object:get_velocity() or {x=0, y=0, z=0}
local bloco_obstrucao = minetest.get_node({x = pos.x + dir_jog.x, y = pos.y, z = pos.z + dir_jog.z}).name
if bloco_obstrucao ~= "air" and vel_atual.y == 0 then vel_atual.y = 5.5 end
self.object:set_velocity({x = dir_jog.x * self.velocidade_andar, y = vel_atual.y, z = dir_jog.z * self.velocidade_andar})
else
local vel_atual = self.object:get_velocity() or {x=0, y=0, z=0}
self.object:set_velocity({x = 0, y = vel_atual.y, z = 0})
end
end
end
-- =====================================================================
-- ⛏️ MINERAÇÃO
-- =====================================================================
if self.has_tool then
local pos_olhos = {x = pos.x, y = pos.y + 0.5, z = pos.z}
local pos_alvo = {x = pos_olhos.x + (dir.x * 2.5), y = pos_olhos.y - 0.8, z = pos_olhos.z + (dir.z * 2.5)}
local ray = minetest.raycast(pos_olhos, pos_alvo, true, false)
local apontado = ray:next()
if apontado and apontado.type == "node" then
local bloco_pos = apontado.under
local node_name = minetest.get_node(bloco_pos).name
local def = minetest.registered_nodes[node_name]
local eh_queravel = def and (def.groups.cracky or def.groups.crumbly or def.groups.choppy)
if eh_queravel and not prohibited_blocks[node_name] then
if bloco_pos.y < (pos.y - 0.2) and node_name ~= "air" then
if math.random(1, 100) < 12 then
local drops = minetest.get_node_drops(node_name, "")
minetest.dig_node(bloco_pos)
for _, item in ipairs(drops) do self.inv:add_item("main", item) end
self.tool_durability = self.tool_durability - 4
if self.tool_durability <= 0 then
self.has_tool = false
minetest.after(8, function() self.has_tool = true; self.tool_durability = 100 end)
end
end
end
end
end
end
end,
})
-- =============================================================================
-- 💬 INTERAÇÕES VIA CHAT (COMIDA, FARM AFK, FERRO)
-- =============================================================================
minetest.register_on_chat_message(function(name, message)
local msg = string.lower(message)
local player = minetest.get_player_by_name(name)
if not player then return end
local p_pos = player:get_pos()
-- 1. Comando: Comida
if string.find(msg, "comida") or string.find(msg, "food") or string.find(msg, "nourriture") then
for _, obj in pairs(minetest.get_objects_inside_radius(p_pos, 15)) do
local luaentity = obj:get_luaentity()
if luaentity and luaentity.name == "ai_players:ai_friend" then
if luaentity.inv:contains_item("main", "mcl_farming:bread") then
luaentity.inv:remove_item("main", "mcl_farming:bread 1")
player:get_inventory():add_item("main", "mcl_farming:bread 1")
minetest.chat_send_all( S(" Take it, bro, Sharing is always great!"))
else
minetest.chat_send_all( S(" i don't have food!"))
end
break
end
end
end
-- 2. Comando: Farm AFK
if string.find(msg, "farm afk") or string.find(msg, "granja afk") or string.find(msg, "ferme afk") then
for _, obj in pairs(minetest.get_objects_inside_radius(p_pos, 15)) do
local luaentity = obj:get_luaentity()
if luaentity and luaentity.name == "ai_players:ai_friend" then
-- O bot coloca o bloco especial de farm 2 blocos à frente dele
local b_pos = obj:get_pos()
local spawn_farm = {x=math.floor(b_pos.x)+2, y=math.floor(b_pos.y), z=math.floor(b_pos.z)}
minetest.set_node(spawn_farm, {name="ai_players:afk_monsters_farm"})
minetest.chat_send_all( S(" alr bro, i just placed the afk farm!"))
break
end
end
end
-- 3. Comando: Ferro
if string.find(msg, "ferro") or string.find(msg, "iron") or string.find(msg, "hierro") or string.find(msg, "fer") then
for _, obj in pairs(minetest.get_objects_inside_radius(p_pos, 15)) do
local luaentity = obj:get_luaentity()
if luaentity and luaentity.name == "ai_players:ai_friend" then
local b_pos = obj:get_pos()
local spawn_farm = {x=math.floor(b_pos.x)+2, y=math.floor(b_pos.y), z=math.floor(b_pos.z)}
minetest.set_node(spawn_farm, {name="ai_players:iron_block_generator"})
minetest.chat_send_all( S(" Let the iron Farm Farm Iron, ik that is strange but i hope you understood!"))
break
end
end
end
end)
