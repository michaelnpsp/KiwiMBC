-- KiwiMBC (C) 2019 MiCHaEL

local addon = CreateFrame('Frame')
addon.addonName = ...

--- upvalues
local pairs = pairs
local ipairs = ipairs
local unpack = unpack
local strfind = strfind
local GetTime = GetTime
local C_Timer_After = C_Timer.After

-- addon version
local versionToc = GetAddOnMetadata("KiwiMBC","Version")
versionToc = versionToc=='@project-version@' and 'Dev' or 'v'..versionToc

--- savedvariables defaults
local defaults = { -- default settings
	hide         = { clock = false, zoom = false, time = false, zone = false, toggle = false, worldmap = false },
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

-- button human description translations
local buttonTranslations = {
	MiniMapTracking = 'Tracking',
	GarrisonLandingPageMinimapButton = 'Order Hall',
}

-- savedvariables
local cfg, cfg_global

-- KiwiMBC minimap button
local kiwiButton

-- all collected buttons
local collectedButtons = {}
local collectTime = 0

-- standard minimap buttons
local minimapButtons = {}
local insideMinimap = false
local dragStart = false
local timerActive = false
local delayHide = .5
local dealyShow = .5

-- boxed minimap buttons
local boxedButtons = {}
local boxedVisible = false

-- accept/cancel dialog
StaticPopupDialogs["KIWIBMC_DIALOG"] = { timeout = 0, whileDead = 1, hideOnEscape = 1, button1 = ACCEPT, button2 = CANCEL }

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

local function SkinButton(button, reset)
	for _,tex in ipairs({button:GetRegions()}) do
		if tex:IsObjectType('Texture') and tex:GetDrawLayer()=='OVERLAY' then
			local rgb = (cfg.blackBorders and not reset) and 0.15 or 1
			tex:SetVertexColor(rgb,rgb,rgb,1)
			return
		end
	end
end

local function SkinButtons()
	for _, button in pairs(collectedButtons) do
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

---------------------------------------------------------------------------------------------------------
-- boxed buttons management
---------------------------------------------------------------------------------------------------------

local function Boxed_BoxButton(button)
	if button then
		local data = {}
		for i=1,button:GetNumPoints() do
			data[i] = { button:GetPoint(i) }
		end
		button.__kmbcSavedPosition = data
		local name = button:GetName()
		boxedButtons[name]   = button
		minimapButtons[name] = nil
		local boxed = cfg.bxButtons
		if not boxed[name] then
			boxed[name] = true
			table.insert( boxed, name )
		end
		button:SetShown(boxedVisible)
	end
end

local function Boxed_UnboxButton(button)
	if button then
		button:ClearAllPoints()
		for _,points in ipairs(button.__kmbcSavedPosition) do
			button:SetPoint( unpack(points) )
		end
		button.__kmbcSavedPosition = nil
		local name = button:GetName()
		boxedButtons[name] = nil
		minimapButtons[name] = button
		local boxed = cfg.bxButtons
		boxed[name] = nil
		RemoveTableValue( boxed, name )
		boxedVisible = next(boxedButtons) and boxedVisible
	end
end

local function Boxed_LayoutButtons()
	local max = (cfg.buttonsPerColumn or 50 ) -1
	local count = max
	local firstButton = kiwiButton
	local prevButton = kiwiButton
	for i,name in ipairs(cfg.bxButtons) do
		local button = boxedButtons[name]
		if button then
			button:ClearAllPoints()
			if count>0 then
				button:SetPoint('TOP',prevButton,'BOTTOM',0,4)
				count = count - 1
			else
				button:SetPoint('RIGHT', firstButton, 'LEFT', 4, 0)
				count, firstButton = max, button
			end
			prevButton = button
		end
	end
end

local function Boxed_ToggleVisibility()
	boxedVisible = next(boxedButtons) and not boxedVisible
	for _,name in ipairs(cfg.bxButtons) do
		local button = boxedButtons[name]
		if button then
			button:SetShown(boxedVisible)
		end
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
			local alwaysVisible = cfg.avButtons
			for buttonName, button in pairs(minimapButtons) do
				if insideMinimap or not boxedVisible or button~=kiwiButton then
					button:SetShown( (insideMinimap or alwaysVisible[buttonName]) and not button.__kmbcHide)
				end
			end
		else
			UpdateButtonsVisibilityDelayed()
		end
	end

	function UpdateButtonsVisibilityDelayed()
		if not timerActive then
			timerActive = GetTime()
			C_Timer_After(insideMinimap and delayShow or delayHide,UpdateButtonsVisibility)
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

---------------------------------------------------------------------------------------------------------
-- collect buttons from minimap
---------------------------------------------------------------------------------------------------------

local function CollectMinimapButton(name, button)
	button = button or _G[name]
	if button then
		collectedButtons[name] = button
		if not button.__kmbcHooked then
			button:HookScript('OnEnter', MinimapOnEnter)
			button:HookScript('OnLeave', MinimapOnLeave)
			button:HookScript("OnDragStart", MinimapDragStart)
			button:HookScript("OnDragStop", MinimapDragStop)
			button.__kmbcHooked = true
		end
		SkinButton(button)
		if cfg.bxButtons[name] then
			Boxed_BoxButton(button)
		else
			minimapButtons[name] = button
		end
		collectTime = GetTime()
		return true
	end
end

local function UncollectMinimapButton(name)
	local button = collectedButtons[name]
	if button then
		if boxedButtons[name] then
			Boxed_UnboxButton(button)
		else
			minimapButtons[name] = nil
		end
		SkinButton(button, true)
		collectedButtons[name] = nil
		collectTime = GetTime()
		button:Show()
		return true
	end
end

local CollectMinimapButtons
do
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
	local function CollectFrameButtons(frame)
		for _, button in ipairs({frame:GetChildren()}) do
			local name = button:GetName()
			if name and	not collectedButtons[name] and IsValidButton(name, button) then
				CollectMinimapButton(name, button)
			end
		end
	end
	local function CollectManualButtons(buttons)
		for name in pairs(buttons) do
			CollectMinimapButton(name)
		end
	end
	function CollectMinimapButtons()
		CollectFrameButtons(Minimap)
		CollectFrameButtons(MinimapBackdrop)
		CollectManualButtons(cfg_global.maButtons)
		UpdateButtonsVisibility()
	end
end


---------------------------------------------------------------------------------------------------------
-- blizzard buttons visibility
---------------------------------------------------------------------------------------------------------

local UpdateBlizzardVisibility
do
	local function Hide( name, frame )
		if frame then
			local hidden = cfg.hide[name] or nil
			frame:SetShown(not hidden)
			frame.__kmbcHide = hidden
		end
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
		addon:UnregisterAllEvents()
		addon.minimapLib:Register("KiwiMBC", addon.minimapLDB, cfg.minimapIcon)
		kiwiButton = addon.minimapLib:GetMinimapButton('KiwiMBC')
		Minimap:HookScript('OnEnter', MinimapOnEnter)
		Minimap:HookScript('OnLeave', MinimapOnLeave)
		delayHide = cfg.delayHide or 0.5
		delayShow = cfg.delayShow or 0.5
		UpdateBlizzardVisibility()
		C_Timer_After( .05, CollectMinimapButtons )
		C_Timer_After( 3, function()
			CollectMinimapButtons()
			Boxed_LayoutButtons()
		end)
	end
end)

