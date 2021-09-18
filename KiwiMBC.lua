-- KiwiMBC (C) 2019 MiCHaEL

local addon = CreateFrame('Frame')
addon.addonName = ...

local versionToc = GetAddOnMetadata(addon.addonName,"Version")
versionToc = versionToc=='@project-version@' and 'Dev' or 'v'..versionToc

--- libraries

local minimapLDB
local minimapLib = LibStub("LibDBIcon-1.0")

--- upvalues
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local strfind = strfind
local GetTime = GetTime
local C_Timer_After = C_Timer.After

--- savedvariables defaults
local defaults = { -- default settings
	hide         = { clock = false, zoom = false, time = false, zone = false, toggle = false, worldmap = false, garrison = false }, -- blizzard buttons
	bxButtons    = {}, -- boxed buttons
	avButtons    = {}, -- always visible buttons
	minimapIcon  = {}, -- used by LibDBIcon-1.0
}

local gdefaults = { -- global defaults (data shared by all characters)
	maButtons = {}, -- manual collected buttons
	baButtons = {}, -- banned buttons, never collect
}

--- frames to ignore in minimap button collection
local Ignore = {
	"Questie", -- needed to ignore trillions of questie icons (QuestieFrameNNN)
	"SexyMap",
	"KiwiMBCBoxFiller",
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
	MiniMapVoiceChatFrame = true,
	MiniMapWorldMapButton = true,
	MiniMapLFGFrame = true,
	MiniMapMailFrame = true,
	MiniMapBattlefieldFrame = true,
	GameTimeFrame = true,
	FeedbackUIButton = true,
	MiniMapTrackingFrame = true,
	QuestieFrameGroup = true,
}

-- valid button frames
local Valid = {
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	GarrisonLandingPageMinimapButton = true,
	LibDBIcon10_Questie = true,
}

-- buttons that cannot be boxed
local nonBoxedButtons = {
	LibDBIcon10_KiwiMBC = true,
	MiniMapTracking = true,
	MiniMapTrackingButton =  true,
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	GarrisonLandingPageMinimapButton = true,
}

-- buttons cannot be skined
local nonSkinButtons = {
	MiniMapTracking = true,
	MiniMapTrackingButton =  true,
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	GarrisonLandingPageMinimapButton = true,
}

-- blizzard zones that can be disabled
local BlizzardZones = {
	zone  = 'MinimapZoneTextButton',
	clock = 'TimeManagerClockButton',
	zoom  = 'MinimapZoomIn',
	time  = 'GameTimeFrame',
	toggle = 'MinimapToggleButton',
	worldmap = 'MiniMapWorldMapButton',
	garrison = 'GarrisonLandingPageMinimapButton',
}

-- blizzard zones reversed that can be disabled
local BlizzardZonesReversed = {
	TimeManagerClockButton = 'clock',
	MinimapZoomIn = 'zoom',
	MinimapZoomOut = 'zoom',
	GameTimeFrame = 'time',
	MinimapToggleButton = 'toggle',
	MiniMapWorldMapButton = 'worldmap',
	GarrisonLandingPageMinimapButton = 'garrison',
}

-- blizzard buttons
local BlizzardButtonsOrder = {
	MiniMapTracking = 1,
	MiniMapTrackingButton = 2,
	MinimapZoomIn = 3,
	MinimapZoomOut = 4,
	MinimapToggleButton = 5,
	MiniMapWorldMapButton = 6,
	TimeManagerClockButton = 7,
	GarrisonLandingPageMinimapButton = 8,
}

-- button human description translations
local buttonTranslations = {
	MiniMapTracking = 'Tracking',
	GarrisonLandingPageMinimapButton = 'Garrison Report',
	Lib_GPI_Minimap_LFGBulletinBoard = 'LFG Bulletin Board',
}

-- layout stuff
local LayoutPoints = {
	BOTTOM = { 'TOP',    'BOTTOM', -1 },
	TOP    = { 'BOTTOM', 'TOP',     1 },
	LEFT   = { 'RIGHT',  'LEFT',   -1 },
	RIGHT  = { 'LEFT',   'RIGHT',   1 },
}

-- savedvariables
local cfg, cfg_global

-- KiwiMBC minimap button
local kiwiButton

-- all collected buttons
local collectedButtons = {}
local collectTime = 0

-- buttons attached to the minimap (non-boxed)
local minimapButtons = {}
local insideMinimap = false
local dragStart = false
local timerActive = false
local delayHide = .5
local dealyShow = .5

-- boxed minimap buttons
local boxedButtons = {}
local boxedVisible = false

-- buttons helper tables
local buttonsSorted = {}
local buttonsSortKeys = {}
local buttonsHumanNames = {}

-- accept/cancel dialog
StaticPopupDialogs["KIWIBMC_DIALOG"] = { timeout = 0, whileDead = 1, hideOnEscape = 1, button1 = ACCEPT, button2 = CANCEL }

