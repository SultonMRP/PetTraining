-- Pet Training: hunter-learned pet abilities (tame and keep using until the game grants them).
-- Tooltip line. Scan button on Beast Training. Ghost scan: Alt-click pet bar, or click the learn popup.

local ADDON = ...

local db
local lastSpellId, lastPetSlot
local learnPopup
local RefreshPetTooltip, HookPetBarClicks, IsUpgradeable

local defaults = {
	learned = {},
	sound = true,
}

local function DebugPrint(msg)
	local D = PetTrainingDebug
	if D and D.Print then
		D.Print(msg)
	end
end

local function DebugOn()
	local D = PetTrainingDebug
	return D and D.On and D.On()
end

local function DumpBeastTraining(reason)
	local D = PetTrainingDebug
	if D and D.DumpTrainer then
		D.DumpTrainer(reason)
	end
end

local function GhostDump(tag)
	local D = PetTrainingDebug
	if D and D.DumpGhost then
		D.DumpGhost(tag)
	end
end

local function DumpLearnDetect(...)
	local D = PetTrainingDebug
	if D and D.DumpLearn then
		D.DumpLearn(...)
	end
end

local function DumpLearnGlobals()
	local D = PetTrainingDebug
	if D and D.DumpLearnGlobals then
		D.DumpLearnGlobals()
	end
end

-- Abilities you farm from beasts (not pet-trainer gold ranks like Growl / stamina).
-- Rank chains from Forever SpellRankData (Bite Rank 3 = 17256).
local WILD = {
	[1742] = true, [1753] = true, [1754] = true, [1755] = true, [1756] = true, [16697] = true, -- Cower
	[7371] = true, [26177] = true, [26178] = true, [26179] = true, [26201] = true, [27685] = true, -- Charge
	[16827] = true, [16828] = true, [16829] = true, [16830] = true, [16831] = true, [16832] = true, [3010] = true, [3009] = true, -- Claw
	[17253] = true, [17255] = true, [17256] = true, [17257] = true, [17258] = true, [17259] = true, [17260] = true, [17261] = true, -- Bite
	[23099] = true, [23109] = true, [23110] = true, -- Dash
	[23145] = true, [23147] = true, [23148] = true, -- Dive
	[24423] = true, [24577] = true, [24578] = true, [24579] = true, -- Demoralizing Screech
	[24450] = true, [24452] = true, [24453] = true, -- Prowl
	[24604] = true, [24605] = true, [24603] = true, [24597] = true, -- Furious Howl
	[24640] = true, [24583] = true, [24586] = true, [24587] = true, -- Scorpid Poison
	[24844] = true, [25008] = true, [25009] = true, [25010] = true, [25011] = true, [25012] = true, -- Lightning Breath
	[26090] = true, [26187] = true, [26188] = true, [1264455] = true, -- Thunderstomp
	[444678] = true, [444681] = true, -- Lava Breath
	[26064] = true, -- Shell Shield
	[1264478] = true, [1264479] = true, [1264480] = true, [1264481] = true, [1264482] = true, -- Sonic Blast
	[1264494] = true, [1264497] = true, [1264498] = true, [1264501] = true, [1264502] = true, -- Swipe
	[1264735] = true, [1264736] = true, [1264739] = true, [1264741] = true, [1264742] = true, -- Pinch
	[1264758] = true, [1264927] = true, [1264929] = true, [1264930] = true, [1264933] = true, -- Dismember
	[1265038] = true, [1265039] = true, [1265040] = true, [1265041] = true, [1265042] = true, -- Tendon Rip
	[1265054] = true, [1265055] = true, [1265056] = true, [1265057] = true, [1265058] = true, -- Mine!
	[1265065] = true, [1265066] = true, [1265067] = true, [1265068] = true, [1265069] = true, -- Savage Rend
	[1265843] = true, [1265878] = true, [1265880] = true, [1265881] = true, [1265883] = true, -- Web
	[1265899] = true, [1265901] = true, [1265902] = true, [1265903] = true, [1265904] = true, -- Dust Cloud
}

-- Base names from ify wow_forever_pet_spells.txt (rank stripped). Growl is trainer gold, not here.
local WILD_NAMES = {
	["bite"] = true,
	["charge"] = true,
	["claw"] = true,
	["cower"] = true,
	["dash"] = true,
	["demoralizing screech"] = true,
	["dismember"] = true,
	["dive"] = true,
	["dust cloud"] = true,
	["furious howl"] = true,
	["lightning breath"] = true,
	["mine!"] = true,
	["pinch"] = true,
	["prowl"] = true,
	["savage rend"] = true,
	["scorpid poison"] = true,
	["shell shield"] = true,
	["sonic blast"] = true,
	["swipe"] = true,
	["tendon rip"] = true,
	["thunderstomp"] = true,
	["trickster's dance"] = true,
	["web"] = true,
}

-- Lower ranks are implied once a higher rank is confirmed from chat or Beast Training.
local CHAINS = {
	{1742, 1753, 1754, 1755, 1756, 16697}, -- Cower
	{7371, 26177, 26178, 26179, 26201, 27685}, -- Charge
	{16827, 16828, 16829, 16830, 16831, 16832, 3010, 3009}, -- Claw
	{17253, 17255, 17256, 17257, 17258, 17259, 17260, 17261}, -- Bite
	{23099, 23109, 23110}, -- Dash
	{23145, 23147, 23148}, -- Dive
	{24423, 24577, 24578, 24579}, -- Demoralizing Screech
	{24450, 24452, 24453}, -- Prowl
	{24604, 24605, 24603, 24597}, -- Furious Howl
	{24640, 24583, 24586, 24587}, -- Scorpid Poison
	{24844, 25008, 25009, 25010, 25011, 25012}, -- Lightning Breath
	{26064}, -- Shell Shield
	{26090, 26187, 26188, 1264455}, -- Thunderstomp
	{444678, 444681}, -- Lava Breath
	{1264478, 1264479, 1264480, 1264481, 1264482}, -- Sonic Blast
	{1264494, 1264497, 1264498, 1264501, 1264502}, -- Swipe
	{1264735, 1264736, 1264739, 1264741, 1264742}, -- Pinch
	{1264758, 1264927, 1264929, 1264930, 1264933}, -- Dismember
	{1265038, 1265039, 1265040, 1265041, 1265042}, -- Tendon Rip
	{1265054, 1265055, 1265056, 1265057, 1265058}, -- Mine!
	{1265065, 1265066, 1265067, 1265068, 1265069}, -- Savage Rend
	{1265843, 1265878, 1265880, 1265881, 1265883}, -- Web
	{1265899, 1265901, 1265902, 1265903, 1265904}, -- Dust Cloud
}

local CHAIN_INDEX = {}
for _, chain in ipairs(CHAINS) do
	for i, id in ipairs(chain) do
		CHAIN_INDEX[id] = { chain = chain, index = i }
	end
end

local BEAST_TRAINING = 5149
local TRAINER_STATUS = {
	available = "available",
	unavailable = "unavailable",
	used = "used",
	header = "header",
}

local function MapTrainerEnums(enumTable)
	if type(enumTable) ~= "table" then
		return
	end
	for name, id in pairs(enumTable) do
		if type(name) == "string" and type(id) == "number" then
			TRAINER_STATUS[id] = strlower(name)
		end
	end
end
if Enum then
	MapTrainerEnums(Enum.TrainerServiceState)
	MapTrainerEnums(Enum.TrainerServiceType)
	MapTrainerEnums(Enum.TrainerServiceStatus)
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cffaad372Pet Training|r: " .. msg)
end

local function SystemMsg(msg)
	DEFAULT_CHAT_FRAME:AddMessage(msg, 1, 1, 0)
end

local function Readable(v)
	if v == nil then
		return nil
	end
	if issecretvalue and issecretvalue(v) then
		return nil
	end
	return v
end

local FILTER_KINDS = { "available", "unavailable", "used" }
local scanButton, scanBusy, scanSaved, scanTimer, scanAdded, scanRemoved, scanReadyAt, scanFullFilters
local ghostScan, ghostRestore, ghostTimer, ghostKeep, ghostDriver, ghostHooks, settingGhost
local ClearGhost
local pendingLearn, pendingPopupScan, pendingBtConfirm

local function IsHunter()
	local _, class = UnitClass("player")
	return class == "HUNTER"
end

local function SpellName(spellID)
	if not spellID then
		return nil
	end
	if C_Spell and C_Spell.GetSpellName then
		local ok, name = pcall(C_Spell.GetSpellName, spellID)
		if ok and Readable(name) then
			return name
		end
	end
	if GetSpellInfo then
		local ok, name = pcall(GetSpellInfo, spellID)
		if ok and Readable(name) then
			return name
		end
	end
