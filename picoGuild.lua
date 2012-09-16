local _G=getfenv(0)
local format = _G.string.format
local find = _G.string.find
local floor = _G.math.floor
local pairs = _G.pairs
local wipe = _G.table.wipe
local insert = _G.table.insert
local sort = _G.table.sort
local IsInGuild = _G.IsInGuild
local GetGuildFactionInfo = _G.GetGuildFactionInfo
local GetGuildInfo = _G.GetGuildInfo
local GetGuildLevel = _G.GetGuildLevel
local GetGuildRosterInfo = _G.GetGuildRosterInfo
local GetGuildRosterMOTD = _G.GetGuildRosterMOTD
local GetNumGuildMembers = _G.GetNumGuildMembers
local GetRealZoneText = _G.GetRealZoneText
local GetText = _G.GetText
local GuildRoster = _G.GuildRoster
local IsLoggedIn = _G.IsLoggedIn
local QueryGuildXP = _G.QueryGuildXP
local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
local REMOTE_CHAT = _G.REMOTE_CHAT
local ToggleGuildFrame = _G.ToggleGuildFrame
local UnitGetGuildXP = _G.UnitGetGuildXP
local UnitInParty = _G.UnitInParty
local UnitInRaid = _G.UnitInRaid
local UnitLevel = _G.UnitLevel
local UnitName = _G.UnitName
local UnitSex = _G.UnitSex

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

local cache = {}
local online, total, remote = 0, 0, 0

------------------------------
--      Are you local?      --
------------------------------

local mejoin = UnitName("player").." has joined the guild."
local friends, colors = {}, {}
for class,color in pairs(RAID_CLASS_COLORS) do colors[class] = format("%02x%02x%02x", color.r*255, color.g*255, color.b*255) end

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
_G.GuildRoster = function(...)
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
	self:UnregisterEvent("PLAYER_LOGIN")
	self.PLAYER_LOGIN = nil
	f:GUILD_XP_UPDATE()
	f:GUILD_ROSTER_UPDATE()
end

function f:UpdateText()
	if IsInGuild() then
		local currentXP, remainingXP = UnitGetGuildXP("player")
		local level = GetGuildLevel() + currentXP/(currentXP + remainingXP)
		dataobj.text = format("Lv%.1f - %d/%d (%d)", floor(level*10)/10, remote and (online - remote) or online, total, remote)
	else dataobj.text = L["No Guild"] end
end

------------------------------
--      Event Handlers      --
------------------------------
--
function f:PLAYER_ENTERING_WORLD()
	if IsInGuild() then
		QueryGuildXP()
		GuildRoster()
	end
end

function f:GUILD_XP_UPDATE()
	f:UpdateText()
end

function f:GUILD_ROSTER_UPDATE()
	if IsInGuild() then
		wipe(cache)
		total, online = GetNumGuildMembers()
		remote = 0
		for i = 1, total do
			local name, rank, rnum, level, class, area, pnote, onote, connected, status, engclass, points, pointrank, mobile = GetGuildRosterInfo(i)
			if mobile then area = REMOTE_CHAT end
			insert(cache, {name=name,rank=rank,rnum=rnum,level=level,class=class,area=area,pnote=pnote,onote=onote,connected=connected,status=status,engclass=engclass,points=points,pointrank=pointrank,mobile=mobile})
			if mobile then remote = remote + 1 end
		end
		sort(cache, function(a,b) return a.rnum < b.rnum end)
		f:UpdateText()
	end
end


function f:CHAT_MSG_SYSTEM(event, msg)
	if find(msg, L["has come online"]) or find(msg, L["has gone offline"]) or msg == mejoin then dirty = true end
end


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

		tip:AddLine(format("Rep:|cffffffff %s %d%% (%d/%d)", factionStandingtext, barValue / barMax * 100, barValue, barMax))
		tip:AddLine(" ")

		local mylevel, myarea = UnitLevel("player"), GetRealZoneText()

		for k,v in pairs(cache) do
			if v.connected and not v.mobile then
				local cc = RAID_CLASS_COLORS[v.engclass]
				local lr, lg, lb, ar, ag, ab = 0, 1, 0, 1, 1, 1
				if v.level < (mylevel - 5) then lr, lg, lb = .6, .6, .6
				elseif v.level > (mylevel + 5) then lr, lg, lb = 1, 0, 0 end
				local grouped = false
				if UnitInParty(name) or UnitInRaid(name) then grouped = true end
				if v.area == myarea then ar, ag, ab = 0, 1, 0 end
				local levelcolor = (v.level >= (mylevel - 5) and v.level <= (mylevel + 5)) and "|cff00ff00" or ""
				tip:AddMultiLine(grouped and "+" or " ", (v.level < 10 and "0" or "")..v.level, v.name, v.area or "???", v.pnote, v.onote, v.rank, 0, grouped and 1 or 0, 0, lr,lg,lb, cc.r,cc.g,cc.b, ar,ag,ab, nil,nil,nil, 1,1,0, .7,.7,1)
			end
		end
		if remote > 0 then 
			tip:AddLine(" ")
			for k,v in pairs(cache) do
				if v.connected and v.mobile then
					local cc = RAID_CLASS_COLORS[v.engclass]
					local lr, lg, lb, ar, ag, ab = 0, 1, 0, 1, 1, 1
					if v.level < (mylevel - 5) then lr, lg, lb = .6, .6, .6
					elseif v.level > (mylevel + 5) then lr, lg, lb = 1, 0, 0 end
					if v.area == myarea then ar, ag, ab = 0, 1, 0 end
					local levelcolor = (v.level >= (mylevel - 5) and v.level <= (mylevel + 5)) and "|cff00ff00" or ""
					tip:AddMultiLine(" ", (v.level < 10 and "0" or "")..v.level, v.name, v.area or "???", v.pnote, v.onote, v.rank, 0, 0, 0, lr,lg,lb, cc.r,cc.g,cc.b, ar,ag,ab, nil,nil,nil, 1,1,0, .7,.7,1)
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
