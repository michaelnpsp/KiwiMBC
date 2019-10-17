-- KiwiMBC (C) 2019 MiCHaEL

local addon = CreateFrame('Frame')
addon.addonName = ...

--- upvalues

local ipairs = ipairs
local strfind = strfind
local GetTime = GetTime
local C_Timer_After = C_Timer.After

--- upvalues

local defaults = {
	hide = { clock = false, zoom = false, time = false, zone = false, toggle = false, worldmap = false },
}

--- frames to ignore in minimap button collection

local Ignore = {
	"Questie",
	ActionBar = true,
	BonusActionButton = true,
	MainMenu = true,
	ShapeshiftButton = true,
	MultiBar = true,
	KeyRingButton = true,
	PlayerFrame = true,
	TargetFrame = true,
	PartyMemberFrame = true,
	ChatFrame = true,
	ExhaustionTick = true,
	TargetofTargetFrame = true,
	WorldFrame = true,
	ActionButton = true,
	CharacterMicroButton = true,
	SpellbookMicroButton = true,
	TalentMicroButton = true,
	QuestLogMicroButton = true,
	SocialsMicroButton = true,
	LFGMicroButton = true,
	HelpMicroButton = true,
	CharacterBag = true,
	PetFrame = true,
	MinimapCluster = true,
	MinimapBackdrop = true,
	UIParent = true,
	WorldFrame = true,
	Minimap = true,
	BuffButton = true,
	BuffFrame = true,
	TimeManagerClockButton = true,
	CharacterFrame =true,
	WorldFrame = true,
	Minimap = true,
	MinimapBackdrop = true,
	UIParent = true,
	MinimapCluster = true,
	MinimapButtonFrameDragButton = true,
	MiniMapTracking = true,
	MiniMapVoiceChatFrame = true,
	MiniMapWorldMapButton = true,
	MiniMapLFGFrame = true,
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	MiniMapMailFrame = true,
	MiniMapBattlefieldFrame = true,
	GameTimeFrame = true,
	FeedbackUIButton =true,
	MiniMapTrackingFrame = true
}

local cfg
local minimapButtons = {}
local insideMinimap = false
local dragStart = false
local timerActive = false
local delayHide = .5
local dealyShow = .5

--- utils
local function CopyTable(src, dst)
	if type(dst)~="table" then dst = {} end
	for k,v in pairs(src) do
		if type(v)=="table" then
			dst[k] = CopyTable(v,dst[k])
		elseif dst[k]==nil then
			dst[k] = v
		end
	end
	return dst
end

--- minimap buttons visibility control
local UpdateButtonsVisibility, UpdateButtonsVisibilityDelayed
do
	function UpdateButtonsVisibility()
		timerActive = false
		if not dragStart then
			for button in pairs(minimapButtons) do
				button:SetShown(insideMinimap)
			end
		end
	end
	function UpdateButtonsVisibilityDelayed()
		if not timerActive then
			timerActive = GetTime()
			C_Timer_After(insideMinimap and delayShow or delayHide,UpdateButtonsVisibility)
		end
	end
end

-- event hooks
local function MinimapOnEnter(f)
	if not insideMinimap then
		insideMinimap = true
		UpdateButtonsVisibilityDelayed()
	end
end

local function MinimapOnLeave(f)
	if insideMinimap then
		insideMinimap = false
		UpdateButtonsVisibilityDelayed()
	end
end

local function MinimapDragStart()
	dragStart = true
end

local function MinimapDragStop()
	dragStart = false
	UpdateButtonsVisibilityDelayed()
end