-- box filler buttons
local fillButtons = setmetatable( {}, {
	__index = function(t,i)
		local button = CreateFrame("Button", "LibDBIcon10_KiwiMBCBoxFiller"..i, Minimap)
		button:SetFrameStrata("MEDIUM")
		button:SetSize(31, 31)
		local overlay = button:CreateTexture(nil, "OVERLAY")
		overlay:SetSize(53, 53)
		overlay:SetTexture(136430) --'Interface\\Minimap\\MiniMap-TrackingBorder'
		overlay:SetPoint("TOPLEFT")
		local c = cfg.blackBorders and 0.15 or 1
		overlay:SetVertexColor(c,c,c,1)
		local background = button:CreateTexture(nil, "BACKGROUND")
		background:SetSize(20, 20)
		background:SetTexture(136467) --'Interface\\Minimap\\UI-Minimap-Background'
		background:SetVertexColor(1,1,1,0.55)
		background:SetPoint("TOPLEFT", 7, -5)
		t[i] = button
		return button
	end }
)

---------------------------------------------------------------------------------------------------------
--- utils
---------------------------------------------------------------------------------------------------------

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

local function RemoveTableValue(t,v)
	for i=#t,1,-1 do
		if t[i]==v then
			table.remove(t,i)
			return true
		end
	end
end

local function RemoveTableDoubleValue(t,v)
	t[v] = nil
	RemoveTableValue(t,v)
end

local function InsertTableDoubleValue(t,k,v)
	t[k] = v
	table.insert(t,k)
end

local function SkinButton(button, buttonName, reset)
	if buttonName and nonSkinButtons[buttonName] then return end
	for _,tex in ipairs({button:GetRegions()}) do
		if tex:IsObjectType('Texture') and tex:GetDrawLayer()=='OVERLAY' then
			local rgb = (cfg.blackBorders and not reset) and 0.15 or 1
			tex:SetVertexColor(rgb,rgb,rgb,1)
			return
		end
	end
end

local function SkinButtons()
	for name,button in pairs(collectedButtons) do
		SkinButton(button,name)
	end
	for _, button in ipairs(fillButtons) do
		SkinButton(button)
	end
end

local function GetButtonHumanName(buttonName)
	local name = buttonTranslations[buttonName]
	if not name then
		name = string.match(buttonName,'^LibDBIcon10_(.+)$') or gsub(buttonName,'MinimapButton','')
		name = gsub( name, '[_-]', ' ' )
		name = gsub( name, 'Broker', '' )
		name = gsub( name, 'Minimap', '' )
	end
	return name
end

local function ConfirmDialog(message, funcAccept, funcCancel)
	local t = StaticPopupDialogs["KIWIBMC_DIALOG"]
	t.text = message
	t.OnCancel = funcCancel
	t.OnAccept = funcAccept
	StaticPopup_Show ("KIWIBMC_DIALOG")
end

local function PrintNameList(list, title)
	if next(list) then
		print(title)
		local t = {}
		for name in pairs(list) do
			table.insert(t, name)
		end
		print( table.concat(t,', ') )
		print( "\n")
	end
end

local function ValidateButtonName(buttonName)
	buttonName = strtrim(buttonName or '','"')
	if strlen(buttonName)>3 then
		local button = _G['LibDBIcon10_'..buttonName] or _G[buttonName]
		if button and type(button)=='table' and button.SetFrameLevel then
			return button:GetName()
		end
	end
	print( string.format( 'KiwiMBC Error: Minimap button "%s" not found !', buttonName) )
end

---------------------------------------------------------------------------------------------------------
-- savedvariables database
---------------------------------------------------------------------------------------------------------

local function SetupDatabase()
	-- current db setup
	KiwiMBCDB = CopyTable(defaults,KiwiMBCDB)
	if KiwiMBCDBC then -- using character database
		cfg = CopyTable(defaults, KiwiMBCDBC)
	else -- using global database
		cfg = KiwiMBCDB
	end
	-- global db setup
	KiwiMBCDB.global = CopyTable(gdefaults,KiwiMBCDB.global)
	cfg_global = KiwiMBCDB.global
end

local function LoadDatabase()
	delayHide = cfg.delayHide or 0.5
	delayShow = cfg.delayShow or 0.5
end


---------------------------------------------------------------------------------------------------------
-- blizzard buttons visibility
---------------------------------------------------------------------------------------------------------

local UpdateBlizzardVisibility, UpdateZoneVisibility
do
	local function HideZoneText()
		MinimapZoneTextButton:SetShown(not cfg.hide.zone)
		MinimapBorderTop:SetAlpha( cfg.hide.zone and 0 or 1)
	end
	function UpdateZoneVisibility( name, frame )
		if frame then
			local hidden = frame.__kmbcDisabled or cfg.hide[name] or nil
			frame:SetShown(not hidden)
			frame.__kmbcHide = hidden
		end
	end
	function UpdateBlizzardVisibility()
		UpdateZoneVisibility( 'clock', TimeManagerClockButton )
		UpdateZoneVisibility( 'zoom',  MinimapZoomOut )
		UpdateZoneVisibility( 'zoom',  MinimapZoomIn )
		UpdateZoneVisibility( 'time',  GameTimeFrame )
		UpdateZoneVisibility( 'toggle', MinimapToggleButton )
		UpdateZoneVisibility( 'worldmap', MiniMapWorldMapButton )
		UpdateZoneVisibility( 'garrison', GarrisonLandingPageMinimapButton )
		HideZoneText()
	end
