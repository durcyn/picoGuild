
----------------------------
--      Localization      --
----------------------------

local L = {
	offline = "(.+) has gone offline.";
	online = "|Hplayer:%s|h[%s]|h has come online.";	["has come online"] = "has come online",
	["has gone offline"] = "has gone offline",

	["No Guild"] = "No Guild",
	["Not in a guild"] = "Not in a guild",
}


------------------------------
--      Are you local?      --
------------------------------

local mejoin = UnitName("player").." has joined the guild."
local friends, colors = {}, {}
for class,color in pairs(RAID_CLASS_COLORS) do colors[class] = string.format("%02x%02x%02x", color.r*255, color.g*255, color.b*255) end

local total, online, remotes = 0,0,0
local level

-------------------------------------------
--      Namespace and all that shit      --
-------------------------------------------

local dataobj = LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject("picoGuild", {type = "data source", icon = "Interface\\Addons\\picoGuild\\icon", text = L["No Guild"]})
local f = CreateFrame("Frame")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then return self[event](self, event, ...) end end)


----------------------------------
--      Server query timer      --
----------------------------------

local MINDELAY, DELAY = 15, 300
local elapsed, dirty = 0, false
f:Hide()
f:SetScript("OnUpdate", function(self, elap)
	elapsed = elapsed + elap
	if (dirty and elapsed >= MINDELAY) or elapsed >= DELAY then
		if IsInGuild() then GuildRoster() else elapsed, dirty = 0, false end
	end
end)


local orig = GuildRoster
GuildRoster = function(...)
	elapsed, dirty = 0, false
	return orig(...)
end


---------------------------
--      Init/Enable      --
---------------------------

function f:PLAYER_LOGIN()
--	LibStub("tekKonfig-AboutPanel").new(nil, "picoGuild")

	self:Show()
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
	self:RegisterEvent("GUILD_XP_UPDATE")
	self:RegisterEvent("CHAT_MSG_SYSTEM")
	self:RegisterEvent("PLAYER_ENTERING_WORLD")
	self:RegisterEvent("PLAYER_LOGOUT")

	SortGuildRoster("rank")
	if IsInGuild() then
		QueryGuildXP()
		GuildRoster()
	end

	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
end


function f:UpdateText()
	if IsInGuild() then
	total, online = GetNumGuildMembers()
		local currentXP, remainingXP = UnitGetGuildXP("player")
		level = GetGuildLevel() + currentXP/(currentXP + remainingXP)
		dataobj.text = string.format("Lv%.1f%s - %d/%d (%d)", math.floor(level*10)/10, online, total, remotes)
	else dataobj.text = L["No Guild"] end
end

------------------------------
--      Event Handlers      --
------------------------------
--
function f:PLAYER_LOGOUT()
	SortGuildRoster("rank")
end

function f:PLAYER_ENTERING_WORLD()
	if IsInGuild() then
		QueryGuildXP()
		GuildRoster()
	end
end

function f:CHAT_MSG_SYSTEM(event, msg)
	if string.find(msg, L["has come online"]) or string.find(msg, L["has gone offline"]) or msg == mejoin then dirty = true end
end


f.GUILD_ROSTER_UPDATE = f.UpdateText
f.GUILD_XP_UPDATE = f.UpdateText


------------------------
--      Tooltip!      --
------------------------

local tip = LibStub("tektip-1.0").new(7, "LEFT", "LEFT", "LEFT", "CENTER", "RIGHT", "RIGHT", "RIGHT")
local lastanchor
function dataobj.OnLeave() tip:Hide() end
function dataobj.OnEnter(self)
	tip:AnchorTo(self)
	lastanchor = self

	tip:AddLine("picoGuild")

	if IsInGuild() then
		local currentXP, remainingXP = UnitGetGuildXP("player")
		local nextLevelXP = currentXP + remainingXP

		local gender = UnitSex("player")
		local name, description, standingID, barMin, barMax, barValue = GetGuildFactionInfo()
		local factionStandingtext = GetText("FACTION_STANDING_LABEL"..standingID, gender)
		barMax, barValue = barMax - barMin, barValue - barMin

		tip:AddLine("<"..GetGuildInfo("player")..">", 1, 1, 1)
		tip:AddLine(GetGuildRosterMOTD(), 0, 1, 0, true)
		tip:AddLine(" ")

		tip:AddLine(string.format("Rep:|cffffffff %s %d%% (%d/%d)", factionStandingtext, barValue / barMax * 100, barValue, barMax))
		tip:AddLine(" ")

		local mylevel, myarea = UnitLevel("player"), GetRealZoneText()
		remotes = 0
		for i=1,GetNumGuildMembers(true) do
			local name, rank, rankIndex, level, class, area, note, officernote, connected, status, engclass, points, pointrank, mobile = GetGuildRosterInfo(i)
			if connected and mobile then	
				remotes = remotes + 1
			elseif connected and not mobile then
				local cc = RAID_CLASS_COLORS[engclass]
				local lr, lg, lb, ar, ag, ab = 0, 1, 0, 1, 1, 1
				if level < (mylevel - 5) then lr, lg, lb = .6, .6, .6
				elseif level > (mylevel + 5) then lr, lg, lb = 1, 0, 0 end
				local grouped = false
				if UnitInParty(name) or UnitInRaid(name) then grouped = true end
				if area == myarea then ar, ag, ab = 0, 1, 0 end
				local levelcolor = (level >= (mylevel - 5) and level <= (mylevel + 5)) and "|cff00ff00" or ""
				tip:AddMultiLine(grouped and "+" or " ", (level < 10 and "0" or "")..level, name, area or "???", note, officernote, rank, 0, grouped and 1 or 0, 0, lr,lg,lb, cc.r,cc.g,cc.b, ar,ag,ab, nil,nil,nil, 1,1,0, .7,.7,1)
			end
		end
		if remotes > 0 then 
			tip:AddLine(" ")
			for i=1,GetNumGuildMembers(true) do
				local name, rank, rankIndex, level, class, area, note, officernote, connected, status, engclass, points, pointrank, mobile = GetGuildRosterInfo(i)
				if connected and mobile then
					local cc = RAID_CLASS_COLORS[engclass]
					local lr, lg, lb, ar, ag, ab = 0, 1, 0, 1, 1, 1
					if level < (mylevel - 5) then lr, lg, lb = .6, .6, .6
					elseif level > (mylevel + 5) then lr, lg, lb = 1, 0, 0 end
					if mobile then area = REMOTE_CHAT end
					if area == myarea then ar, ag, ab = 0, 1, 0 end
					local levelcolor = (level >= (mylevel - 5) and level <= (mylevel + 5)) and "|cff00ff00" or ""
					tip:AddMultiLine(" ", (level < 10 and "0" or "")..level, name, area or "???", note, officernote, rank, 0, 0, 0, lr,lg,lb, cc.r,cc.g,cc.b, ar,ag,ab, nil,nil,nil, 1,1,0, .7,.7,1)
				end
			end
		end
		f:UpdateText()
	else
		tip:AddLine(L["Not in a guild"])
	end

	tip:Show()
end


-----------------------------------------
--      Click to open guild panel      --
-----------------------------------------

function dataobj.OnClick()
	ToggleGuildFrame()
	if GuildFrame:IsShown() then tip:Hide() else dataobj.OnEnter(lastanchor) end
end


-----------------------------------
--      Make rocket go now!      --
-----------------------------------

if IsLoggedIn() then f:PLAYER_LOGIN() else f:RegisterEvent("PLAYER_LOGIN") end