-- collect buttons from minimap
local CollectMinimapButtons, CollectSavedMinimapButtons
do
	local function AddMinimapButton(f, name)
		minimapButtons[f] = true
		f:HookScript('OnEnter', MinimapOnEnter)
		f:HookScript('OnLeave', MinimapOnLeave)
		f:HookScript("OnDragStart", MinimapDragStart)
		f:HookScript("OnDragStop", MinimapDragStop)
	end
	local function IsValidButtonName(name)
		if name and name~='' and not Ignore[name] then
			for _,pattern in ipairs(Ignore) do
				if strfind(name, pattern) then
					return false
				end
			end
			return true
		end
	end
	local function CollectFrameButtons(frame)
		for _, f in ipairs({frame:GetChildren()}) do
			if not minimapButtons[f] and f:HasScript('OnClick') and f:IsShown() then
				local name = f:GetName()
				if IsValidButtonName(name) then
					AddMinimapButton(f, name)
				end
			end
		end
	end
	function CollectMinimapButtons()
		CollectFrameButtons(Minimap)
		CollectFrameButtons(MinimapBackdrop)
	end
end

local function UpdateMinimapButtons()
	CollectMinimapButtons()
	UpdateButtonsVisibility()
end

local UpdateBlizzardVisibility
do
	local function Hide( name, frame )
		if frame then frame:SetShown(not cfg.hide[name]) end
	end
	local function HideZoneText()
		MinimapZoneTextButton:SetShown(not cfg.hide.zone)
		MinimapBorderTop:SetTexture( cfg.hide.zone and "" or "Interface\\Minimap\\UI-Minimap-Border")
	end
	function UpdateBlizzardVisibility()
		Hide( 'clock', TimeManagerClockButton )
		Hide( 'zoom',  MinimapZoomOut )
		Hide( 'zoom',  MinimapZoomIn )
		Hide( 'time',  GameTimeFrame )
		Hide( 'toggle', MinimapToggleButton )
		Hide( 'worldmap', MiniMapWorldMapButton )
		HideZoneText()
	end
end

--- init
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function(frame, event, name)
	if event == "ADDON_LOADED" and name == addon.addonName then
		addon.__loaded = true
	end
	if addon.__loaded and IsLoggedIn() then
		KiwiMBCDB = KiwiMBCDB or CopyTable(defaults)
		cfg = KiwiMBCDB
		addon:UnregisterAllEvents()
		Minimap:HookScript('OnEnter', MinimapOnEnter)
		Minimap:HookScript('OnLeave', MinimapOnLeave)
		delayHide = cfg.delayHide or 0.5
		delayShow = cfg.delayShow or 0.5
		UpdateBlizzardVisibility()
		C_Timer_After( .05, UpdateMinimapButtons )
		C_Timer_After( 3,   UpdateMinimapButtons )
	end
end)

--config
SLASH_KIWIMBC1,SLASH_KIWIMBC2 = "/kmbc","/kiwimbc";
SlashCmdList.KIWIMBC = function(args)
	local arg1,arg2,arg3 = strsplit(" ",strlower(args),3)
	if arg1 =='delay' and tonumber(arg2) then
		cfg.delayHide = tonumber(arg2)/10
		cfg.delayShow = tonumber(arg3) and tonumber(arg3)/10 or cfg.delayHide
		delayHide = cfg.delayHide
		delayShow = cfg.delayShow
	elseif defaults.hide[arg1] ~= nil then
		cfg.hide[arg1] = not cfg.hide[arg1]
		UpdateBlizzardVisibility()
	else
		print("KiwiMBC (Minimap Buttons Control) commands:")
		print("  /kiwimbc")
		print("  /kmbc")
		print("  /kmbc zone     -zone text visibility")
		print("  /kmbc clock    -clock visibility")
		print("  /kmbc time     -time visibility")
		print("  /kmbc zoom     -zoom buttons visibility")
		print("  /kmbc toggle   -minimap toggle button visibility")
		print("  /kmbc worldmap -worldmap button visibility")
		print("  /kmbc delay [1-10] [1-10] - [hide] [show] delay in tenths of a second")
		print("  /kmbc remember - toggle remember collected buttons between sessions")
	end
	print("KiwiMBC setup:")
	for name in pairs(defaults.hide) do
		print( string.format("  %s visible: %s",name, tostring(not cfg.hide[name])) )
	end
	print( string.format('  buttons show delay: %.1f tenths of a second', (cfg.delayShow or 0.5)*10 ) )
	print( string.format('  buttons hide delay: %.1f tenths of a second', (cfg.delayHide or 0.5)*10 ) )
end