end

---------------------------------------------------------------------------------------------------------
-- setup events
---------------------------------------------------------------------------------------------------------

local function SetupEvents()
	addon:UnregisterAllEvents()
	if GarrisonLandingPageMinimapButton then
		addon:RegisterEvent('GARRISON_HIDE_LANDING_PAGE')
		addon:RegisterEvent('GARRISON_SHOW_LANDING_PAGE')
		addon:SetScript( 'OnEvent', function(frame, event)
			GarrisonLandingPageMinimapButton.__kmbcDisabled = (event=='GARRISON_HIDE_LANDING_PAGE')
			UpdateZoneVisibility( 'garrison',GarrisonLandingPageMinimapButton)
		end)
	end
end

---------------------------------------------------------------------------------------------------------
-- boxed buttons management
---------------------------------------------------------------------------------------------------------

local function Boxed_BoxButton(button, name)
	if button and not nonBoxedButtons[name] then
		local data = {}
		for i=1,button:GetNumPoints() do
			data[i] = { button:GetPoint(i) }
		end
		button.__kmbcSavedPosition = data
		boxedButtons[name] = button
		minimapButtons[name] = nil
		button.__kbmcSavedOnDragStart = button:GetScript('OnDragStart')
		button.__kbmcSavedOnDragStop  = button:GetScript('OnDragStop')
		button:SetScript('OnDragStart',nil)
		button:SetScript('OnDragStop',nil)
		button:SetShown(boxedVisible)
	end
end

local function Boxed_UnboxButton(button, name)
	if button and button.__kmbcSavedPosition then
		button:ClearAllPoints()
		for _,points in ipairs(button.__kmbcSavedPosition) do
			button:SetPoint( unpack(points) )
		end
		button.__kmbcSavedPosition = nil
		boxedButtons[name] = nil
		minimapButtons[name] = button
		boxedVisible = next(boxedButtons) and boxedVisible
		button:SetScript('OnDragStart',button.__kbmcSavedOnDragStart)
		button:SetScript('OnDragStop', button.__kbmcSavedOnDragStop)
		button.__kbmcSavedOnDragStart = nil
		button.__kbmcSavedOnDragStop  = nil
	end
end

local function Boxed_IterateButtons()
	local f, i, c, name = true, 0, 1
	local buttons = cfg.allButtonsBoxed and buttonsSorted or cfg.bxButtons
	return function (k, v)
		if f then -- return real minimap buttons
			repeat
				i = i + 1; name = buttons[i]
				if name then
					button = boxedButtons[name]
					if button then c = c + 1; return button; end
				end
			until name==nil
			local bpc = cfg.buttonsPerColumn or 50
			f, i, c = false, 0, c>bpc and math.ceil(c/bpc)*bpc-c or 0
		end
		if i<c then -- return fake buttons to fill holes not ocuppied by real minimap buttons
			i = i + 1
			local button = fillButtons[i]
			button:SetShown(boxedVisible)
			return button
		else -- hide unused fake buttons
			for j=i+1,#fillButtons do
				fillButtons[j]:Hide()
			end
		end
	end
end

local function Boxed_LayoutButtons()
	local boxedVisible = next(boxedButtons) and boxedVisible
	local grow = cfg.buttonsGrowth or 'BOTTOMLEFT'
	local spacing = (cfg.buttonsSpacing or 0) - 4
	local max = (cfg.buttonsPerColumn or 50 ) -1
	local count = max
	local firstButton = kiwiButton
	local prevButton = kiwiButton
	local vp1, vp2, vmul = unpack( LayoutPoints[ strmatch(grow, 'TOP')  or 'BOTTOM' ] )
	local hp1, hp2, hmul = unpack( LayoutPoints[ strmatch(grow, 'LEFT') or 'RIGHT'  ] )
	for button in Boxed_IterateButtons() do
		button:ClearAllPoints()
		if count>0 then
			button:SetPoint( vp1, prevButton, vp2, 0, spacing * vmul )
			count = count - 1
		else
			button:SetPoint( hp1, firstButton, hp2, spacing * hmul, 0)
			count, firstButton = max, button
		end
		button:SetShown(boxedVisible)
		prevButton = button
	end
end

local function Boxed_ToggleVisibility()
	boxedVisible = next(boxedButtons) and not boxedVisible
	for button in Boxed_IterateButtons() do
		button:SetShown(boxedVisible)
	end
end

---------------------------------------------------------------------------------------------------------
--- minimap buttons visibility control
---------------------------------------------------------------------------------------------------------