end

local function SpellSubtext(spellID)
	if not spellID then
		return nil
	end
	if C_Spell and C_Spell.GetSpellSubtext then
		local ok, sub = pcall(C_Spell.GetSpellSubtext, spellID)
		if ok and Readable(sub) and sub ~= "" then
			return sub
		end
	end
	if GetSpellSubtext then
		local ok, sub = pcall(GetSpellSubtext, spellID)
		if ok and Readable(sub) and sub ~= "" then
			return sub
		end
	end
end

local function SpellLabel(spellID, fallback)
	local name = SpellName(spellID) or fallback
	if not name then
		return "pet ability"
	end
	local sub = SpellSubtext(spellID)
	if sub then
		return name .. " (" .. sub .. ")"
	end
	return name
end

local function IsWild(spellID)
	return spellID and WILD[spellID] == true
end

local function IsLearned(spellID)
	return spellID and db and db.learned[spellID] == true
end

local function MarkLearned(spellID)
	if not spellID or not db then
		return false
	end
	local changed = false
	local info = CHAIN_INDEX[spellID]
	if info then
		for i = 1, info.index do
			local id = info.chain[i]
			if not db.learned[id] then
				db.learned[id] = true
				changed = true
			end
		end
		return changed
	end
	if db.learned[spellID] then
		return false
	end
	db.learned[spellID] = true
	return true
end

local function TrainerServiceStatus(index)
	local info = { GetTrainerServiceInfo(index) }
	for i = 1, #info do
		local v = info[i]
		if type(v) == "string" then
			v = strlower(v)
		end
		if TRAINER_STATUS[v] then
			return TRAINER_STATUS[v]
		end
		if type(v) == "number" and type(TRAINER_STATUS[v]) == "string" then
			return TRAINER_STATUS[v]
		end
	end
end

local function TrainerSpellID(index)
	if C_TooltipInfo and C_TooltipInfo.GetTrainerService then
		local ok, data = pcall(C_TooltipInfo.GetTrainerService, index)
		local id = ok and data and Readable(data.id)
		if type(id) == "number" then
			return id
		end
	end
end

local function GetTrainerTypeValue()
	if C_Trainer and C_Trainer.GetTrainerType then
		local ok, t = pcall(C_Trainer.GetTrainerType)
		if ok then
			return Readable(t)
		end
	end
end

local function IsPetTrainer()
	local trainerType = GetTrainerTypeValue()
	local petEnum = Enum and Enum.TrainerType and Enum.TrainerType.Pet
	-- Forever Beast Training reports type 3; Pet enum may be missing or a different number.
	if trainerType == petEnum or trainerType == 3 then
		return true
	end
	local points = ClassTrainerFrame and ClassTrainerFrame.trainingPoints
	return points and points.IsShown and points:IsShown()
end

-- Forever Beast Training lists ranks the hunter can teach, not the pet's inherent bar.
-- Bite 3 on a spider does not appear here until you actually learn it. Any wild rank
-- that shows up (available / unavailable / used) is hunter-known.
local function TrainerServiceCount()
	if not GetNumTrainerServices then
		return 0
	end
	local ok, n = pcall(GetNumTrainerServices)
	return (ok and n) or 0
end

-- Add ranks found in the current BT list. Does not drop leftovers.
local function SyncBeastTraining()
	if not IsHunter() or not db or not GetNumTrainerServices then
		return 0
	end
	if not IsPetTrainer() then
		return 0
	end
	local added = 0
	for index = 1, TrainerServiceCount() do
		local status = TrainerServiceStatus(index)
		if status and status ~= "header" then
			local spellID = TrainerSpellID(index)
			if IsWild(spellID) and MarkLearned(spellID) then
				added = added + 1
			end
		end
	end
	return added
end

-- Full list (all filters on): each chain matches BT. Higher leftover ranks are dropped.
local function ApplyScanToLearned()
	if not IsHunter() or not db or not GetNumTrainerServices or not IsPetTrainer() then
		return 0, 0
	end
	local seen = {}
	for index = 1, TrainerServiceCount() do
		local status = TrainerServiceStatus(index)
		if status and status ~= "header" then
			local spellID = TrainerSpellID(index)
			if IsWild(spellID) then
				seen[spellID] = true
			end
		end
	end
	local touched = {}
	local added = 0
	for spellID in pairs(seen) do
		local info = CHAIN_INDEX[spellID]
		if info then
			touched[info.chain] = true
		elseif MarkLearned(spellID) then
			added = added + 1
		end
	end
	local removed = 0
	for c = 1, #CHAINS do
		local chain = CHAINS[c]
		if touched[chain] then
			local maxSeen = 0
			for i = 1, #chain do
				if seen[chain[i]] and i > maxSeen then
					maxSeen = i
				end
			end
			for i = 1, #chain do
				local id = chain[i]
				if i <= maxSeen then
					if not db.learned[id] then
						db.learned[id] = true
						added = added + 1
					end
				elseif db.learned[id] then
					db.learned[id] = nil
					removed = removed + 1
					DebugPrint("scan dropped leftover " .. SpellLabel(id) .. " (" .. id .. ")")
				end
			end
		end
	end
	return added, removed
end

local function CanToggleFilters()
	return (GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter) and true or false
end

-- Forever returns 1/0. Lua 5.1 treats 0 as true, so never use `if value` on these.
local function FilterIsOn(value)
	return value == true or value == 1
end

local function ReadFilters()
	local saved = {}
	if not GetTrainerServiceTypeFilter then
		return saved
	end
	for _, kind in ipairs(FILTER_KINDS) do
		local ok, value = pcall(GetTrainerServiceTypeFilter, kind)
		saved[kind] = ok and FilterIsOn(value) or false
	end
	return saved
end

local settingFilters

local function SetFilter(kind, on)
	if not SetTrainerServiceTypeFilter then
		return
	end
	settingFilters = true
	pcall(SetTrainerServiceTypeFilter, kind, on and 1 or 0)
	settingFilters = false
end

local function ApplyFilters(saved)
	if not saved then
		return
	end
	for _, kind in ipairs(FILTER_KINDS) do
		SetFilter(kind, FilterIsOn(saved[kind]))
	end
end

local function EnableAllFilters()
	for _, kind in ipairs(FILTER_KINDS) do
		SetFilter(kind, true)
	end
end

local function FiltersAllOn()
	local saved = ReadFilters()
	for _, kind in ipairs(FILTER_KINDS) do
		if not FilterIsOn(saved[kind]) then
			return false
		end
	end
	return true
end

local function GhostActive()
	return ghostScan or ghostKeep
end

local ghostSoundsHooked
local origPlaySound, origPlaySoundFile, origPlaySoundKitID

local function HookGhostSounds()
	if ghostSoundsHooked then
		return
	end
	ghostSoundsHooked = true
	origPlaySound = PlaySound
	origPlaySoundFile = PlaySoundFile
	origPlaySoundKitID = PlaySoundKitID
	if origPlaySound then
		function PlaySound(...)
			if GhostActive() then
				return
			end
			return origPlaySound(...)
		end
	end
	if origPlaySoundFile then
		function PlaySoundFile(...)
			if GhostActive() then
				return
			end
			return origPlaySoundFile(...)
		end
	end
	if origPlaySoundKitID then
		function PlaySoundKitID(...)
			if GhostActive() then
				return
			end
			return origPlaySoundKitID(...)
		end
	end
end

local function UnhookGhostSounds()
	if not ghostSoundsHooked then
		return
	end
	if origPlaySound then
		PlaySound = origPlaySound
	end
	if origPlaySoundFile then
		PlaySoundFile = origPlaySoundFile
	end
	if origPlaySoundKitID then
		PlaySoundKitID = origPlaySoundKitID
	end
	origPlaySound, origPlaySoundFile, origPlaySoundKitID = nil, nil, nil
	ghostSoundsHooked = false
end

local function ApplyGhost(frame)
	frame = frame or ClassTrainerFrame
	if not frame then
		return
	end
	if not ghostRestore then
		ghostRestore = { alpha = frame:GetAlpha() }
	end
	settingGhost = true
	frame:SetAlpha(0)
	settingGhost = false
end

local function StartGhostDriver()
	if not ghostDriver then
		ghostDriver = CreateFrame("Frame")
	end
	ghostDriver:SetScript("OnUpdate", function(self)
		if not GhostActive() then
			self:SetScript("OnUpdate", nil)
			return
		end
		local frame = ClassTrainerFrame
		if frame and frame:GetAlpha() ~= 0 then
			settingGhost = true
			frame:SetAlpha(0)
			settingGhost = false
		end
	end)
