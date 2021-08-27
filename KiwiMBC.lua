-- KiwiMBC (C) 2019 MiCHaEL

local addon = CreateFrame('Frame')
addon.addonName = ...

--- upvalues
local ipairs = ipairs
local unpack = unpack
local strfind = strfind
local GetTime = GetTime
local C_Timer_After = C_Timer.After

--- savedvariables defaults
local defaults = {
	hide = { clock = false, zoom = false, time = false, zone = false, toggle = false, worldmap = false },
	boxed = {},         -- boxed buttons
	alwaysVisible = {}, -- always visible buttons
	minimapIcon = {},
}

--- frames to ignore in minimap button collection
local Ignore = {
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
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	MiniMapMailFrame = true,
	MiniMapBattlefieldFrame = true,
	GameTimeFrame = true,
	FeedbackUIButton = true,
	MiniMapTrackingFrame = true,
	QuestieFrameGroup = true,
}

-- buttons that cannot be boxed
local nonBoxedButtons = {
	LibDBIcon10_KiwiMBC = true,
	MiniMapTracking = true,
	GarrisonLandingPageMinimapButton = true,
}

-- button human description translations
local buttonTranslations = {
	MiniMapTracking = 'Tracking',
	GarrisonLandingPageMinimapButton = 'Order Hall',
}

-- savedvariables
local cfg

-- KiwiMBC minimap button
local kiwiButton

-- all minimap button names sorted
local sortedButtons = {}

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

local function SkinButton(button)
	for _,tex in ipairs({button:GetRegions()}) do
		if tex:IsObjectType('Texture') and tex:GetDrawLayer()=='OVERLAY' then
			local rgb = cfg.blackBorders and 0.15 or 1
			tex:SetVertexColor(rgb,rgb,rgb,1)
			return
		end
	end
end

local function SkinButtons()
	for _, button in pairs(minimapButtons) do
		SkinButton(button)
	end
	for _, button in pairs(boxedButtons) do
		SkinButton(button)
	end
end

local function GetButtonHumanName(buttonName)
	local name = buttonTranslations[buttonName]
	if not name then
		name = string.match(buttonName,'^LibDBIcon10_(.+)$') or gsub(buttonName,'MinimapButton','')
		name = gsub( name, '[_-]', ' ' )
		name = gsub( name, 'Broker', '' )
	end
	return name
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
		button.__kbmcSavedPosition = data
		local name = button:GetName()
		boxedButtons[name]   = button
		minimapButtons[name] = nil
		local boxed = cfg.boxed
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
		for _,points in ipairs(button.__kbmcSavedPosition) do
			button:SetPoint( unpack(points) )
		end
		button.__kbmcSavedPosition = nil
		local name = button:GetName()
		boxedButtons[name] = nil
		minimapButtons[name] = button
		local boxed = cfg.boxed
		boxed[name] = nil
		RemoveTableValue( boxed, name )
	end
end

local function Boxed_LayoutButtons()
	local count       = cfg.buttonsPerColumn or 50
	local firstButton = cfg.boxed[1]
	local prevButton  = kiwiButton
	for i,name in ipairs(cfg.boxed) do
		local button = boxedButtons[name]
		if button then
			button:ClearAllPoints()
			if count>0 then
				button:SetPoint('TOP',prevButton,'BOTTOM',0,4)
				count = count - 1
			else
				button:SetPoint('RIGHT', firstButton, 'LEFT', 4, 0)
				count = (cfg.buttonsPerColumn or 50) - 1
				firstButton = button
			end
			prevButton = button
		end
	end
end

local function Boxed_ToggleVisibility()
	boxedVisible = not boxedVisible
	for _,name in ipairs(cfg.boxed) do
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
			local alwaysVisible = cfg.alwaysVisible
			for buttonName, button in pairs(minimapButtons) do
				if insideMinimap or not boxedVisible or button~=kiwiButton then
					button:SetShown( insideMinimap or alwaysVisible[buttonName] )
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

local CollectMinimapButtons
do
	local function AddMinimapButton(button, name)
		minimapButtons[name] = button
		button:HookScript('OnEnter', MinimapOnEnter)
		button:HookScript('OnLeave', MinimapOnLeave)
		button:HookScript("OnDragStart", MinimapDragStart)
		button:HookScript("OnDragStop", MinimapDragStop)
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
		for _, button in ipairs({frame:GetChildren()}) do
			local name = button:GetName()
			if not minimapButtons[name] and not boxedButtons[name] and button:IsShown() and (button:HasScript('OnClick') or button:HasScript('OnMouseDown')) then
				if IsValidButtonName(name) then
					if cfg.boxed[name] then
						Boxed_BoxButton(button)
					else
						AddMinimapButton(button, name)
					end
					table.insert(sortedButtons, name)
					SkinButton(button)
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

---------------------------------------------------------------------------------------------------------
-- blizzard buttons visibility
---------------------------------------------------------------------------------------------------------

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
		KiwiMBCDB = CopyTable(defaults, KiwiMBCDB )
		cfg = KiwiMBCDB
		addon:UnregisterAllEvents()
		addon.minimapLib:Register("KiwiMBC", addon.minimapLDB, cfg.minimapIcon)
		kiwiButton = addon.minimapLib:GetMinimapButton('KiwiMBC')
		Minimap:HookScript('OnEnter', MinimapOnEnter)
		Minimap:HookScript('OnLeave', MinimapOnLeave)
		delayHide = cfg.delayHide or 0.5
		delayShow = cfg.delayShow or 0.5
		UpdateBlizzardVisibility()
		C_Timer_After( .05, UpdateMinimapButtons )
		C_Timer_After( 3, function()
			UpdateMinimapButtons()
			Boxed_LayoutButtons()
		end)
	end