local UpdateButtonsVisibility, UpdateButtonsVisibilityDelayed
do
	function UpdateButtonsVisibility()
		timerActive = false
		if not dragStart and not IsMouseButtonDown() then
			if boxedVisible and cfg.autoHideBox and not insideMinimap then
				Boxed_ToggleVisibility()
			end
			local avButtons = cfg.avButtons
			local allVisible = insideMinimap or cfg.allButtonsVisible
			for buttonName, button in pairs(minimapButtons) do
				button:SetShown( (allVisible or avButtons[buttonName]) and not button.__kmbcHide )
			end
			kiwiButton:SetShown( not cfg.hideKiwiButton and (allVisible or avButtons[kiwiButton:GetName()] or boxedVisible or cfg.detachedMinimapButton) )
		else
			UpdateButtonsVisibilityDelayed()
		end
	end
	function UpdateButtonsVisibilityDelayed()
		if not timerActive then
			timerActive = GetTime()
			C_Timer_After(insideMinimap and delayShow or delayHide, UpdateButtonsVisibility)
		end
	end
end

---------------------------------------------------------------------------------------------------------
-- event hooks
---------------------------------------------------------------------------------------------------------

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

local function MinimapDragStart(button)
	dragStart = true
end

local function MinimapDragStop(button)
	dragStart = false
	UpdateButtonsVisibilityDelayed()
	if boxedButtons[button:GetName()] then
		Boxed_LayoutButtons()
	end
end

local function MinimapButtonOnShow(button)
	if not boxedVisible and boxedButtons[button:GetName()] then
		button:Hide()
	end
end

---------------------------------------------------------------------------------------------------------
-- collect buttons from minimap
---------------------------------------------------------------------------------------------------------

local function CollectMinimapButton(name, button)
	button = button or _G[name]
	if button then
		local humanName = GetButtonHumanName(name)
		buttonsHumanNames[name] = humanName
		buttonsSortKeys[name] = string.format('%02d%s', BlizzardButtonsOrder[name] or 0, humanName)
		buttonsSorted[#buttonsSorted+1] = name
		collectedButtons[name] = button
		if not button.__kmbcHooked then
			button:HookScript('OnShow', MinimapButtonOnShow)
			button:HookScript('OnEnter', MinimapOnEnter)
			button:HookScript('OnLeave', MinimapOnLeave)
			button:HookScript("OnDragStart", MinimapDragStart)
			button:HookScript("OnDragStop", MinimapDragStop)
			button.__kmbcHooked = true
		end
		SkinButton(button,name)
		if button~=kiwiButton then
			if nonBoxedButtons[name]==nil and (cfg.allButtonsBoxed or cfg.bxButtons[name]) then
				Boxed_BoxButton(button, name)
			else
				minimapButtons[name] = button
			end
		end
		collectTime = GetTime()
	end
end

local function UncollectMinimapButton(name)
	local button = collectedButtons[name]
	if button then
		if boxedButtons[name] then
			Boxed_UnboxButton(button, name)
		else
			minimapButtons[name] = nil
		end
		SkinButton(button, name, true)
		RemoveTableValue(buttonsSorted,name)
		collectedButtons[name] = nil
		collectTime = GetTime()
		button:Show()
		return true
	end
end

local function IsValidButton(name, button)
	if Ignore[name] or cfg_global.baButtons[name] then -- blacklisted buttons
		return false
	end
	if Valid[name] or cfg_global.maButtons[name] then  -- whitelisted buttons
		return true
	end
	if button:IsShown() and (button:HasScript('OnClick') or button:HasScript('OnMouseDown')) then -- looks like a frame button ?
		for _,pattern in ipairs(Ignore) do
			if strfind(name, pattern) then -- patterns to ignore (example: Questie creates a lot of icons/buttons parented to the minimap)
				return false
			end
		end
		return true
	end
end

local function IsCollectableButton(name, button)
	button = button or _G[name]
	return name and	not collectedButtons[name] and IsValidButton(name, button)
end

local function SortCollectedButtons()
	table.sort(buttonsSorted, function(a,b) return buttonsSortKeys[a]<buttonsSortKeys[b] end )
end

local function CollectIconCreatedEvent(_, button)
		local name = button:GetName()
		if IsCollectableButton(name, button) then
		C_Timer_After(0, function()
			CollectMinimapButton(name, button)
			SortCollectedButtons()
			UpdateButtonsVisibility()
			Boxed_LayoutButtons()
		end)
	end
end

local function CollectFrameButtons(frame)
	for _, button in ipairs({frame:GetChildren()}) do
		local name = button:GetName()
		if IsCollectableButton(name, button) then
			CollectMinimapButton(name, button)
		end
	end
end

local function CollectManualButtons(buttons)
	for name in pairs(buttons) do
		CollectMinimapButton(name)
	end
end

local function CollectMinimapButtons()
	CollectFrameButtons(Minimap)
	CollectFrameButtons(MinimapBackdrop)
	CollectManualButtons(cfg_global.maButtons)
	SortCollectedButtons()
	UpdateButtonsVisibility()
end

---------------------------------------------------------------------------------------------------------
--- minimap button position setup
---------------------------------------------------------------------------------------------------------

local CreateMinimapButton, DetachMinimapButton, ReattachMinimapButton, SaveMinimapButtonPosition
do
	local function OnUpdate()
		local mx, my = Minimap:GetCenter()
		local px, py = GetCursorPosition()
		local scale  = Minimap:GetEffectiveScale()
		kiwiButton:SetPoint('CENTER', Minimap, 'CENTER', px/scale - mx, py/scale - my)
	end

	local function OnDragStart()
		if not cfg.lockedMinimapButton then
			kiwiButton:SetScript( 'OnUpdate', OnUpdate )
		end
	end

	local function OnDragStop()
		if not cfg.lockedMinimapButton then
			kiwiButton:SetScript('OnUpdate',nil)
			SaveMinimapButtonPosition()
		end
	end

	function SaveMinimapButtonPosition()
		local mx, my = Minimap:GetCenter()
		local bx, by = kiwiButton:GetCenter()
		cfg.minimapIcon.detachedPosX = bx-mx
		cfg.minimapIcon.detachedPosY = by-my
	end

	function DetachMinimapButton()
		minimapLib:Lock('KiwiMBC')
		kiwiButton:SetScript("OnDragStart", OnDragStart)
		kiwiButton:SetScript("OnDragStop", OnDragStop)
		kiwiButton:ClearAllPoints()
		kiwiButton:SetPoint('CENTER', Minimap, 'CENTER', cfg.minimapIcon.detachedPosX , cfg.minimapIcon.detachedPosY )
	end

	function ReattachMinimapButton()
		cfg.lockedMinimapButton = nil
		cfg.minimapIcon.detachedPosX = nil
		cfg.minimapIcon.detachedPosY = nil
		minimapLib:Unlock('KiwiMBC')
		minimapLib:Hide('KiwiMBC')
		minimapLib:Show('KiwiMBC')
	end

	function CreateMinimapButton()
		Minimap:HookScript('OnEnter', MinimapOnEnter)
		Minimap:HookScript('OnLeave', MinimapOnLeave)
		minimapLib:Register("KiwiMBC", minimapLDB, cfg.minimapIcon)
		kiwiButton = minimapLib:GetMinimapButton('KiwiMBC')
		if cfg.detachedMinimapButton then
			DetachMinimapButton()
		end
	end

end

---------------------------------------------------------------------------------------------------------
--- init
---------------------------------------------------------------------------------------------------------

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function(frame, event, name)
	if event == "ADDON_LOADED" and name == addon.addonName then
		addon.__loaded = true
	end
	if addon.__loaded and IsLoggedIn() then
		SetupDatabase()
		LoadDatabase()
		SetupEvents()
		C_Timer_After( .05, function()
			CreateMinimapButton()
			UpdateBlizzardVisibility()
			CollectMinimapButtons()
			Boxed_LayoutButtons()
		end )
		C_Timer_After( 3, function()
			CollectMinimapButtons()
			Boxed_LayoutButtons()
			minimapLib.RegisterCallback('KiwiMBC', "LibDBIcon_IconCreated", CollectIconCreatedEvent)
		end)
	end
end)

