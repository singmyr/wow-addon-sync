--[[
    @todo: Get secondary professions.
    @todo: Get profession cooldowns.
     - GetSpellCooldown(29688) - Transmute: Primal Might
      - https://wowwiki-archive.fandom.com/wiki/API_GetSpellCooldown
      - Figure out how to calculate how much time is left.
     - IsSpellKnown(29688) - Transmute: Primal Might
      - https://wowwiki-archive.fandom.com/wiki/API_IsSpellKnown
    @todo: Get bank contents.
    @todo: Get gbank contents. (Only for <Singmyr>)
    @todo: Get mail contents.
 ]]

local f = CreateFrame("frame")
local events = {}

Sync = Sync or {}

function events:BAG_UPDATE(...)
    local bagID = ...
    if bagID < 0 then
        return
    end
    SyncInventory()
end

function events:PLAYER_LOGOUT(...)
    Sync["timestamp"] = GetServerTime()
    SyncJSON = recursiveJSON(Sync)
end

function recursiveJSON(data)
    if type(data) ~= "table" then
        if type(data) == "string" then
            return "\""..data.."\""
        end
        return data
    end
    
    local result = {}

    for key, value in pairs(data) do
        print(key, value)
        table.insert(result, string.format("\"%s\":%s", key, recursiveJSON(value)))
    end

    return "{" .. table.concat(result, ",") .. "}"
end

-- Not used yet.
--[[ function events:BANKFRAME_CLOSED(...)
    -- Dump the player's bank
    print("BANKFRAME_CLOSED")
end

function events:BANKFRAME_OPENED(...)
    -- Dump the player's bank
    print("BANKFRAME_OPENED")
end ]]

function SyncCharacter()
    if Sync["character"] == nil then
        Sync["character"] = {}
    end
    Sync["character"]["name"] = UnitName("player")
    Sync["character"]["level"] = UnitLevel("player")
    _, Sync["character"]["classID"] = UnitClassBase("player")
    Sync["character"]["className"], _ = UnitClassBase("player")
    Sync["character"]["race"] = UnitRace("player")
    Sync["character"]["gender"] = UnitSex("player")
    Sync["character"]["guild"], _, _, _ = GetGuildInfo("player")

    -- XP
    Sync["character"]["xp"] = UnitXP("player")
    Sync["character"]["xpMax"] = UnitXPMax("player")
    Sync["character"]["restedXp"] = 0
    local restedXP = GetXPExhaustion()
    if restedXP ~= nil then
        Sync["character"]["restedXp"] = restedXP / 2
    end
end

function SyncProfessions()
    if Sync["professions"] == nil then
        Sync["professions"] = {}
    end
    for skillIndex = 1, GetNumSkillLines() do
        local skillName, isHeader, _, skillRank, _, _,
            skillMaxRank, isAbandonable, _, _, _, _,
            skillDescription = GetSkillLineInfo(skillIndex)
        if not isHeader and isAbandonable then
            Sync["professions"][skillName] = {}
            Sync["professions"][skillName]["rank"] = skillRank
            Sync["professions"][skillName]["maxRank"] = skillMaxRank
            Sync["professions"][skillName]["cooldowns"] = {}
        end
    end
end

function SyncMoney()
    -- Sync["gold"] = GetCoinText(GetMoney(), ", ")
    Sync["gold"] = GetMoney()
end

function SyncInventory()
    if Sync["inventory"] == nil then
        Sync["inventory"] = {}
    end
    local items = {}
    for containerID=BACKPACK_CONTAINER,NUM_BAG_SLOTS,1 do
        Sync["inventory"][""..containerID] = {}
        numSlots = GetContainerNumSlots(containerID)
        Sync["inventory"][""..containerID]["size"] = numSlots
        if numSlots > 0 then
            Sync["inventory"][""..containerID]["items"] = {}
            if containerID == 0 then
            end
            for slot=1,numSlots,1 do
                itemID = GetContainerItemID(containerID, slot)
                if itemID ~= nil then
                    _, count, _, _, _, _, _ = GetContainerItemInfo(containerID, slot)
                    if Sync["inventory"][""..containerID]["items"][itemID] ~= nil then
                        Sync["inventory"][""..containerID]["items"][itemID] = Sync["inventory"][""..containerID]["items"][itemID] + count
                    else
                        Sync["inventory"][""..containerID]["items"][itemID] = count
                    end
                    if items[itemID] ~= nil then
                        items[itemID] = items[itemID] + count
                    else
                        items[itemID] = count
                    end
                end
            end
        end
    end
end

function events:PLAYER_XP_UPDATE(...)
    SyncCharacter()
end

function events:UPDATE_EXHAUSTION(...)
    SyncCharacter()
end

function events:PLAYER_LEVEL_UP(...)
    SyncCharacter()
end

function events:PLAYER_MONEY(...)
    SyncMoney()
end

function events:ADDON_LOADED(...)
    local name = ...
    if name == "Sync" then
        Sync = Sync or {}    
    end
end

function events:PLAYER_ENTERING_WORLD(...)
    SyncMoney()

    SyncProfessions()

    SyncCharacter()

    SyncInventory()
end

f:SetScript("OnEvent", function(self, event, ...)
    events[event](self, ...)
end)

for k, v in pairs(events) do
    f:RegisterEvent(k)
end

-- Not used.
-- SLASH_SYNC1 = "/sync"
-- SlashCmdList["SYNC"] = nil