end

local function CloseGhostTrainer()
	ghostKeep = true
	ApplyGhost(ClassTrainerFrame)
	if CloseTrainer then
		pcall(CloseTrainer)
	end
	if ClassTrainerFrame then
		if HideUIPanel then
			pcall(HideUIPanel, ClassTrainerFrame)
		end
		ClassTrainerFrame:Hide()
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.3, function()
			if ClassTrainerFrame and ClassTrainerFrame:IsShown() then
				if CloseTrainer then
					pcall(CloseTrainer)
				end
				ClassTrainerFrame:Hide()
			end
			if not ClassTrainerFrame or not ClassTrainerFrame:IsShown() then
				ClearGhost()
			end
		end)
	end
end

function ClearGhost()
	local frame = ClassTrainerFrame
	if ghostTimer then
		ghostTimer:Cancel()
		ghostTimer = nil
	end
	ghostScan, ghostKeep = false, false
	if ghostDriver then
		ghostDriver:SetScript("OnUpdate", nil)
	end
	if frame and ghostRestore then
		settingGhost = true
		frame:SetAlpha(ghostRestore.alpha or 1)
		settingGhost = false
	end
	ghostRestore = nil
	UnhookGhostSounds()
end

local function FinishScan(reason)
	if not scanBusy then
		return
	end
	if TrainerServiceCount() > 0 or reason == "timeout" then
		local full = scanFullFilters and FiltersAllOn()
		if full then
			local added, removed = ApplyScanToLearned()
			scanAdded = (scanAdded or 0) + added
			scanRemoved = (scanRemoved or 0) + removed
			DebugPrint("scan: full list applied  added=" .. tostring(added) .. "  dropped=" .. tostring(removed))
		else
			scanAdded = (scanAdded or 0) + SyncBeastTraining()
			DebugPrint("scan: additive only (filters not all on)")
		end
	end
	local saved = scanSaved
	scanBusy = false
	scanSaved = nil
	scanReadyAt = nil
	scanFullFilters = false
	if scanTimer then
		scanTimer:Cancel()
		scanTimer = nil
	end
	if saved then
		ApplyFilters(saved)
		DebugPrint("scan: filters restored  available=" .. tostring(saved.available) .. "  unavailable=" .. tostring(saved.unavailable) .. "  used=" .. tostring(saved.used))
	end
	if (scanRemoved or 0) > 0 then
		Print("Scan recorded " .. (scanAdded or 0) .. " rank(s), dropped " .. scanRemoved .. " leftover.")
	elseif (scanAdded or 0) > 0 then
		Print("Scan recorded " .. scanAdded .. " teachable rank(s).")
	else
		Print("Scan complete. No new ranks.")
	end
	scanAdded, scanRemoved = 0, 0
	DebugPrint("scan finished (" .. tostring(reason) .. ")")
	if pendingBtConfirm then
		ConfirmPendingInBeastTraining("scan-" .. tostring(reason))
	end
	if ghostScan or ghostKeep then
		CloseGhostTrainer()
	end
	if RefreshPetTooltip then
		RefreshPetTooltip()
		if C_Timer and C_Timer.After then
			C_Timer.After(0.4, RefreshPetTooltip)
		end
	end
end

local function TryFinishScan()
	if not scanBusy then
		return
	end
	if scanReadyAt and (GetTime and GetTime() or 0) < scanReadyAt then
		return
	end
	if scanFullFilters and not FiltersAllOn() then
		EnableAllFilters()
		return
	end
	if TrainerServiceCount() == 0 then
		return
	end
	FinishScan("update")
end

local function StartScan()
	if scanBusy then
		return
	end
	if not IsHunter() or not IsPetTrainer() then
		if not ghostScan then
			Print("Open Beast Training first.")
		end
		return
	end
	if not db then
		return
	end
	scanBusy = true
	scanAdded = 0
	scanRemoved = 0
	scanFullFilters = false
	if CanToggleFilters() then
		scanSaved = ReadFilters()
		EnableAllFilters()
		scanFullFilters = true
		scanReadyAt = (GetTime and GetTime() or 0) + 0.5
		DebugPrint("scan: filters on  available=" .. tostring(scanSaved.available) .. "  unavailable=" .. tostring(scanSaved.unavailable) .. "  used=" .. tostring(scanSaved.used))
		if scanTimer then
			scanTimer:Cancel()
		end
		scanTimer = C_Timer.NewTimer(2, function()
			scanTimer = nil
			FinishScan("timeout")
		end)
		if C_Timer.After then
			C_Timer.After(0.55, TryFinishScan)
		end
		return
	end
	scanSaved = nil
	DebugPrint("scan: no filter API, using current list")
	scanAdded = SyncBeastTraining()
	FinishScan("now")
end

local function FilterAnchor(frame)
	return frame.filterDropdown or frame.FilterDropdown or _G.ClassTrainerFrameFilterDropDown
end

local function PlaceScanButton()
	if not scanButton or not ClassTrainerFrame then
		return
	end
	local pet = IsPetTrainer()
	scanButton:SetShown(pet)
	if not pet then
		return
	end
	scanButton:ClearAllPoints()
	local filter = FilterAnchor(ClassTrainerFrame)
	if filter then
		scanButton:SetPoint("RIGHT", filter, "LEFT", -4, 0)
	else
		scanButton:SetPoint("TOPRIGHT", ClassTrainerFrame, "TOPRIGHT", -36, -32)
	end
end

local function EnsureScanButton()
	if scanButton or not ClassTrainerFrame then
		PlaceScanButton()
		return
	end
	scanButton = CreateFrame("Button", "PetTrainingScanButton", ClassTrainerFrame, "UIPanelButtonTemplate")
	scanButton:SetSize(72, 22)
	scanButton:SetText("Scan")
	scanButton:SetFrameLevel(ClassTrainerFrame:GetFrameLevel() + 5)
	scanButton:SetScript("OnClick", StartScan)
	scanButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Scan")
		GameTooltip:AddLine("Turns on all Beast Training filters, records hunter-known ranks, then restores your filters.", 1, 0.82, 0, true)
		GameTooltip:Show()
	end)
	scanButton:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	PlaceScanButton()
end

local function HookGhostFrame()
	if ghostHooks or not ClassTrainerFrame then
		return
	end
	ghostHooks = true
	hooksecurefunc(ClassTrainerFrame, "SetAlpha", function(self, amount)
		if settingGhost or not GhostActive() then
			return
		end
		if amount ~= 0 then
			settingGhost = true
			self:SetAlpha(0)
			settingGhost = false
		end
	end)
	hooksecurefunc(ClassTrainerFrame, "Show", function(self)
		PlaceScanButton()
		if GhostActive() then
			ApplyGhost(self)
		end
	end)
end

local function HookTrainerUI()
	if not ClassTrainerFrame then
		return
	end
	EnsureScanButton()
	HookGhostFrame()
end

local function AddonLoaded(name)
	if C_AddOns and C_AddOns.IsAddOnLoaded then
		local ok, v = pcall(C_AddOns.IsAddOnLoaded, name)
		return ok and v
	end
	if IsAddOnLoaded then
		local ok, v = pcall(IsAddOnLoaded, name)
		return ok and v
	end
end

local function AddonExists(name)
	if C_AddOns and C_AddOns.DoesAddOnExist then
		local ok, v = pcall(C_AddOns.DoesAddOnExist, name)
		if ok then
			return v and true or false
		end
	end
	if GetAddOnInfo then
		local ok, addonName, _, _, _, reason = pcall(GetAddOnInfo, name)
		if ok and type(addonName) == "string" and addonName ~= "" then
			return reason ~= "MISSING"
		end
	end
	return AddonLoaded(name) and true or false
end

local function WhenAddonLoaded(name, fn)
	if not AddonExists(name) then
		return
	end
	if AddonLoaded(name) then
		fn()
		return
	end
	if EventUtil and EventUtil.ContinueOnAddOnLoaded then
		EventUtil.ContinueOnAddOnLoaded(name, fn)
		return
	end
	local wait = CreateFrame("Frame")
	wait:RegisterEvent("ADDON_LOADED")
	wait:SetScript("OnEvent", function(self, _, loaded)
		if loaded == name then
			self:UnregisterEvent("ADDON_LOADED")
			fn()
		end
	end)
end