---------------------------------------------------------------------------------------------------------
-- minimap&ldb button
---------------------------------------------------------------------------------------------------------

minimapLDB = LibStub("LibDataBroker-1.1", true):NewDataObject("KiwiMBC", {
	type  = "launcher",
	label = GetAddOnInfo("KiwiMBC", "Title"),
	icon = "Interface\\Addons\\KiwiMBC\\icon",
	OnClick = function(self, button)
		if button=="LeftButton" then
			Boxed_ToggleVisibility()
		elseif button=="RightButton" then
			addon:ShowPopupMenu()
		end
	end,
	OnTooltipShow = function(tooltip)
		tooltip:AddDoubleLine("KiwiMBC ",versionToc)
		tooltip:AddLine("Minimap Buttons Controller", 1, 1, 1)
		tooltip:AddLine("|cFFff4040Left Click|r to display boxed buttons\n|cFFff4040Right Click|r to open config menu", 0.2, 1, 0.2)
	end,
})

---------------------------------------------------------------------------------------------------------
-- database configuration
---------------------------------------------------------------------------------------------------------

local function Cfg_CollectToggle(buttonName)
	buttonName = type(buttonName)=='table' and buttonName.value or buttonName
	local name = ValidateButtonName(buttonName)
	if name then
		if cfg_global.maButtons[name] then
			cfg_global.maButtons[name] = nil
			UncollectMinimapButton(name)
		else
			cfg_global.maButtons[name] = true
			CollectMinimapButton(name)
		end
	end
end

local function Cfg_IgnoreToggle(buttonName)
	buttonName = type(buttonName)=='table' and buttonName.value or buttonName
	local name = buttonName or ''
	local nameAlt = 'LibDBIcon10_'..name
	if cfg_global.baButtons[name] or cfg_global.baButtons[nameAlt] then
		cfg_global.baButtons[name] = nil
		cfg_global.baButtons[nameAlt] = nil
		CollectMinimapButtons()
	else
		name = ValidateButtonName(name)
		if name then
			cfg_global.baButtons[name] = true
			UncollectMinimapButton(name)
		end
	end
end