---------------------------------------------------------------------------------------------------------
-- minimap&ldb button
---------------------------------------------------------------------------------------------------------

addon.minimapLib = LibStub("LibDBIcon-1.0")
addon.minimapLDB = LibStub("LibDataBroker-1.1", true):NewDataObject("KiwiMBC", {
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
		Boxed_UnboxButton( boxedButtons[buttonName] )
	else
		Boxed_BoxButton( minimapButtons[buttonName] )
	end
	 Boxed_LayoutButtons()
end

local function Cfg_AlwaysToggle(buttonName)
	buttonName = type(buttonName)=='table' and buttonName.value or buttonName
	cfg.avButtons[buttonName] = not cfg.avButtons[buttonName] or nil
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

local function Cfg_DarkToggle()
	cfg.blackBorders = not cfg.blackBorders
	SkinButtons()
end

local function Cfg_DelaySet(key, value)
	value = tonumber(value)
	cfg[key] = value and value/10 or cfg[key]
	delayHide, delayShow = cfg.delayHide, cfg.delayShow
end

local function Cfg_ButtonsPerColumnSet(value)
	cfg.buttonsPerColumn = type(value) == 'table' and value.value or value
	Boxed_LayoutButtons()
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
	elseif arg1~='' then
		Cfg_BlizToggle(arg1)
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
		print("  /kmbc delay [1-50] [1-50] - [hide] [show] delay in tenths of a second")
		print("  /kmbc collect button_name  - toggle button_name collect status")
		print("  /kmbc ignore button_name  - toggle button_name ignore status")
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
	-- boxed buttons
	local function BoxedGet(info)
		return cfg.bxButtons[info.value]
	end
	-- always visible buttons
	local function AlwaysGet(info)
		return cfg.avButtons[info.value]
	end
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
			local sortedButtons = {}
			for name in pairs(collectedButtons) do
				table.insert(sortedButtons, name)
			end
			table.sort(sortedButtons)
			wipe(menuAlways); wipe(menuBoxed)
 			for _,buttonName in ipairs(sortedButtons) do
				local name = GetButtonHumanName(buttonName)
				table.insert(menuAlways, {text=name, value=buttonName, isNotRadio=true, keepShownOnClick=1, checked=AlwaysGet, func=Cfg_AlwaysToggle} )
				if not nonBoxedButtons[buttonName] then
					table.insert(menuBoxed, {text=name, value=buttonName, isNotRadio=true, keepShownOnClick=1, checked=BoxedGet, func=Cfg_BoxedToggle} )
				end
			end
			updateTime = collectTime+0.01
		end
	end
	-- main menu
	local menuTable = {
		{ text = 'KiwiMBC', notCheckable= true, isTitle = true },
		{ text = 'Buttons Show Delay', notCheckable= true, hasArrow = true, menuList = CreateRange('delayShow', DelayRange) },
		{ text = 'Buttons Hide Delay', notCheckable= true, hasArrow = true, menuList = CreateRange('delayHide', DelayRange) },
		{ text = 'Buttons Per Column',  notCheckable= true, hasArrow = true, menuList = CreateRange('buttonsPerColumn', ColRange) },
		{ text = 'Always Visible Buttons',   notCheckable= true, hasArrow = true, menuList = menuAlways },
		{ text = 'Boxed Buttons',    notCheckable= true, hasArrow = true, menuList = menuBoxed },
		{ text = 'Blizzard Buttons', notCheckable= true, hasArrow = true, menuList = {
			{ text='Zone',      value='zone',     isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Clock',     value='clock',    isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Zoom',      value='zoom',     isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Time',      value='time',     isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='Toggle',    value='toggle',   isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=Cfg_BlizToggle },
			{ text='World Map', value='worldmap', isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=Cfg_BlizToggle },
		} },
		{ text = 'Draw Dark Borders', isNotRadio=true, keepShownOnClick = 1, checked = function() return cfg.blackBorders end, func = Cfg_DarkToggle },
		{ text = 'Use Character Profile', isNotRadio=true, checked = function() return KiwiMBCDBC~=nil end, func = Cfg_ProfileToggle },
		{ text = 'Close Menu', notCheckable = 1, func = function() menuFrame:Hide() end },
	}
	function addon:ShowPopupMenu()
		UpdateSubMenus()
		local x, y = GetCursorPosition()
		local uiScale = UIParent:GetEffectiveScale()
		UIDropDownMenu_SetAnchor(menuFrame, x/uiScale, y/uiScale, 'TOPRIGHT', UIParent, 'BOTTOMLEFT')
		EasyMenu(menuTable, menuFrame, nil, 0 , 0, 'MENU', 1)
	end
end