local function OpenBeastTraining(silent)
	if InCombatLockdown and InCombatLockdown() then
		if not silent then
			Print("Can't open Beast Training in combat.")
		end
		return false
	end
	if C_SpellBook and C_SpellBook.IsSpellKnown and Enum and Enum.SpellBookSpellBank then
		local ok, known = pcall(C_SpellBook.IsSpellKnown, BEAST_TRAINING, Enum.SpellBookSpellBank.Player)
		if ok and known == false then
			if not silent then
				Print("You do not know Beast Training yet.")
			end
			return false
		end
	end
	GhostDump("open BT")
	local function try(name, fn, ...)
		if not fn then
			DebugPrint("  skip " .. name .. " (nil)")
			return false
		end
		local ok, a, b, c = pcall(fn, ...)
		DebugPrint("  " .. name .. " ok=" .. tostring(ok) .. " r1=" .. tostring(a) .. " r2=" .. tostring(b) .. " r3=" .. tostring(c))
		return ok
	end
	try("C_Spell.CastSpellByID", C_Spell and C_Spell.CastSpellByID, BEAST_TRAINING)
	try("CastSpellByID", CastSpellByID, BEAST_TRAINING)
	try("CastSpellByName", CastSpellByName, SpellName(BEAST_TRAINING) or "Beast Training")
	if C_Timer and C_Timer.After then
		C_Timer.After(0.05, function()
			GhostDump("post-cast 50ms")
		end)
		C_Timer.After(0.5, function()
			GhostDump("post-cast 500ms")
		end)
	end
	return true
end

local function StartGhostScan()
	if scanBusy or ghostScan then
		DebugPrint("StartGhostScan abort: already running scanBusy=" .. tostring(scanBusy) .. " ghostScan=" .. tostring(ghostScan))
		return
	end
	if not IsHunter() or not db then
		DebugPrint("StartGhostScan abort: not hunter/db")
		return
	end
	if InCombatLockdown and InCombatLockdown() then
		SystemMsg("You're in combat, unable to update.")
		DebugPrint("StartGhostScan abort: combat")
		return
	end
	if ClassTrainerFrame and ClassTrainerFrame:IsShown() and IsPetTrainer() and not GhostActive() then
		DebugPrint("StartGhostScan: trainer already open, visible scan")
		StartScan()
		return
	end
	HookTrainerUI()
	HookGhostSounds()
	ghostScan = true
	ghostKeep = true
	StartGhostDriver()
	ApplyGhost(ClassTrainerFrame)
	GhostDump("StartGhostScan")
	if ghostTimer then
		ghostTimer:Cancel()
	end
	ghostTimer = C_Timer.NewTimer(4, function()
		ghostTimer = nil
		if ghostScan and not scanBusy then
			GhostDump("timeout")
			ClearGhost()
		end
	end)
	OpenBeastTraining()
end

local function MarkCurrentPet()
	if not UnitExists("pet") then
		Print("No pet out.")
		return 0
	end
	local added = 0
	local slots = NUM_PET_ACTION_SLOTS or 10
	for slot = 1, slots do
		local spellID = SpellIdFromPetSlot(slot)
		if IsWild(spellID) and MarkLearned(spellID) then
			added = added + 1
		end
	end
	return added
end

local function ArmGhostScan()
	HookTrainerUI()
	HookGhostSounds()
	ghostScan = true
	ghostKeep = true
	StartGhostDriver()
	ApplyGhost(ClassTrainerFrame)
	if ghostTimer then
		ghostTimer:Cancel()
	end
	ghostTimer = C_Timer.NewTimer(4, function()
		ghostTimer = nil
		if ghostScan and not scanBusy then
			GhostDump("timeout")
			ClearGhost()
		end
	end)
end

local function AbilityDisplayName(name)
	if type(name) == "string" then
		name = strtrim(name)
		if name ~= "" then
			return name
		end
	end
	return "pet ability"
end

local function ShowLearnPopup(spellID, nameFromChat, isTest)
	if InCombatLockdown and InCombatLockdown() then
		pendingLearn = { spellID = spellID, name = nameFromChat, isTest = isTest }
		return
	end
	if not learnPopup then
		local template = BackdropTemplateMixin and "BackdropTemplate" or nil
		learnPopup = CreateFrame("Frame", "PetTrainingLearnPopup", UIParent, template)
		learnPopup:SetSize(220, 56)
		learnPopup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
		learnPopup:SetFrameStrata("DIALOG")
		learnPopup:SetToplevel(true)
		learnPopup:SetClampedToScreen(true)
		learnPopup:SetMovable(true)
		if learnPopup.SetBackdrop then
			learnPopup:SetBackdrop({
				bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
				edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
				tile = true,
				tileSize = 16,
				edgeSize = 12,
				insets = { left = 3, right = 3, top = 3, bottom = 3 },
			})
			learnPopup:SetBackdropColor(0.05, 0.04, 0.02, 0.94)
			learnPopup:SetBackdropBorderColor(0.55, 0.45, 0.2, 1)
		end

		learnPopup.title = learnPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		learnPopup.title:SetPoint("TOPLEFT", 12, -10)
		learnPopup.title:SetJustifyH("LEFT")

		learnPopup.text = learnPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		learnPopup.text:SetPoint("TOPLEFT", learnPopup.title, "BOTTOMLEFT", 0, -4)
		learnPopup.text:SetJustifyH("LEFT")
		learnPopup.text:SetJustifyV("TOP")
		learnPopup.text:SetWordWrap(true)

		-- Secure click casts Beast Training (hardware event); PreClick ghosts the window.
		local clicker = CreateFrame("Button", "PetTrainingLearnClick", learnPopup, "SecureActionButtonTemplate")
		clicker:SetAllPoints(learnPopup)
		clicker:SetFrameLevel(learnPopup:GetFrameLevel() + 5)
		clicker:RegisterForClicks("AnyUp", "AnyDown")
		clicker:RegisterForDrag("RightButton")
		clicker:SetAttribute("useOnKeyDown", false)
		clicker:SetAttribute("type", "spell")
		clicker:SetAttribute("spell", BEAST_TRAINING)
		clicker:SetAttribute("type1", "spell")
		clicker:SetAttribute("spell1", BEAST_TRAINING)
		clicker:SetScript("OnDragStart", function()
			learnPopup:StartMoving()
		end)
		clicker:SetScript("OnDragStop", function()
			learnPopup:StopMovingOrSizing()
		end)
		clicker:SetScript("PreClick", function()
			if InCombatLockdown and InCombatLockdown() then
				pendingPopupScan = true
				SystemMsg("You're in combat, unable to update.")
				if learnPopup.text then
					learnPopup.text:SetText("Waiting until you're out of combat. Click again after.")
				end
				DebugPrint("learn popup click in combat, wait")
				return
			end
			DebugPrint("learn popup click -> ghost")
			ArmGhostScan()
		end)
		clicker:SetScript("PostClick", function()
			if pendingPopupScan then
				return
			end
			learnPopup:Hide()
		end)
		clicker:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:SetText("Click to scan Beast Training", 1, 1, 1)
			GameTooltip:AddLine("Right-drag to move.", 0.7, 0.7, 0.7)
			GameTooltip:Show()
		end)
		clicker:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		learnPopup.clicker = clicker
	elseif learnPopup.clicker and not InCombatLockdown() then
		learnPopup.clicker:SetAttribute("type", "spell")
		learnPopup.clicker:SetAttribute("spell", BEAST_TRAINING)
		learnPopup.clicker:SetAttribute("type1", "spell")
		learnPopup.clicker:SetAttribute("spell1", BEAST_TRAINING)
	end
	local label = AbilityDisplayName(nameFromChat)
	if isTest then
		learnPopup.title:SetText("Pet Training  (test)")
		learnPopup.text:SetText("Click this window to ghost-scan Beast Training.")
	else
		learnPopup.title:SetText("Learned " .. label)
		learnPopup.text:SetText("Click this window to scan Beast Training.")
	end
	local padX, padTop, padBot, gap = 12, 10, 10, 4
	local minW, maxW = 180, 360
	learnPopup.title:SetWidth(1000)
	learnPopup.text:SetWidth(1000)
	local need = math.max(learnPopup.title:GetStringWidth() or 0, learnPopup.text:GetStringWidth() or 0)
	local inner = math.min(maxW - padX * 2, math.max(minW - padX * 2, need))
	learnPopup.title:SetWidth(inner)
	learnPopup.text:SetWidth(inner)
	local h = padTop + (learnPopup.title:GetStringHeight() or 12) + gap + (learnPopup.text:GetStringHeight() or 12) + padBot
	learnPopup:SetSize(inner + padX * 2, h)
	learnPopup:Show()
end