local function Cfg_BlizToggle(zone)
	zone = type(zone)=='table' and zone.value or zone
	if zone and defaults.hide[zone]~=nil then
		cfg.hide[zone] = not cfg.hide[zone]
		UpdateBlizzardVisibility()
		UpdateButtonsVisibility()
	end
end

local function Cfg_BoxedToggle(buttonName)
	buttonName = type(buttonName)=='table' and buttonName.value or buttonName
	if cfg.bxButtons[buttonName] then
		RemoveTableDoubleValue( cfg.bxButtons, buttonName )
		Boxed_UnboxButton( boxedButtons[buttonName], buttonName )
	else
		InsertTableDoubleValue( cfg.bxButtons, buttonName, true )
		Boxed_BoxButton( minimapButtons[buttonName], buttonName )
	end
	Boxed_LayoutButtons()
end

local function Cfg_BoxedAllToggle()
	local allBoxed = not cfg.allButtonsBoxed or nil
	cfg.allButtonsBoxed = allBoxed
	wipe(cfg.bxButtons)
	for buttonName,button in pairs(collectedButtons) do
		if not allBoxed ~= not boxedButtons[buttonName] then
			if allBoxed then
				Boxed_BoxButton(button, buttonName)
			else
				Boxed_UnboxButton(button, buttonName)
			end
		end
	end
	Boxed_LayoutButtons()
	UpdateButtonsVisibility()
end

local function Cfg_AlwaysToggle(buttonName)
	buttonName = type(buttonName)=='table' and buttonName.value or buttonName
	cfg.avButtons[buttonName] = not cfg.avButtons[buttonName] or nil
	UpdateButtonsVisibility()
end

local function Cfg_AlwaysAllToggle()
	wipe(cfg.avButtons)
	cfg.allButtonsVisible = not cfg.allButtonsVisible or nil
	UpdateButtonsVisibility()
end

local function Cfg_ProfileToggle()
	if KiwiMBCDBC then -- switch to global database
		ConfirmDialog('Current character settings will be removed and the UI will be reloaded. Are you sure you want to use the global profile ?', function()
			KiwiMBCDBC = nil
			ReloadUI()
		end)
	else -- switch to character database
		ConfirmDialog('Are you sure you want to use a specific character profile ?', function()
			KiwiMBCDBC = CopyTable(KiwiMBCDB)
			ReloadUI()
		end)
	end
end

local function Cfg_DetachedToggle()
	cfg.detachedMinimapButton = not cfg.detachedMinimapButton or nil
	if cfg.detachedMinimapButton then
		SaveMinimapButtonPosition()
		DetachMinimapButton()
	else
		ReattachMinimapButton()
	end
end

local function Cfg_LockedToggle()
	cfg.lockedMinimapButton = not cfg.lockedMinimapButton or nil
end

local function Cfg_DarkToggle()
	cfg.blackBorders = not cfg.blackBorders
	SkinButtons()
end

local function Cfg_AutoHideBoxToggle()
	cfg.autoHideBox = not cfg.autoHideBox or nil
	UpdateButtonsVisibilityDelayed()
end

local function Cfg_DelaySet(key, value)
	value = tonumber(value)
	cfg[key] = value and value/10 or cfg[key]
	delayHide, delayShow = cfg.delayHide, cfg.delayShow
end

local function Cfg_ButtonsSpacingSet(value)
	cfg.buttonsSpacing = type(value) == 'table' and value.value or value
	Boxed_LayoutButtons()
end

local function Cfg_ButtonsPerColumnSet(value)
	cfg.buttonsPerColumn = type(value) == 'table' and value.value or value
	Boxed_LayoutButtons()
end

local function Cfg_ButtonsGrowthSet(info)
	cfg.buttonsGrowth = info.value
	Boxed_LayoutButtons()
end

local function Cfg_KiwiButtonToggle()
	cfg.hideKiwiButton = not cfg.hideKiwiButton or nil
	UpdateButtonsVisibility()
end

---------------------------------------------------------------------------------------------------------
-- command line
---------------------------------------------------------------------------------------------------------