end)

---------------------------------------------------------------------------------------------------------
-- minimap&ldb button
---------------------------------------------------------------------------------------------------------

do
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
			tooltip:AddLine("KiwiMBC")
			tooltip:AddLine("Minimap Button Controller", 1, 1, 1)
			tooltip:AddLine("|cFFff4040Left Click|r to display boxed buttons\n|cFFff4040Right Click|r to open menu", 0.2, 1, 0.2)
		end,
	})
	addon.minimapLib = LibStub("LibDBIcon-1.0")
end

---------------------------------------------------------------------------------------------------------
-- command line
---------------------------------------------------------------------------------------------------------

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
		print("  /kmbc delay [1-50] [1-50] - [hide] [show] delay in tenths of a second")
	end
	print("KiwiMBC setup:")
	for name in pairs(defaults.hide) do
		print( string.format("  %s visible: %s",name, tostring(not cfg.hide[name])) )
	end
	print( string.format('  buttons show delay: %.1f tenths of a second', (cfg.delayShow or 0.5)*10 ) )
	print( string.format('  buttons hide delay: %.1f tenths of a second', (cfg.delayHide or 0.5)*10 ) )
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
	local function BlizSet(info)
		cfg.hide[info.value] = not cfg.hide[info.value]
		UpdateBlizzardVisibility()
	end
	-- black borders
	local function DarkGet(info)
		return cfg.blackBorders
	end
	local function DarkSet(info)
		cfg.blackBorders = not cfg.blackBorders
		SkinButtons()
	end
	-- delay menus
	local function DelayText(value)
		return string.format( "%.1f sec", value / 10 )
	end
	local function DelayGet(info)
		return math.floor( (cfg[info.arg1] or 0.5) * 10 ) == info.value
	end
	local function DelaySet(info)
		cfg[info.arg1] = info.value / 10
		delayHide = cfg.delayHide or 0.5
		delayShow = cfg.delayShow or 0.5
	end
	local DelayRange = { text = DelayText, checked = DelayGet, func = DelaySet, range = {0,1,2,3,4,5,6,7,8,9,10,15,20,25,30,35,40,45,50} }
	-- boxed buttons
	local function BoxedGet(info)
		return cfg.boxed[info.value]
	end
	local function BoxedSet(info)
		if cfg.boxed[info.value] then
			Boxed_UnboxButton( boxedButtons[info.value] )
		else
			Boxed_BoxButton( minimapButtons[info.value] )
		end
		 Boxed_LayoutButtons()
	end
	-- always visible buttons
	local function AlwaysGet(info)
		return cfg.alwaysVisible[info.value]
	end
	local function AlwaysSet(info)
		cfg.alwaysVisible[info.value] = not cfg.alwaysVisible[info.value] or nil
		UpdateButtonsVisibility()
	end
	-- buttons per column
	local function ColGet(info)
		return (cfg[info.arg1] or 50) == info.value
	end
	local function ColSet(info)
		cfg[info.arg1] = info.value
		Boxed_LayoutButtons()
	end
	local ColRange = { checked = ColGet, func = ColSet, range = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,20,30,40,50} }
	-- several submenus
	local function ButtonAddItem(buttonName)
		local name = GetButtonHumanName(buttonName)
		table.insert(menuAlways, {text=name, value=buttonName, isNotRadio=true, keepShownOnClick=1, checked=AlwaysGet, func=AlwaysSet} )
		if not nonBoxedButtons[buttonName] then
			table.insert(menuBoxed, {text=name, value=buttonName, isNotRadio=true, keepShownOnClick=1, checked=BoxedGet, func=BoxedSet} )
		end
	end
	-- main menu
	local menuTable = {
		{ text = 'KiwiMBC',          notCheckable= true, isTitle = true },
		{ text = 'Show Delay',       notCheckable= true, hasArrow = true, menuList = CreateRange('delayShow', DelayRange) },
		{ text = 'Hide Delay',       notCheckable= true, hasArrow = true, menuList = CreateRange('delayHide', DelayRange) },
		{ text = 'Blizzard Buttons', notCheckable= true, hasArrow = true, menuList = {
			{ text='Zone',      value='zone',     isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=BlizSet },
			{ text='Clock',     value='clock',    isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=BlizSet },
			{ text='Zoom',      value='zoom',     isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=BlizSet },
			{ text='Time',      value='time',     isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=BlizSet },
			{ text='Toggle',    value='toggle',   isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=BlizSet },
			{ text='World Map', value='worldmap', isNotRadio=true, keepShownOnClick=1, checked=BlizGet, func=BlizSet },
		} },
		{ text = 'Always Visible',   notCheckable= true, hasArrow = true, menuList = menuAlways },
		{ text = 'Boxed Buttons',    notCheckable= true, hasArrow = true, menuList = menuBoxed },
		{ text = 'Buttons per Column',  notCheckable= true, hasArrow = true, menuList = CreateRange('buttonsPerColumn', ColRange) },
		{ text = 'Dark Borders', isNotRadio=true, keepShownOnClick = 1, checked = DarkGet, func = DarkSet },
	}
	function addon:ShowPopupMenu()
		addon.ShowPopupMenu = function()
			local x, y = GetCursorPosition()
			local uiScale = UIParent:GetEffectiveScale()
			UIDropDownMenu_SetAnchor(menuFrame, x/uiScale,y/uiScale, 'TOPRIGHT', UIParent, 'BOTTOMLEFT')
			EasyMenu(menuTable, menuFrame, nil, 0 , 0, 'MENU', 1)
		end
		table.sort(sortedButtons)
		for _,buttonName in ipairs(sortedButtons) do
			ButtonAddItem(buttonName)
		end
		addon:ShowPopupMenu()
	end
end