local function EnsureDB()
	PetTrainingDB = PetTrainingDB or {}
	if type(PetTrainingDB.learned) ~= "table" then
		PetTrainingDB.learned = {}
	end
	if type(PetTrainingDB.sound) ~= "boolean" then
		PetTrainingDB.sound = defaults.sound
	end
	PetTrainingDB.log = nil
	PetTrainingDB.debug = nil
	db = PetTrainingDB
end

local function LineText(tooltip, i, right)
	local name = tooltip:GetName()
	if not name then
		return
	end
	local fs = _G[name .. (right and "TextRight" or "TextLeft") .. i]
	return fs and Readable(fs:GetText())
end

local function HasStatusLine(tooltip)
	for i = 1, tooltip:NumLines() do
		local text = LineText(tooltip, i)
		if text == "not learned" or text == "known" or text == "upgradeable" then
			return true
		end
	end
	return false
end

local adding

local function AddStatusLine(tooltip, spellID)
	if adding or not tooltip or not tooltip.AddLine then
		return
	end
	EnsureDB()
	if not IsHunter() or not IsWild(spellID) then
		return
	end
	if HasStatusLine(tooltip) then
		lastSpellId = spellID
		return
	end
	lastSpellId = spellID
	adding = true
	if tooltip.AddBlankLine then
		tooltip:AddBlankLine()
	else
		-- A plain " " line is trimmed to nothing on this tooltip; keep a real gap.
		tooltip:AddLine(" ")
		local fs = _G[tooltip:GetName() .. "TextLeft" .. tooltip:NumLines()]
		if fs then
			fs:SetText(" ")
			fs:SetHeight(8)
		end
	end
	if IsLearned(spellID) then
		tooltip:AddLine("known", 0.2, 1, 0.25)
	else
		tooltip:AddLine("not learned", 1, 0.2, 0.2)
	end
	if IsUpgradeable and IsUpgradeable(spellID) then
		tooltip:AddLine("upgradeable", 1, 0.82, 0)
	end
	tooltip:Show()
	adding = false
end

local function SpellIdFromLines(tooltip)
	if not tooltip or not tooltip.NumLines then
		return
	end
	for i = 1, tooltip:NumLines() do
		local text = LineText(tooltip, i)
		if text then
			local id = tonumber(text:match("Spell%s*ID:%s*(%d+)")) or tonumber(text:match("SpellID:%s*(%d+)"))
			if id then
				return id
			end
		end
	end
end

local function SpellIdFromGetSpell(tooltip)
	if not (tooltip and tooltip.GetSpell) then
		return
	end
	local ok, a, b, c = pcall(tooltip.GetSpell, tooltip)
	if not ok then
		return
	end
	a, b, c = Readable(a), Readable(b), Readable(c)
	if type(c) == "number" then
		return c
	end
	if type(b) == "number" then
		return b
	end
	if type(a) == "number" then
		return a
	end
end