SLASH_KIWIMBC1, SLASH_KIWIMBC2 = "/kmbc", "/kiwimbc";
SlashCmdList.KIWIMBC = function(args)
	local arg1, arg2, arg3 = strsplit(" ",args,3)
	arg1 = strlower(arg1 or '')
	if arg1 =='delay' then
		Cfg_DelaySet('delayHide', arg2)
		Cfg_DelaySet('delayShow', arg3)
	elseif arg1 == 'collect' then
		Cfg_CollectToggle(arg2)
	elseif arg1 == 'ignore' then
		Cfg_IgnoreToggle(arg2)
	elseif arg1 == 'detach' then
		Cfg_DetachedToggle()
	elseif arg1 == 'reset' then
		if cfg.detachedMinimapButton then
			Cfg_DetachedToggle()
		end
	elseif arg1=='button' then
		if arg2=='kiwi' then
			Cfg_KiwiButtonToggle()
		elseif arg2~='' then
			Cfg_BlizToggle(arg2)
		end
	else
		print("KiwiMBC (Minimap Buttons Control) commands:")
		print("  /kiwimbc")
		print("  /kmbc")
		print("  /kmbc button kiwi              - toggle KiwiMBC button visibility")
		print("  /kmbc button zone              - toggle blizzard zone text visibility")
		print("  /kmbc button clock             - toggle blizzard clock visibility")
		print("  /kmbc button time              - toggle blizzard time visibility")
		print("  /kmbc button zoom              - toggle blizzard zoom buttons visibility")
		print("  /kmbc button toggle            - toggle blizzard toggle button visibility")
		print("  /kmbc button worldmap          - toggle blizzard worldmap button visibility")
		print("  /kmbc delay [1-50] [1-50]      - [hide] [show] delay in tenths of a second")
		print("  /kmbc collect button_name      - toggle button_name collect status")
		print("  /kmbc ignore button_name       - toggle button_name ignore status")
		print("  /kmbc detach                   - toggle minimap button detach mode")
		print("  /kmbc reset                    - reset minimap button position")
		print("\n")
	end
	PrintNameList(collectedButtons,     "Collected minimap buttons:")
	PrintNameList(cfg_global.maButtons, "Manual collected minimap buttons:")
	PrintNameList(cfg_global.baButtons, "Ignored minimap buttons:")
end

---------------------------------------------------------------------------------------------------------
-- popup menu
---------------------------------------------------------------------------------------------------------

do
	local menuFrame = CreateFrame("Frame", "KiwiMBCDPopupMenu", UIParent, "UIDropDownMenuTemplate")
	local menuBoxed = {}
	local menuAlways = {}
	-- ranges management
	local function CreateRange(key, options)
		local menu = {}
		for _,value in ipairs(options.range) do
			table.insert( menu, { arg1 = key, text = type(options.text)=='function' and options.text(value) or options.text or value, value = value, func = options.func, checked = options.checked } )
		end
		return menu
	end
	-- blizzard buttons
	local function BlizGet(info)
		return not cfg.hide[info.value]
	end
	local function BlizHidden(info)
		return not _G[ BlizzardZones[info.value] ]
	end
	-- boxed buttons
	local function BoxedDisabled(item)
		return cfg.allButtonsBoxed
	end
	local function BoxedGet(info)
		return cfg.allButtonsBoxed or cfg.bxButtons[info.value]
	end
	-- always visible buttons
	local function AlwaysDisabled(item)
		return cfg.allButtonsVisible
	end
	local function AlwaysHidden(item)
		return cfg.hide[BlizzardZonesReversed[item.value]] or (cfg.allButtonsBoxed and nonBoxedButtons[item.value]==nil) or cfg.bxButtons[item.value]
	end
	local function AlwaysGet(info)
		return cfg.allButtonsVisible or cfg.avButtons[info.value]
	end
	-- buttons growth
	local function GrowthGet(info)
		return (cfg.buttonsGrowth or 'BOTTOMLEFT') == info.value
	end
	-- buttons spacing
	local function SpacingText(value)
		return value>=0 and '+'..tostring(value) or value
	end
	local function SpacingGet(info)
		return (cfg.buttonsSpacing or 0) == info.value
	end
	local SpacingRange = { text = SpacingText, checked = SpacingGet, func = Cfg_ButtonsSpacingSet, range = {-5,-4,-3,-2,-1,0,1,2,3,4,5,6,7,8,9,10} }
	-- buttons per column
	local function ColGet(info)
		return (cfg.buttonsPerColumn or 50) == info.value
	end
	local ColRange = { checked = ColGet, func = Cfg_ButtonsPerColumnSet, range = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,40,50} }
	-- delay menus
	local function DelayText(value)
		return string.format( "%.1f sec", value / 10 )
	end
	local function DelayGet(info)
		return math.floor( (cfg[info.arg1] or 0.5) * 10 ) == info.value
	end
	local function DelaySet(info)
		Cfg_DelaySet( info.arg1, info.value )
	end
	local DelayRange = { text = DelayText, checked = DelayGet, func = DelaySet, range = {0,1,2,3,4,5,6,7,8,9,10,15,20,25,30,35,40,45,50} }
	-- submenus
	local updateTime = -1
	local function UpdateSubMenus()
		if collectTime>updateTime then
			wipe(menuAlways); menuAlways[1] = { text='All Buttons', isNotRadio=true, checked=function() return cfg.allButtonsVisible end, func=Cfg_AlwaysAllToggle }
			wipe(menuBoxed);  menuBoxed[1]  = { text='All Buttons', isNotRadio=true, checked=function() return cfg.allButtonsBoxed   end, func=Cfg_BoxedAllToggle  }
 			for _,buttonName in ipairs(buttonsSorted) do
				local humanName = buttonsHumanNames[buttonName]
				table.insert(menuAlways, {text=humanName, value=buttonName, isNotRadio=true, keepShownOnClick=1, checked=AlwaysGet, func=Cfg_AlwaysToggle, disable=AlwaysDisabled, hidden=AlwaysHidden} )
				if not nonBoxedButtons[buttonName] then
					table.insert(menuBoxed, {text=humanName, value=buttonName, isNotRadio=true, keepShownOnClick=1, checked=BoxedGet, func=Cfg_BoxedToggle, disable=BoxedDisabled} )
				end
			end
			updateTime = collectTime+0.01
		end
	end
	-- main menu
	local menuTable = {
		{ text = 'Minimap Buttons', notCheckable= true, isTitle = true },
		{ text = 'Always Visible Buttons',   notCheckable= true, hasArrow = true, menuList = menuAlways },
		{ text = 'Buttons Show Delay', notCheckable= true, hasArrow = true, menuList = CreateRange('delayShow', DelayRange) },
		{ text = 'Buttons Hide Delay', notCheckable= true, hasArrow = true, menuList = CreateRange('delayHide', DelayRange) },
		{ text = 'Blizzard Buttons', notCheckable= true, hasArrow = true, menuList = {
			{ text='Zone',            value='zone',     isNotRadio=true, keepShownOnClick=1, hidden=BlizHidden, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Clock',           value='clock',    isNotRadio=true, keepShownOnClick=1, hidden=BlizHidden, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Zoom',            value='zoom',     isNotRadio=true, keepShownOnClick=1, hidden=BlizHidden, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Time',            value='time',     isNotRadio=true, keepShownOnClick=1, hidden=BlizHidden, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Toggle',          value='toggle',   isNotRadio=true, keepShownOnClick=1, hidden=BlizHidden, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='World Map',       value='worldmap', isNotRadio=true, keepShownOnClick=1, hidden=BlizHidden, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Garrison Report', value='garrison', isNotRadio=true, keepShownOnClick=1, hidden=BlizHidden, checked=BlizGet, func=Cfg_BlizToggle },
		} },
		{ text = 'Buttons in a Box', notCheckable= true, isTitle = true },
		{ text = 'Boxed Buttons',    notCheckable= true, hasArrow = true, menuList = menuBoxed },
		{ text = 'Buttons Grow Direction', notCheckable= true, hasArrow = true, menuList = {
			{ text='Bottom Left',  value='BOTTOMLEFT',  checked=GrowthGet, func=Cfg_ButtonsGrowthSet },
			{ text='Bottom Right', value='BOTTOMRIGHT', checked=GrowthGet, func=Cfg_ButtonsGrowthSet },
			{ text='Top Left',     value='TOPLEFT',     checked=GrowthGet, func=Cfg_ButtonsGrowthSet },
			{ text='Top Right',    value='TOPRIGHT',    checked=GrowthGet, func=Cfg_ButtonsGrowthSet },
		} },
		{ text = 'Buttons Spacing',  notCheckable= true, hasArrow = true,  menuList = CreateRange('buttonsSpacing', SpacingRange) },
		{ text = 'Buttons Per Column',  notCheckable= true, hasArrow = true, menuList = CreateRange('buttonsPerColumn', ColRange) },
		{ text = 'Auto Hide Buttons', isNotRadio=true, keepShownOnClick = 1, checked = function() return cfg.autoHideBox end, func = Cfg_AutoHideBoxToggle },
		{ text = 'Miscellaneous', notCheckable= true, isTitle = true },
		{ text = 'Detach Minimap Button', isNotRadio=true, checked = function() return cfg.detachedMinimapButton end, func = Cfg_DetachedToggle },
		{ text = 'Lock Minimap Button', isNotRadio=true, hidden = function() return not cfg.detachedMinimapButton end, checked = function() return cfg.lockedMinimapButton end, func = Cfg_LockedToggle },
		{ text = 'Draw Dark Borders', isNotRadio=true, keepShownOnClick = 1, checked = function() return cfg.blackBorders end, func = Cfg_DarkToggle },
		{ text = 'Use Character Profile', isNotRadio=true, checked = function() return KiwiMBCDBC~=nil end, func = Cfg_ProfileToggle },
		{ text = 'Close Menu', notCheckable = 1, func = function() menuFrame:Hide() end },
	}
	-- my easy menu implementation
	local function MyEasyMenu_Initialize(frame, level, menuList)
		for index, item in ipairs(menuList) do
			if item.text and (item.hidden==nil or not item.hidden(item)) then
				item.index = index
				if item.disable then item.disabled = item.disable(item) end
				UIDropDownMenu_AddButton(item, level)
			end
		end
	end
	local function MyEasyMenu(menuList, menuFrame, anchor, x, y, autoHideDelay)
		menuFrame.displayMode = 'MENU'
		UIDropDownMenu_Initialize(menuFrame, MyEasyMenu_Initialize, 'MENU', nil, menuList)
		ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay)
	end
	-- display the menu
	function addon:ShowPopupMenu()
		UpdateSubMenus()
		local x, y = GetCursorPosition()
		local uiScale = UIParent:GetEffectiveScale()
		UIDropDownMenu_SetAnchor(menuFrame, x/uiScale, y/uiScale, 'TOPRIGHT', UIParent, 'BOTTOMLEFT')
		MyEasyMenu(menuTable, menuFrame, nil, 0 , 0, 1)
	end
end