-- Forever / retail: name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID
local function CallPetActionInfo(slot)
	local apis = {}
	if C_PetBar and C_PetBar.GetPetActionInfo then
		apis[#apis + 1] = C_PetBar.GetPetActionInfo
	end
	if C_ActionBar and C_ActionBar.GetPetActionInfo then
		apis[#apis + 1] = C_ActionBar.GetPetActionInfo
	end
	if GetPetActionInfo then
		apis[#apis + 1] = GetPetActionInfo
	end
	for i = 1, #apis do
		local ok, name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, spellID = pcall(apis[i], slot)
		if ok and (name or spellID) then
			spellID = Readable(spellID)
			if (type(spellID) ~= "number" or spellID == 0) and C_PetInfo and C_PetInfo.GetSpellForPetAction then
				local okPet, sid = pcall(C_PetInfo.GetSpellForPetAction, slot)
				if okPet then
					spellID = Readable(sid)
				end
			end
			return Readable(name), spellID, Readable(isToken)
		end
	end
	if C_PetInfo and C_PetInfo.GetSpellForPetAction then
		local ok, sid = pcall(C_PetInfo.GetSpellForPetAction, slot)
		if ok and Readable(sid) then
			return nil, Readable(sid)
		end
	end
end

local function SpellIdFromName(name)
	name = Readable(name)
	if type(name) ~= "string" or name == "" then
		return
	end
	local base = strtrim((name:match("^(.-)%s*%(") or name))
	local rank
	if GameTooltip and GameTooltip:IsShown() then
		local right = LineText(GameTooltip, 1, true)
		rank = right and tonumber(right:match("(%d+)"))
	end
	local fallback
	for id in pairs(WILD) do
		local n = SpellName(id)
		if n and strlower(n) == strlower(base) then
			local sub = SpellSubtext(id)
			local subRank = sub and tonumber(sub:match("(%d+)"))
			if rank and subRank == rank then
				return id
			end
			fallback = fallback or id
		end
	end
	if not rank then
		return fallback
	end
end

local function SpellIdFromPetSlot(slot)
	slot = Readable(slot)
	if type(slot) ~= "number" then
		return
	end
	local name, spellID, isToken = CallPetActionInfo(slot)
	spellID = Readable(spellID)
	if type(spellID) == "number" and spellID > 0 then
		return spellID
	end
	if not isToken then
		return SpellIdFromName(name)
	end
end

local function HighestIndexOnPetBar(chain)
	if not chain or not UnitExists("pet") then
		return 0
	end
	local best = 0
	local n = NUM_PET_ACTION_SLOTS or 10
	for slot = 1, n do
		local id = SpellIdFromPetSlot(slot)
		local info = id and CHAIN_INDEX[id]
		if info and info.chain == chain and info.index > best then
			best = info.index
		end
	end
	return best
end

local function HighestTeachableIndex(chain)
	if not chain then
		return 0
	end
	local best = 0
	for i = 1, #chain do
		if IsLearned(chain[i]) and i > best then
			best = i
		end
	end
	return best
end

-- Pet bar rank vs highest rank the hunter has actually learned.
function IsUpgradeable(spellID)
	local info = CHAIN_INDEX[spellID]
	if not info then
		return false
	end
	local petIndex = HighestIndexOnPetBar(info.chain)
	if petIndex < 1 then
		return false
	end
	return HighestTeachableIndex(info.chain) > petIndex
end

local function SpellIdFromTooltip(tooltip, data, petSlot)
	local id = SpellIdFromPetSlot(petSlot)
	if id then
		return id
	end
	id = data and Readable(data.id)
	if type(id) == "number" and IsWild(id) then
		return id
	end
	id = SpellIdFromGetSpell(tooltip)
	if id then
		return id
	end
	id = SpellIdFromLines(tooltip)
	if id then
		return id
	end
	if type(data and data.id) == "number" then
		return Readable(data.id)
	end
end

local function ApplyStatus(tooltip, data, petSlot)
	if adding or not tooltip or (tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip) then
		return
	end
	if not IsHunter() then
		return
	end
	EnsureDB()
	AddStatusLine(tooltip, SpellIdFromTooltip(tooltip, data, petSlot))
end

function RefreshPetTooltip()
	if not GameTooltip or not GameTooltip:IsShown() then
		return
	end
	if lastPetSlot and GameTooltip.SetPetAction then
		GameTooltip:SetPetAction(lastPetSlot)
		return
	end
	if lastSpellId then
		AddStatusLine(GameTooltip, lastSpellId)
	end
end

local petClickHooked = {}

local function OnPetButtonClick(self, mouseButton)
	if not IsAltKeyDown() then
		return
	end
	if mouseButton and mouseButton ~= "LeftButton" then
		return
	end
	local slot = self.id or self._state_action or (self.GetID and self:GetID())
	if (type(slot) ~= "number" or slot < 1) and self.GetName then
		slot = tonumber((self:GetName() or ""):match("(%d+)$"))
	end
	if type(slot) ~= "number" or slot < 1 then
		return
	end
	lastPetSlot = slot
	lastSpellId = SpellIdFromPetSlot(slot)
	DebugPrint("alt-click pet slot=" .. slot .. " spell=" .. tostring(lastSpellId))
	StartGhostScan()
end

local function FrameHasScript(frame, script)
	if not frame or not frame.HasScript then
		return false
	end
	local ok, has = pcall(frame.HasScript, frame, script)
	return ok and has and true or false
end

local function HookPetButton(btn)
	if not btn or petClickHooked[btn] then
		return
	end
	-- Forever PetActionBar / Edit Mode chrome are Frames; they have no OnClick.
	if not FrameHasScript(btn, "OnClick") then
		petClickHooked[btn] = true
		return
	end
	petClickHooked[btn] = true
	pcall(btn.HookScript, btn, "OnClick", OnPetButtonClick)
	if FrameHasScript(btn, "PostClick") then
		pcall(btn.HookScript, btn, "PostClick", OnPetButtonClick)
	end
end

local function HookButtonList(list)
	if type(list) ~= "table" then
		return
	end
	for _, btn in pairs(list) do
		HookPetButton(btn)
	end
end

local function HookPetBarFrame(frame)
	if not frame then
		return
	end
	-- Do not HookScript the bar itself. Forever's PetActionBar is the Edit Mode
	-- container; clicks live on PetActionButton1..10 / actionButtons.
	HookButtonList(frame.actionButtons)
	HookButtonList(frame.buttons)
	HookButtonList(frame.shownButtonContainers)
	local kids = { frame:GetChildren() }
	for i = 1, #kids do
		local child = kids[i]
		if FrameHasScript(child, "OnClick") then
			HookPetButton(child)
		end
	end
end

local function HookElvUIPetBar()
	local E = ElvUI and ElvUI[1]
	if not E then
		return
	end
	local AB = E.ActionBars
	if not AB and E.GetModule then
		local ok, mod = pcall(function()
			return E:GetModule("ActionBars")
		end)
		AB = ok and mod
	end
	if not AB then
		return
	end
	HookPetBarFrame(AB.petBar)
	if type(AB.handledBars) == "table" then
		HookPetBarFrame(AB.handledBars.barPet)
		HookPetBarFrame(AB.handledBars.petbar)
		HookPetBarFrame(AB.handledBars.petBar)
	end
end

local hookedUsePetAction

local PET_BAR_PACKS = {
	{ addon = "Bartender4", prefixes = { "BT4PetButton" } },
	{ addon = "Dominos", prefixes = { "DominosPetActionButton" } },
	{
		addon = "ElvUI",
		prefixes = {
			"ElvUI_BarPetButton",
			"ElvUIPetBarButton",
			"ElvUI_PetBarButton",
			"ElvUIPetButton",
			"ElvUI_PetActionButton",
		},
		frames = { "ElvUI_BarPet", "ElvUIPetBar", "ElvUI_PetBar" },
		extra = function()
			HookElvUIPetBar()
		end,
	},
}

function HookPetBarClicks()
	local n = NUM_PET_ACTION_SLOTS or 10
	for i = 1, n do
		HookPetButton(_G["PetActionButton" .. i])
	end
	HookPetBarFrame(_G.PetActionBarFrame)
	HookPetBarFrame(_G.PetActionBar)
	for p = 1, #PET_BAR_PACKS do
		local pack = PET_BAR_PACKS[p]
		if AddonLoaded(pack.addon) then
			for i = 1, n do
				for k = 1, #(pack.prefixes or {}) do
					HookPetButton(_G[pack.prefixes[k] .. i])
				end
			end
			for k = 1, #(pack.frames or {}) do
				HookPetBarFrame(_G[pack.frames[k]])
			end
			if pack.extra then
				pack.extra()
			end
		end
	end
	if not hookedUsePetAction and UsePetAction then
		hookedUsePetAction = true
		hooksecurefunc("UsePetAction", function(index)
			if not IsAltKeyDown() then
				return
			end
			lastPetSlot = index
			lastSpellId = SpellIdFromPetSlot(index)
			DebugPrint("alt UsePetAction slot=" .. tostring(index) .. " spell=" .. tostring(lastSpellId))
			StartGhostScan()
		end)
	end
end

local hooked
local function HookTooltips()
	if hooked then
		return
	end
	hooked = true
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		local T = Enum.TooltipDataType
		for _, key in ipairs({ "Spell", "PetAction", "TrainerService", "Macro" }) do
			if T[key] then
				TooltipDataProcessor.AddTooltipPostCall(T[key], function(tooltip, data)
					ApplyStatus(tooltip, data)
				end)
			end
		end
	end
	if GameTooltip then
		if GameTooltip.HookScript then
			pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetSpell", function(tooltip)
				ApplyStatus(tooltip)
			end)
		end
		for _, method in ipairs({ "SetPetAction", "SetSpellByID", "SetSpellBookItem", "SetTrainerService", "SetAction" }) do
			if GameTooltip[method] then
				hooksecurefunc(GameTooltip, method, function(tooltip, a)
					ApplyStatus(tooltip, nil, method == "SetPetAction" and a or nil)
				end)
			end
		end
	end
end

local LEARN_STRING_KEYS = {
	"ERR_LEARN_SPELL_S",
	"ERR_LEARN_ABILITY_S",
	"ERR_LEARN_PASSIVE_S",
}

local function PatternFrom(fmt)
	if type(fmt) ~= "string" then
		return nil
	end
	-- Trailing period is optional; Forever links can omit it or add extra tokens.
	fmt = fmt:gsub("%.%s*$", "")
	local pat = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
	pat = pat:gsub("%%s", "(.+)")
	pat = pat:gsub("%%d", "(%%d+)")
	return pat
end

local function LearnPatterns()
	local list = {}
	for _, key in ipairs(LEARN_STRING_KEYS) do
		local pat = PatternFrom(_G[key])
		if pat then
			list[#list + 1] = pat
		end
	end
	-- Fallback if globals are missing at load.
	list[#list + 1] = "You have learned a new spell:%s*(.+)"
	list[#list + 1] = "You have learned a new ability:%s*(.+)"
	list[#list + 1] = "You have learned a new passive:%s*(.+)"
	return list
end

local function StripColors(text)
	if type(text) ~= "string" then
		return text
	end
	return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

-- Spell links: |Hspell:id|h[Swipe]|h. Use the text between [ ], ignore the id.
local function BracketText(text)
	if type(text) ~= "string" then
		return
	end
	local name = text:match("|h%[(.-)%]|h") or text:match("%[(.-)%]")
	if name then
		return strtrim(StripColors(name):gsub("%.%s*$", ""))
	end
end

local function CleanAbilityName(name)
	if type(name) ~= "string" then
		return name
	end
	name = StripColors(name)
	name = BracketText(name) or name
	name = strtrim(name:gsub("%.%s*$", ""))
	return name
end

local function AbilityBaseName(name)
	name = CleanAbilityName(name)
	if type(name) ~= "string" or name == "" then
		return name
	end
	local base = name:match("^(.-)%s*%(") or name
	base = base:match("^(.-)%s+[Rr]ank%s*%d+") or base
	return strtrim(base)
end

local function ParseLearned(message)
	if type(message) ~= "string" then
		return
	end
	local plain = StripColors(message)
	local name = BracketText(message) or BracketText(plain)
	local captured
	for _, pat in ipairs(LearnPatterns()) do
		captured = plain:match(pat) or message:match(pat)
		if captured then
			break
		end
	end
	if not captured then
		captured = plain:match("[Yy]ou have learned a new spell:%s*(.+)")
			or plain:match("[Yy]ou have learned a new ability:%s*(.+)")
			or plain:match("[Yy]ou have learned a new passive:%s*(.+)")
	end
	if not captured then
		local lower = plain:lower()
		if lower:find("learned a new", 1, true) then
			return nil, name, nil
		end
		return
	end
	captured = captured:gsub("%.%s*$", "")
	name = name or CleanAbilityName(captured)
	return nil, name, captured
end

local function NameLooksWild(name)
	local base = AbilityBaseName(name)
	if type(base) ~= "string" or base == "" then
		return false
	end
	if not WILD_NAMES[strlower(base)] then
		return false
	end
	return true
end

-- Mark the rank on the pet bar, or Rank N from the chat name. Never pick a
-- random same-name id from WILD (pairs() order) or "upgradeable" goes false.
local function MarkLearnedFromChat(spellID, name)
	name = CleanAbilityName(name)
	local base = AbilityBaseName(name)
	if spellID and IsWild(spellID) then
		MarkLearned(spellID)
	end
	if not base or base == "" then
		return
	end
	local nslots = NUM_PET_ACTION_SLOTS or 10
	for slot = 1, nslots do
		local id = SpellIdFromPetSlot(slot)
		if id then
			local n = SpellName(id)
			if n and strlower(n) == strlower(base) then
				WILD[id] = true
				MarkLearned(id)
			end
		end
	end
	local rank = name and tonumber(name:match("[Rr]ank%s*(%d+)"))
	if not rank then
		return
	end
	for id in pairs(WILD) do
		local n = SpellName(id)
		if n and strlower(n) == strlower(base) then
			local sub = SpellSubtext(id)
			local subRank = sub and tonumber(sub:match("(%d+)"))
			local info = CHAIN_INDEX[id]
			if subRank == rank or (info and info.index == rank) then
				MarkLearned(id)
			end
		end
	end
end

local function SpellKnownOn(spellID, petBook)
	if not spellID then
		return nil
	end
	local bankEnum = Enum and Enum.SpellBookSpellBank
	local bank = bankEnum and (petBook and bankEnum.Pet or bankEnum.Player)
	if C_SpellBook and C_SpellBook.IsSpellKnown and bank ~= nil then
		local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID, bank)
		if ok then
			return known
		end
	end
	if IsSpellKnown then
		local ok, known = pcall(IsSpellKnown, spellID, petBook and true or false)
		if ok then
			return known
		end
	end
	if not petBook and IsPlayerSpell then
		local ok, known = pcall(IsPlayerSpell, spellID)
		if ok then
			return known
		end
	end
end

local function PetBarSlotsFor(spellID, name)
	local slots = {}
	local n = NUM_PET_ACTION_SLOTS or 10
	local base = name and strtrim((name:match("^(.-)%s*%(") or name))
	for i = 1, n do
		local slotName, slotID = CallPetActionInfo(i)
		slotID = Readable(slotID)
		local match = false
		if spellID and type(slotID) == "number" and slotID == spellID then
			match = true
		elseif spellID then
			local fromSlot = SpellIdFromPetSlot(i)
			if fromSlot == spellID then
				match = true
			end
		elseif base and type(slotName) == "string" and strlower(slotName) == strlower(base) then
			match = true
		end
		if match then
			slots[#slots + 1] = i
		end
	end
	return slots
end

local function FindInBeastTraining(spellID, name)
	if not GetNumTrainerServices or not IsPetTrainer() then
		return
	end
	local base = name and strtrim((name:match("^(.-)%s*%(") or name))
	for index = 1, TrainerServiceCount() do
		local id = TrainerSpellID(index)
		if spellID and id == spellID then
			return index, id, TrainerServiceStatus(index)
		end
		if not id and base then
			local info = { GetTrainerServiceInfo(index) }
			local rowName = Readable(info[1])
			if type(rowName) == "string" and strlower(rowName) == strlower(base) then
				return index, id, TrainerServiceStatus(index)
			end
		end
	end
end

local function TrainerOpenKind()
	local frame = ClassTrainerFrame
	local shown = frame and frame.IsShown and frame:IsShown()
	if not shown then
		return "closed"
	end
	if IsPetTrainer() then
		return "beast-training"
	end
	return "player-trainer"
end

local function ClassifyLearnSource(spellID, name)
	local wild = IsWild(spellID) or NameLooksWild(name)
	local slots = PetBarSlotsFor(spellID, name)
	local petOut = UnitExists("pet") and true or false
	local trainer = TrainerOpenKind()
	if trainer == "player-trainer" then
		return "player-trainer"
	end
	if not wild then
		return "player-spell"
	end
	if #slots > 0 then
		return "pet-bar"
	end
	if petOut then
		return "pet-out"
	end
	if trainer == "beast-training" then
		return "beast-training"
	end
	return "wild-no-pet"
end

local function IsPetLearnSource(source)
	return source == "pet-bar" or source == "pet-out" or source == "beast-training" or source == "wild-no-pet"
end

local function ConfirmPendingInBeastTraining(reason)
	if not pendingBtConfirm then
		return
	end
	local rec = pendingBtConfirm
	local age = (GetTime and GetTime() or 0) - (rec.at or 0)
	if age > 180 then
		DebugPrint("BT confirm expired for " .. SpellLabel(rec.spellID, rec.name) .. " after " .. string.format("%.1f", age) .. "s")
		pendingBtConfirm = nil
		return
	end
	local index, id, status = FindInBeastTraining(rec.spellID, rec.name)
	if not index then
		DebugPrint(string.format(
			"BT watch (%s): %s not in Beast Training yet  services=%s  trainer=%s  age=%.1fs",
			tostring(reason),
			SpellLabel(rec.spellID, rec.name),
			tostring(TrainerServiceCount()),
			TrainerOpenKind(),
			age
		))
		return
	end
	local sid = id or rec.spellID
	if sid then
		MarkLearned(sid)
	end
	DebugPrint(string.format(
		"BT watch (%s): FOUND %s at row %d status=%s id=%s  %.1fs after pet-learn",
		tostring(reason),
		SpellLabel(sid, rec.name),
		index,
		tostring(status),
		tostring(sid),
		age
	))
	Print("Beast Training now lists " .. SpellLabel(sid, rec.name) .. ".")
	pendingBtConfirm = nil
	if RefreshPetTooltip then
		RefreshPetTooltip()
	end
end

local lastPetLearnAt, lastPetLearnId, lastPetLearnName

local function AcceptPetLearn(spellID, name, source, why)
	local now = GetTime and GetTime() or 0
	local base = AbilityBaseName(name)
	local same = (spellID and spellID == lastPetLearnId)
		or (base and lastPetLearnName and strlower(base) == lastPetLearnName)
	if same and now - (lastPetLearnAt or 0) < 2 then
		DebugPrint("learn debounce (" .. tostring(why) .. ") id=" .. tostring(spellID) .. " name=" .. tostring(base))
		if pendingBtConfirm then
			ConfirmPendingInBeastTraining(why)
		end
		return
	end
	lastPetLearnId, lastPetLearnAt = spellID, now
	lastPetLearnName = base and strlower(base)
	pendingBtConfirm = {
		spellID = spellID,
		name = name,
		source = source,
		at = now,
		why = why,
	}
	MarkLearnedFromChat(spellID, name)
	ShowLearnPopup(spellID, name)
	ConfirmPendingInBeastTraining(why)
end

local function OnSystemMessage(message)
	if not IsHunter() or not db then
		return
	end
	if TrainerOpenKind() == "beast-training" then
		DebugPrint("ignored learn chat (Beast Training is open)")
		return
	end
	local plain = type(message) == "string" and StripColors(message):lower() or ""
	local looksLearn = plain:find("you have learned a new", 1, true) or plain:find("learned a new spell", 1, true)
	local _, name, captured = ParseLearned(message)
	name = BracketText(message) or name
	if not looksLearn then
		if DebugOn() and type(message) == "string" and message:lower():find("learn", 1, true) then
			DebugPrint("CHAT_MSG_SYSTEM (learn-ish): " .. message:gsub("|", "||"))
		end
		return
	end
	local wildName = NameLooksWild(name)
	local source = ClassifyLearnSource(nil, name)
	DumpLearnDetect(message, nil, name, captured, source)
	if not wildName then
		DebugPrint("ignored learn chat (name not a pet ability) " .. tostring(name))
		return
	end
	if source == "player-trainer" then
		DebugPrint("ignored learn chat (player trainer open)")
		return
	end
	AcceptPetLearn(nil, name, source, "learn-chat")
end

local function SkillLineLabel(index)
	if type(index) ~= "number" then
		return "?"
	end
	if C_SpellBook and C_SpellBook.GetSpellBookSkillLineInfo then
		local ok, info = pcall(C_SpellBook.GetSpellBookSkillLineInfo, index)
		if ok and type(info) == "table" then
			return tostring(info.name or info.skillLineName) .. " idx=" .. index
		end
	end
	if GetSpellTabInfo then
		local ok, name = pcall(GetSpellTabInfo, index)
		if ok and Readable(name) then
			return tostring(Readable(name)) .. " idx=" .. index
		end
	end
	return "idx=" .. tostring(index)
end

-- Wiki: LEARNED_SPELL_IN_TAB / LEARNED_SPELL_IN_SKILL_LINE fire when a spell is added to the spellbook.
local function OnLearnedSpellInBook(event, spellID, skillIndex, isGuild)
	if not IsHunter() or not db then
		return
	end
	spellID = Readable(spellID)
	if type(spellID) ~= "number" then
		DebugPrint(event .. " missing spellID  a1=" .. tostring(spellID) .. " a2=" .. tostring(skillIndex))
		return
	end
	local name = SpellName(spellID)
	local source = ClassifyLearnSource(spellID, name)
	DebugPrint(string.format(
		"%s id=%s %s  skillLine=%s  guild=%s  playerKnown=%s petKnown=%s  source=%s",
		event,
		tostring(spellID),
		SpellLabel(spellID, name),
		SkillLineLabel(skillIndex),
		tostring(isGuild),
		tostring(SpellKnownOn(spellID, false)),
		tostring(SpellKnownOn(spellID, true)),
		tostring(source)
	))
	DumpLearnDetect(event, spellID, name, nil, source)
	if not IsWild(spellID) then
		DebugPrint(event .. " ignored (class/trainer spell, not a wild pet rank)")
		return
	end
	if source == "player-trainer" then
		DebugPrint(event .. " ignored (player trainer window open)")
		return
	end
	if source == "beast-training" then
		DebugPrint(event .. " ignored (Beast Training is open)")
		return
	end
	AcceptPetLearn(spellID, name, source, event)
end

SLASH_PETTRAINING1 = "/pt"
SLASH_PETTRAINING2 = "/pettraining"
SlashCmdList.PETTRAINING = function(msg)
	msg = strtrim(strlower(msg or ""))
	EnsureDB()
	if msg == "sound" then
		db.sound = not db.sound
		Print("Sound " .. (db.sound and "on" or "off") .. ".")
		return
	end
	if msg == "mark" then
		if not lastSpellId or not IsWild(lastSpellId) then
			Print("Hover a pet ability first, then /pt mark.")
			return
		end
		if MarkLearned(lastSpellId) then
			Print("Marked " .. SpellLabel(lastSpellId) .. " as known.")
		else
			Print(SpellLabel(lastSpellId) .. " is already known.")
		end
		return
	end
	if msg == "unmark" then
		if not lastSpellId then
			Print("Hover a pet ability first, then /pt unmark.")
			return
		end
		db.learned[lastSpellId] = nil
		Print("Cleared " .. SpellLabel(lastSpellId) .. ".")
		return
	end
	if msg == "list" then
		local n = 0
		for id in pairs(db.learned) do
			n = n + 1
			Print("known  " .. SpellLabel(id) .. "  (" .. id .. ")")
		end
		if n == 0 then
			Print("No learned pet abilities saved yet.")
		end
		return
	end
	if msg == "debug" or msg == "logclear" then
		local D = PetTrainingDebug
		if D and D.Slash and D.Slash(msg) then
			return
		end
		Print("Debug file is not loaded. Add PetTrainingDebug.lua to the TOC to enable it.")
		return
	end
	if msg == "sync" then
		OpenBeastTraining()
		Print("Opening Beast Training…")
		return
	end
	if msg == "scan" then
		StartScan()
		return
	end
	if msg == "test" then
		ShowLearnPopup(nil, "Bite (Rank 3)", true)
		return
	end
	Print("/pt mark | unmark | list | sound | sync | scan | test")
	Print("Ghost scan: click the learn popup or Alt-click a pet ability.")
end

local HUNTER_EVENTS = {
	"CHAT_MSG_SYSTEM",
	"LEARNED_SPELL_IN_TAB",
	"LEARNED_SPELL_IN_SKILL_LINE",
	"TRAINER_SHOW",
	"TRAINER_UPDATE",
	"SPELLS_CHANGED",
	"UNIT_SPELLCAST_SUCCEEDED",
	"UNIT_SPELLCAST_FAILED",
	"UNIT_SPELLCAST_INTERRUPTED",
	"PLAYER_REGEN_ENABLED",
	"PET_BAR_UPDATE",
}

local function RegisterHunterEvents(frame)
	for i = 1, #HUNTER_EVENTS do
		local e = HUNTER_EVENTS[i]
		if C_EventUtils and C_EventUtils.IsEventValid then
			local ok, valid = pcall(C_EventUtils.IsEventValid, e)
			if ok and valid == false then
				DebugPrint("skip invalid event " .. e)
			else
				frame:RegisterEvent(e)
			end
		else
			pcall(frame.RegisterEvent, frame, e)
		end
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local name = ...
		if name ~= ADDON then
			return
		end
		EnsureDB()
		HookTooltips()
		self:UnregisterEvent("ADDON_LOADED")
		if IsHunter() then
			RegisterHunterEvents(self)
		end
	elseif event == "PLAYER_LOGIN" then
		EnsureDB()
		HookTooltips()
		HookPetBarClicks()
		if IsHunter() then
			RegisterHunterEvents(self)
			if DebugOn() then
				DebugPrint("learn globals at login:")
				DumpLearnGlobals()
			end
		end
		self:UnregisterEvent("PLAYER_LOGIN")
	elseif event == "PET_BAR_UPDATE" then
		HookPetBarClicks()
	elseif event == "SPELLS_CHANGED" then
		if pendingBtConfirm then
			ConfirmPendingInBeastTraining("SPELLS_CHANGED")
		end
	elseif event == "LEARNED_SPELL_IN_TAB" or event == "LEARNED_SPELL_IN_SKILL_LINE" then
		OnLearnedSpellInBook(event, ...)
	elseif event == "CHAT_MSG_SYSTEM" then
		OnSystemMessage(...)
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" or event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		local unit, a2, a3, a4, a5 = ...
		if unit ~= "player" then
			return
		end
		local spellID = a3
		if type(spellID) ~= "number" then
			spellID = a5
		end
		if type(spellID) ~= "number" then
			spellID = a2
		end
		if spellID == BEAST_TRAINING then
			DebugPrint(event .. " id=" .. tostring(spellID) .. " a2=" .. tostring(a2) .. " a3=" .. tostring(a3) .. " a4=" .. tostring(a4) .. " a5=" .. tostring(a5))
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if pendingPopupScan then
			pendingPopupScan = nil
			if learnPopup then
				if learnPopup.text then
					learnPopup.text:SetText("Click this window to scan Beast Training.")
				end
				learnPopup:Show()
			end
			SystemMsg("Out of combat. Click the window to scan Beast Training.")
		end
		if pendingLearn then
			local pending = pendingLearn
			pendingLearn = nil
			ShowLearnPopup(pending.spellID, pending.name, pending.isTest)
		end
	elseif event == "TRAINER_SHOW" or event == "TRAINER_UPDATE" then
		EnsureScanButton()
		if GhostActive() and ClassTrainerFrame then
			ApplyGhost(ClassTrainerFrame)
		end
		DumpBeastTraining(event)
		if pendingBtConfirm then
			ConfirmPendingInBeastTraining(event)
		end
		if ghostScan and not scanBusy then
			StartScan()
		elseif scanBusy then
			TryFinishScan()
		elseif not GhostActive() then
			local added = SyncBeastTraining()
			if added > 0 then
				Print("Beast Training recorded " .. added .. " teachable rank(s).")
			end
			if pendingBtConfirm then
				ConfirmPendingInBeastTraining(event .. "-sync")
			end
		end
	end
end)

if EventUtil and EventUtil.ContinueOnAddOnLoaded then
	EventUtil.ContinueOnAddOnLoaded("Blizzard_TrainerUI", HookTrainerUI)
elseif ClassTrainerFrame then
	HookTrainerUI()
else
	local wait = CreateFrame("Frame")
	wait:RegisterEvent("ADDON_LOADED")
	wait:SetScript("OnEvent", function(self, _, name)
		if name == "Blizzard_TrainerUI" then
			HookTrainerUI()
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end

WhenAddonLoaded("Bartender4", HookPetBarClicks)
WhenAddonLoaded("Dominos", HookPetBarClicks)
WhenAddonLoaded("ElvUI", function()
	HookPetBarClicks()
	if C_Timer and C_Timer.After then
		C_Timer.After(1, HookPetBarClicks)
	end
end)

HookTooltips()
HookPetBarClicks()

PetTraining = {
	GetDB = function()
		return db
	end,
	IsHunter = IsHunter,
	IsPetTrainer = IsPetTrainer,
	IsWild = IsWild,
	IsLearned = IsLearned,
	NameLooksWild = NameLooksWild,
	SpellLabel = SpellLabel,
	TrainerServiceCount = TrainerServiceCount,
	TrainerServiceStatus = TrainerServiceStatus,
	TrainerSpellID = TrainerSpellID,
	GetTrainerTypeValue = GetTrainerTypeValue,
	FilterKinds = function()
		return FILTER_KINDS
	end,
	BeastTraining = function()
		return BEAST_TRAINING
	end,
	GhostState = function()
		return ghostScan, ghostKeep, scanBusy, ghostSoundsHooked
	end,
	AbilityBaseName = AbilityBaseName,
	BracketText = BracketText,
	SpellKnownOn = SpellKnownOn,
	PetBarSlotsFor = PetBarSlotsFor,
	FindInBeastTraining = FindInBeastTraining,
	TrainerOpenKind = TrainerOpenKind,
	IsPetLearnSource = IsPetLearnSource,
	SkillLineLabel = SkillLineLabel,
	AddonLoaded = AddonLoaded,
	SpellIdFromPetSlot = SpellIdFromPetSlot,
	CallPetActionInfo = CallPetActionInfo,
	LearnStringKeys = function()
		return LEARN_STRING_KEYS
	end,
}
