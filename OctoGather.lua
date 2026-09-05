-- Octo Gather - self-learning Herbalism map markers for Vanilla 1.12.

local ADDON = "Octo Gather"
local MAX_PINS = 100
local UPDATE_INTERVAL = 0.10
local DUPLICATE_DISTANCE = 0.004 -- 0.4 map percentage points, as used by classic Gatherer.

local frame = CreateFrame("Frame", "OctoGatherFrame")
local pins = {}
local worldPins = {}
local worldMapCheckbox = nil
local elapsedSinceUpdate = 0
local pendingNode = nil
local pendingRequirement = nil
local pendingGather = false
local lastRecordedName = nil
local lastRecordedTime = 0
local lastInteractTime = 0
local originalInteract = nil
local interactWrapper = nil

-- Zone-name lookup is intentional. OctoWoW inserts extra maps, so its numeric
-- zone indices do not match the original 1.12 indices used by old Gatherer.
local zoneScale = {
    ["Ashenvale"] = 0.15670371525706, ["Azshara"] = 0.13779501505279,
    ["Darkshore"] = 0.17799008894522, ["Darnassus"] = 0.02876626176374,
    ["Desolace"] = 0.12219839120669, ["Durotar"] = 0.14368294970080,
    ["Dustwallow Marsh"] = 0.14266384095509, ["Felwood"] = 0.15625084006464,
    ["Feralas"] = 0.18885970960818, ["Moonglade"] = 0.06292695969921,
    ["Mulgore"] = 0.13960673216274, ["Orgrimmar"] = 0.03811449638057,
    ["Silithus"] = 0.09468465888932, ["Stonetalon Mountains"] = 0.13272833611061,
    ["Tanaris"] = 0.18750104661175, ["Teldrassil"] = 0.13836131003639,
    ["The Barrens"] = 0.27539211944292, ["Barrens"] = 0.27539211944292,
    ["Thousand Needles"] = 0.11956582877920, ["Thunder Bluff"] = 0.02836291430658,
    ["Un'Goro Crater"] = 0.10054401185671, ["Winterspring"] = 0.19293573573141,

    ["Alterac Mountains"] = 0.07954563533736, ["Arathi Highlands"] = 0.10227310921644,
    ["Badlands"] = 0.07066771883566, ["Blasted Lands"] = 0.09517074521836,
    ["Burning Steppes"] = 0.08321525646393, ["Deadwind Pass"] = 0.07102298961531,
    ["Dun Morogh"] = 0.13991525534426, ["Duskwood"] = 0.07670475476181,
    ["Eastern Plaguelands"] = 0.10996723642661, ["Elwynn Forest"] = 0.09860350595046,
    ["Hillsbrad Foothills"] = 0.09090931690055, ["Ironforge"] = 0.02248317426784,
    ["Loch Modan"] = 0.07839152145224, ["Redridge Mountains"] = 0.06170112311456,
    ["Searing Gorge"] = 0.06338794005823, ["Silverpine Forest"] = 0.11931848806212,
    ["Stormwind City"] = 0.03819701270887, ["Stormwind"] = 0.03819701270887,
    ["Stranglethorn Vale"] = 0.18128603034401, ["Swamp of Sorrows"] = 0.06516347991404,
    ["The Hinterlands"] = 0.10937523495111, ["Hinterlands"] = 0.10937523495111,
    ["Tirisfal Glades"] = 0.12837403412087, ["Undercity"] = 0.02727719546939,
    ["Western Plaguelands"] = 0.12215946583965, ["Westfall"] = 0.09943208435841,
    ["Wetlands"] = 0.11745423014662,
}

-- Exact world dimensions for the outdoor and event zones added by the
-- OctoWoW/Turtle WoW 1.18.1 client. Values are width and height in world yards.
-- Zone additions that remain inside a Vanilla map (for example Tirisfal
-- Uplands) already use that parent zone's scale and do not need another entry.
local customZoneSize = {
    ["Hyjal"] = { 3206.00, 2142.00 },
    ["Scarlet Enclave"] = { 3159.00, 2108.00 },
    ["Lapidis Isle"] = { 2901.45, 1915.90 },
    ["Gillijim's Isle"] = { 3092.10, 2047.00 },
    ["Tel'Abim"] = { 3227.00, 2187.00 },
    ["Alah'Thalas"] = { 1468.00, 976.00 },
    ["Gilneas"] = { 3666.00, 2442.00 },
    ["Icepoint Rock"] = { 1608.00, 1075.00 },
    ["Blackstone Island"] = { 2472.00, 1665.00 },
    ["Thalassian Highlands"] = { 3082.00, 2061.00 },
    ["Winter Veil Vale"] = { 1432.00, 977.00 },
    ["Grim Reaches"] = { 5387.00, 3584.00 },
    ["Balor"] = { 3098.00, 2068.00 },
    ["Northwind"] = { 3241.00, 2157.00 },
    ["Moonwhisper Coast"] = { 7856.00, 5241.00 },
}

-- Names seen in older client data, on the website, or with capitalization
-- differences are normalized to the current English WorldMapArea names.
local zoneAliases = {
    ["Mount Hyjal"] = "Hyjal",
    ["Island of Lapidis"] = "Lapidis Isle",
    ["Tel'abim"] = "Tel'Abim",
    ["Alah'thalas"] = "Alah'Thalas",
}

local minimapZoomYards = {
    [0] = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 },
    [1] = { [0] = 466.6667, [1] = 400, [2] = 333.3333, [3] = 266.6667,
        [4] = 200, [5] = 133.3333 },
}

local continentScale = {
    [1] = {
        { 11016.6, 7399.9 }, { 12897.3, 8638.1 }, { 15478.8, 10368.0 },
        { 19321.8, 12992.7 }, { 25650.4, 17253.2 }, { 38787.7, 26032.1 },
    },
    [2] = {
        { 10448.3, 7072.7 }, { 12160.5, 8197.8 }, { 14703.1, 9825.0 },
        { 18568.7, 12472.2 }, { 24390.3, 15628.5 }, { 37012.2, 25130.6 },
    },
}

-- Minimum gathering requirements. Unknown/custom OctoWoW herbs learn their
-- requirement from the node tooltip and save it with the recorded location.
local herbRequirements = {
    ["Peacebloom"] = 1, ["Silverleaf"] = 1, ["Earthroot"] = 15,
    ["Mageroyal"] = 50, ["Briarthorn"] = 70, ["Stranglekelp"] = 85,
    ["Bruiseweed"] = 100, ["Wild Steelbloom"] = 115, ["Grave Moss"] = 120,
    ["Kingsblood"] = 125, ["Liferoot"] = 150, ["Fadeleaf"] = 160,
    ["Goldthorn"] = 170, ["Khadgar's Whisker"] = 185, ["Wintersbite"] = 195,
    ["Firebloom"] = 205, ["Purple Lotus"] = 210, ["Arthas' Tears"] = 220,
    ["Sungrass"] = 230, ["Blindweed"] = 235, ["Ghost Mushroom"] = 245,
    ["Gromsblood"] = 250, ["Golden Sansam"] = 260, ["Dreamfoil"] = 270,
    ["Mountain Silversage"] = 280, ["Plaguebloom"] = 285, ["Icecap"] = 290,
    ["Black Lotus"] = 300,
}

local iconRoot = "Interface\\AddOns\\OctoGather\\Icons\\"
local herbIcons = {
    ["Peacebloom"] = iconRoot .. "HerbPeacebloom",
    ["Silverleaf"] = iconRoot .. "HerbSilverleaf",
    ["Earthroot"] = iconRoot .. "HerbEarthroot",
    ["Mageroyal"] = iconRoot .. "HerbMageroyal",
    ["Briarthorn"] = iconRoot .. "HerbBriarthorn",
    ["Stranglekelp"] = iconRoot .. "HerbStranglekelp",
    ["Bruiseweed"] = iconRoot .. "HerbBruiseweed",
    ["Wild Steelbloom"] = iconRoot .. "HerbWildSteelbloom",
    ["Grave Moss"] = iconRoot .. "HerbGraveMoss",
    ["Kingsblood"] = iconRoot .. "HerbKingsblood",
    ["Liferoot"] = iconRoot .. "HerbLiferoot",
    ["Fadeleaf"] = iconRoot .. "HerbFadeleaf",
    ["Goldthorn"] = iconRoot .. "HerbGoldthorn",
    ["Khadgar's Whisker"] = iconRoot .. "HerbKhadgarsWhisker",
    ["Wintersbite"] = iconRoot .. "HerbWintersbite",
    ["Firebloom"] = iconRoot .. "HerbFirebloom",
    ["Purple Lotus"] = iconRoot .. "HerbPurpleLotus",
    ["Arthas' Tears"] = iconRoot .. "HerbArthasTears",
    ["Sungrass"] = iconRoot .. "HerbSungrass",
    ["Blindweed"] = iconRoot .. "HerbBlindweed",
    ["Ghost Mushroom"] = iconRoot .. "HerbGhostMushroom",
    ["Gromsblood"] = iconRoot .. "HerbGromsblood",
    ["Golden Sansam"] = iconRoot .. "HerbGoldenSansam",
    ["Dreamfoil"] = iconRoot .. "HerbDreamfoil",
    ["Mountain Silversage"] = iconRoot .. "HerbMountainSilversage",
    ["Plaguebloom"] = iconRoot .. "HerbPlaguebloom",
    ["Icecap"] = iconRoot .. "HerbIcecap",
    ["Black Lotus"] = iconRoot .. "HerbBlackLotus",
}

local colors = {
    red    = { 1.00, 0.12, 0.12 },
    orange = { 1.00, 0.50, 0.00 },
    yellow = { 1.00, 0.90, 0.10 },
    green  = { 0.20, 1.00, 0.20 },
    gray   = { 0.55, 0.55, 0.55 },
    unknown = { 0.70, 0.35, 1.00 },
}

local difficultyPriority = {
    unknown = 0, gray = 1, green = 2, yellow = 3, orange = 4, red = 5,
}

local function Print(message)
    DEFAULT_CHAT_FRAME:AddMessage("|cff68cc70" .. ADDON .. ":|r " .. message)
end

local function GetHerbalismSkill()
    local i
    for i = 1, GetNumSkillLines() do
        local name, isHeader, _, rank = GetSkillLineInfo(i)
        if not isHeader and name == "Herbalism" then
            return tonumber(rank) or 0
        end
    end
    return 0
end

local function Difficulty(required, skill)
    if not required then return "unknown" end
    if skill < required then return "red" end
    if skill < required + 25 then return "orange" end
    if skill < required + 50 then return "yellow" end
    if skill < required + 100 then return "green" end
    return "gray"
end

local function IsMinimapIndoors()
    local temporaryZoom = 0
    local indoors = 1
    if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
        if (GetCVar("minimapInsideZoom") + 0) >= 3 then
            Minimap:SetZoom(Minimap:GetZoom() - 1)
            temporaryZoom = 1
        else
            Minimap:SetZoom(Minimap:GetZoom() + 1)
            temporaryZoom = -1
        end
    end
    if (GetCVar("minimapInsideZoom") + 0) == Minimap:GetZoom() then indoors = 0 end
    Minimap:SetZoom(Minimap:GetZoom() + temporaryZoom)
    return indoors
end

local function CanonicalZoneName(name)
    if not name then return name end
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    return zoneAliases[name] or name
end

local function FindCurrentMapZone()
    local realZone = CanonicalZoneName(GetRealZoneText())
    local continent
    for continent = 1, 2 do
        local zones = { GetMapZones(continent) }
        local zone
        for zone = 1, table.getn(zones) do
            if CanonicalZoneName(zones[zone]) == realZone then
                return continent, zone, realZone
            end
        end
    end
    return nil, nil, realZone
end

local function GetPosition(forceMap)
    local continent, zone, zoneName = FindCurrentMapZone()
    if not continent or not zone then return nil end

    if forceMap and not WorldMapFrame:IsVisible() then
        SetMapZoom(continent, zone)
    end

    local x, y = GetPlayerMapPosition("player")
    if x == 0 and y == 0 and not WorldMapFrame:IsVisible() then
        SetMapZoom(continent, zone)
        x, y = GetPlayerMapPosition("player")
    end
    if x == 0 and y == 0 then return nil end
    return continent, zone, zoneName, x, y
end

local function ReadNodeTooltip()
    local name = GameTooltipTextLeft1 and GameTooltipTextLeft1:GetText()
    if not name or name == "" then return nil, nil end

    local required = herbRequirements[name]
    local i
    for i = 2, GameTooltip:NumLines() do
        local line = getglobal("GameTooltipTextLeft" .. i)
        local text = line and line:GetText()
        if text and string.find(text, "Herbalism") then
            local _, _, number = string.find(text, "%((%d+)%)")
            if number then required = tonumber(number) end
        end
    end
    return name, required
end

local function DatabaseZone(continent, zone, create)
    local key = tostring(continent) .. ":" .. tostring(zone)
    if create and not OctoGatherDB.nodes[key] then OctoGatherDB.nodes[key] = {} end
    return OctoGatherDB.nodes[key], key
end

local function RecordNode(name, required)
    if not name or name == "" then return end
    local continent, zone, zoneName, x, y = GetPosition(true)
    if not continent then
        Print("Could not read your map position; this zone may need OctoWoW map data.")
        return
    end

    required = required or herbRequirements[name]
    local areaName = GetSubZoneText and GetSubZoneText() or ""
    if GetMinimapZoneText then
        local minimapName = GetMinimapZoneText()
        if minimapName and minimapName ~= "" then areaName = minimapName end
    end
    local nodes = DatabaseZone(continent, zone, true)
    local i
    for i = 1, table.getn(nodes) do
        local node = nodes[i]
        if node.name == name and math.abs(node.x - x) <= DUPLICATE_DISTANCE and
                math.abs(node.y - y) <= DUPLICATE_DISTANCE then
            node.x = (node.x * node.count + x) / (node.count + 1)
            node.y = (node.y * node.count + y) / (node.count + 1)
            node.count = node.count + 1
            if required then node.required = required end
            node.zoneName = zoneName
            node.areaName = areaName
            return
        end
    end

    table.insert(nodes, {
        name = name, required = required, x = x, y = y,
        count = 1, zoneName = zoneName, areaName = areaName,
    })
    local location = zoneName
    if areaName and areaName ~= "" and areaName ~= zoneName then
        location = location .. " - " .. areaName
    end
    Print("learned " .. name .. " in " .. location .. " at " ..
        math.floor(x * 1000) / 10 .. ", " .. math.floor(y * 1000) / 10 .. ".")
end

local function RecordNodeOnce(name, required)
    local now = GetTime()
    if lastRecordedName == name and now - lastRecordedTime < 2 then return end
    RecordNode(name, required)
    lastRecordedName = name
    lastRecordedTime = now
end

local function InstallInteractHook()
    if type(Interact) ~= "function" or Interact == interactWrapper then return end
    -- Wrap the newest implementation if Interact or another addon replaces it.
    originalInteract = Interact
    interactWrapper = function(autoloot)
        lastInteractTime = GetTime()
        return originalInteract(autoloot)
    end
    Interact = interactWrapper
end

local function HerbNameFromLootMessage(message)
    if not message then return nil end
    local _, _, name = string.find(message, "%[([^%]]+)%]")
    if not name then return nil end
    if herbRequirements[name] then return name end
    return nil
end

local function SetPinColor(pin, color)
    local i
    for i = 1, table.getn(pin.edges) do
        pin.edges[i]:SetTexture(color[1], color[2], color[3], 1)
    end
end

-- Self-contained cursor tooltip. This avoids Vanilla tooltip-template and map
-- mouse-layer differences while leaving GameTooltip free for gathering scans.
local markerTooltip = CreateFrame("Frame", "OctoGatherMarkerTooltip", UIParent)
markerTooltip:SetFrameStrata("TOOLTIP")
markerTooltip:SetFrameLevel(100)
markerTooltip:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
markerTooltip:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
local markerTooltipText = markerTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
markerTooltipText:SetPoint("TOPLEFT", markerTooltip, "TOPLEFT", 8, -7)
markerTooltipText:SetJustifyH("LEFT")
markerTooltip:Hide()
local hoveredPin = nil

local function ShowMarkerTooltip(pin)
    if not pin.herbNames or not pin.herbNames[1] then return end
    local text = table.concat(pin.herbNames, "\n")
    markerTooltipText:SetText(text)
    markerTooltip:SetWidth(math.max(44, markerTooltipText:GetStringWidth() + 16))
    markerTooltip:SetHeight(math.max(24, table.getn(pin.herbNames) * 14 + 12))
    markerTooltipText:SetWidth(markerTooltip:GetWidth() - 16)
    markerTooltip:Show()
end

local function PositionMarkerTooltip(cursorX, cursorY)
    local scale = UIParent:GetEffectiveScale()
    local x, y = cursorX / scale, cursorY / scale
    local width, height = markerTooltip:GetWidth(), markerTooltip:GetHeight()
    if x + width + 18 > UIParent:GetWidth() then x = x - width - 14 else x = x + 14 end
    if y + height + 18 > UIParent:GetHeight() then y = y - height - 14 else y = y + 14 end
    markerTooltip:ClearAllPoints()
    markerTooltip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
end

local function EnableMarkerTooltip(pin)
    -- Use screen coordinates for hover; map layers can intercept OnEnter.
    -- Mouse-disabled markers also preserve normal map clicks and dragging.
    pin:EnableMouse(false)
    local function HideMarkerTooltip()
        if hoveredPin == this then
            hoveredPin = nil
            markerTooltip:Hide()
        end
    end
    pin:SetScript("OnHide", HideMarkerTooltip)
end

local function UpdateMarkerHover()
    local cursorX, cursorY = GetCursorPosition()
    local pool = pins
    if WorldMapFrame and WorldMapFrame:IsVisible() then pool = worldPins end
    local candidate = nil
    local i
    for i = 1, table.getn(pool) do
        local pin = pool[i]
        if pin:IsVisible() and pin.herbNames and pin.herbNames[1] and pin.hitParent then
            local scale = pin.hitParent:GetEffectiveScale()
            local x, y = cursorX / scale, cursorY / scale
            if pin.hitAnchor == "TOPLEFT" then
                x = x - pin.hitParent:GetLeft()
                y = y - pin.hitParent:GetTop()
            else
                local centerX, centerY = pin.hitParent:GetCenter()
                x = x - centerX
                y = y - centerY
            end
            if x >= pin.hitLeft - 3 and x <= pin.hitRight + 3 and
                    y >= pin.hitBottom - 3 and y <= pin.hitTop + 3 then
                candidate = pin
                break
            end
        end
    end
    hoveredPin = candidate
    if candidate then
        ShowMarkerTooltip(candidate)
        PositionMarkerTooltip(cursorX, cursorY)
    else
        markerTooltip:Hide()
    end
end

local function SetMarkerNames(pin, names)
    pin.herbNames = {}
    local name
    for name in pairs(names) do table.insert(pin.herbNames, name) end
    table.sort(pin.herbNames)
    -- Pooled pins can represent a different group after moving or zooming.
    if hoveredPin == pin then ShowMarkerTooltip(pin) end
end

local function AddSolidEdge(pin)
    local texture = pin:CreateTexture(nil, "OVERLAY")
    table.insert(pin.edges, texture)
end

local function GetHerbIcon(name)
    return herbIcons[name] or herbIcons["Peacebloom"]
end

local function SetPinBounds(pin, left, right, bottom, top, anchorParent, anchorPoint)
    local width = math.max(4, right - left)
    local height = math.max(4, top - bottom)
    pin:SetWidth(width)
    pin:SetHeight(height)

    local topEdge, bottomEdge, leftEdge, rightEdge =
        pin.edges[1], pin.edges[2], pin.edges[3], pin.edges[4]
    topEdge:ClearAllPoints()
    topEdge:SetPoint("TOPLEFT", pin, "TOPLEFT", 0, 0)
    topEdge:SetPoint("TOPRIGHT", pin, "TOPRIGHT", 0, 0)
    topEdge:SetHeight(2)
    bottomEdge:ClearAllPoints()
    bottomEdge:SetPoint("BOTTOMLEFT", pin, "BOTTOMLEFT", 0, 0)
    bottomEdge:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 0, 0)
    bottomEdge:SetHeight(2)
    leftEdge:ClearAllPoints()
    leftEdge:SetPoint("TOPLEFT", pin, "TOPLEFT", 0, 0)
    leftEdge:SetPoint("BOTTOMLEFT", pin, "BOTTOMLEFT", 0, 0)
    leftEdge:SetWidth(2)
    rightEdge:ClearAllPoints()
    rightEdge:SetPoint("TOPRIGHT", pin, "TOPRIGHT", 0, 0)
    rightEdge:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", 0, 0)
    rightEdge:SetWidth(2)

    anchorParent = anchorParent or Minimap
    anchorPoint = anchorPoint or "CENTER"
    pin.hitLeft, pin.hitRight = left, right
    pin.hitBottom, pin.hitTop = bottom, top
    pin.hitParent, pin.hitAnchor = anchorParent, anchorPoint
    pin:ClearAllPoints()
    pin:SetPoint("CENTER", anchorParent, anchorPoint,
        (left + right) / 2, (bottom + top) / 2)
end

local function AcquirePin(index)
    if pins[index] then return pins[index] end
    local pin = CreateFrame("Frame", "OctoGatherPin" .. index, Minimap)
    pin:SetWidth(14)
    pin:SetHeight(14)
    if MiniMapTrackingFrame then
        pin:SetFrameLevel(MiniMapTrackingFrame:GetFrameLevel() + 1)
    else
        pin:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    end
    pin.edges = {}
    AddSolidEdge(pin)
    AddSolidEdge(pin)
    AddSolidEdge(pin)
    AddSolidEdge(pin)
    pins[index] = pin
    EnableMarkerTooltip(pin)
    return pin
end

local function AcquireWorldPin(index)
    if worldPins[index] then return worldPins[index] end
    local pin = CreateFrame("Frame", "OctoGatherWorldPin" .. index, WorldMapButton)
    pin:SetWidth(14)
    pin:SetHeight(14)
    pin:SetFrameLevel(WorldMapButton:GetFrameLevel() + 5)
    pin.icon = pin:CreateTexture(nil, "ARTWORK")
    pin.icon:SetPoint("TOPLEFT", pin, "TOPLEFT", 2, -2)
    pin.icon:SetPoint("BOTTOMRIGHT", pin, "BOTTOMRIGHT", -2, 2)
    pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    pin.edges = {}
    AddSolidEdge(pin)
    AddSolidEdge(pin)
    AddSolidEdge(pin)
    AddSolidEdge(pin)
    worldPins[index] = pin
    EnableMarkerTooltip(pin)
    return pin
end

local function BoundsOverlap(a, b)
    return a.left <= b.right and a.right >= b.left and
        a.bottom <= b.top and a.top >= b.bottom
end

local function AddMarkerGroup(groups, x, y, difficulty, herbName)
    local group = {
        left = x - 7, right = x + 7, bottom = y - 7, top = y + 7,
        difficulty = difficulty,
        iconName = herbName,
        names = {},
    }
    if herbName then group.names[herbName] = true end

    -- Recheck after every expansion so chains of overlapping markers become
    -- one group even when the first and last markers do not touch directly.
    local merged = true
    while merged do
        merged = false
        local i
        for i = table.getn(groups), 1, -1 do
            local other = groups[i]
            if group.iconName == other.iconName and BoundsOverlap(group, other) then
                local name
                for name in pairs(other.names) do group.names[name] = true end
                group.left = math.min(group.left, other.left)
                group.right = math.max(group.right, other.right)
                group.bottom = math.min(group.bottom, other.bottom)
                group.top = math.max(group.top, other.top)
                if difficultyPriority[other.difficulty] > difficultyPriority[group.difficulty] then
                    group.difficulty = other.difficulty
                end
                table.remove(groups, i)
                merged = true
            end
        end
    end
    table.insert(groups, group)
end

local function HidePinsAfter(index)
    local i
    for i = index, table.getn(pins) do pins[i]:Hide() end
end


local function HideWorldPinsAfter(index)
    local i
    for i = index, table.getn(worldPins) do worldPins[i]:Hide() end
end

local function UpdatePins()
    if not OctoGatherDB or not OctoGatherDB.enabled then
        HidePinsAfter(1)
        return
    end

    local continent, zone, zoneName, playerX, playerY = GetPosition(false)
    if not continent or (not zoneScale[zoneName] and not customZoneSize[zoneName]) then
        HidePinsAfter(1)
        return
    end

    local nodes = DatabaseZone(continent, zone, false)
    if not nodes then
        HidePinsAfter(1)
        return
    end

    local zoom = Minimap:GetZoom() or 0
    local scales = continentScale[continent]
    local minimapScale = scales and scales[zoom + 1]
    local exactSize = customZoneSize[zoneName]
    local zoomSet = exactSize and minimapZoomYards[IsMinimapIndoors()]
    local zoomYards = zoomSet and zoomSet[zoom]
    if not exactSize and not minimapScale then HidePinsAfter(1) return end
    if exactSize and not zoomYards then HidePinsAfter(1) return end

    local skill = GetHerbalismSkill()
    local localScale = zoneScale[zoneName]
    local radius = Minimap:GetWidth() / 2 - 5
    local groups = {}
    local i
    for i = 1, table.getn(nodes) do
        local node = nodes[i]
        local offsetX, offsetY
        if exactSize then
            offsetX = (node.x - playerX) * Minimap:GetWidth() * exactSize[1] / zoomYards
            offsetY = (node.y - playerY) * Minimap:GetHeight() * exactSize[2] / zoomYards
        else
            offsetX = (node.x - playerX) * localScale * minimapScale[1]
            offsetY = (node.y - playerY) * localScale * minimapScale[2]
        end
        local distance = math.sqrt(offsetX * offsetX + offsetY * offsetY)
        if distance <= radius then
            local difficulty = Difficulty(node.required or herbRequirements[node.name], skill)
            AddMarkerGroup(groups, offsetX, -offsetY, difficulty, node.name)
        end
    end


    local shown = math.min(table.getn(groups), MAX_PINS)
    for i = 1, shown do
        local group = groups[i]
        local pin = AcquirePin(i)
        SetMarkerNames(pin, group.names)
        SetPinColor(pin, colors[group.difficulty])
        pin:SetAlpha(group.difficulty == "gray" and 0.5 or 1.0)
        SetPinBounds(pin, group.left, group.right, group.bottom, group.top)
        pin:Show()
    end
    HidePinsAfter(shown + 1)
end


local function UpdateWorldMapPins()
    if not OctoGatherDB or not OctoGatherDB.worldMapEnabled or
            not WorldMapFrame or not WorldMapFrame:IsVisible() then
        HideWorldPinsAfter(1)
        return
    end

    local continent = GetCurrentMapContinent()
    local zone = GetCurrentMapZone()
    if not continent or not zone or continent <= 0 or zone <= 0 then
        HideWorldPinsAfter(1)
        return
    end

    local nodes = DatabaseZone(continent, zone, false)
    local width = WorldMapButton:GetWidth()
    local height = WorldMapButton:GetHeight()
    if not nodes or not width or not height or width <= 0 or height <= 0 then
        HideWorldPinsAfter(1)
        return
    end

    local skill = GetHerbalismSkill()
    local groups = {}
    local i
    for i = 1, table.getn(nodes) do
        local node = nodes[i]
        local x = node.x * width
        local y = -node.y * height
        local difficulty = Difficulty(node.required or herbRequirements[node.name], skill)
        AddMarkerGroup(groups, x, y, difficulty, node.name)
    end

    local shown = math.min(table.getn(groups), MAX_PINS)
    for i = 1, shown do
        local group = groups[i]
        local pin = AcquireWorldPin(i)
        SetMarkerNames(pin, group.names)
        pin.icon:SetTexture(GetHerbIcon(group.iconName))
        SetPinColor(pin, colors[group.difficulty])
        pin:SetAlpha(group.difficulty == "gray" and 0.5 or 1.0)
        SetPinBounds(pin, group.left, group.right, group.bottom, group.top,
            WorldMapButton, "TOPLEFT")
        pin:Show()
    end
    HideWorldPinsAfter(shown + 1)
end


local function CreateWorldMapCheckbox()
    if worldMapCheckbox or not WorldMapFrame then return end
    worldMapCheckbox = CreateFrame("CheckButton", "OctoGatherWorldMapToggle",
        WorldMapFrame, "UICheckButtonTemplate")
    worldMapCheckbox:SetWidth(24)
    worldMapCheckbox:SetHeight(24)
    worldMapCheckbox:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 18, -42)
    worldMapCheckbox:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 10)
    local label = getglobal("OctoGatherWorldMapToggleText")
    if label then
        label:SetText("Octo Gather")
        label:SetTextColor(0.41, 0.80, 0.44)
    end
    worldMapCheckbox:SetChecked(OctoGatherDB.worldMapEnabled)
    worldMapCheckbox:SetScript("OnClick", function()
        OctoGatherDB.worldMapEnabled = this:GetChecked() and true or false
        UpdateWorldMapPins()
    end)
end

local function InitializeDatabase()
    if type(OctoGatherDB) ~= "table" then OctoGatherDB = {} end
    if type(OctoGatherDB.nodes) ~= "table" then OctoGatherDB.nodes = {} end
    if OctoGatherDB.enabled == nil then OctoGatherDB.enabled = true end
    if OctoGatherDB.worldMapEnabled == nil then OctoGatherDB.worldMapEnabled = true end
    OctoGatherDB.version = 1
    CreateWorldMapCheckbox()
    if worldMapCheckbox then worldMapCheckbox:SetChecked(OctoGatherDB.worldMapEnabled) end
end

local function ShowStatus()
    local zones, nodes = 0, 0
    local _, zoneNodes
    for _, zoneNodes in pairs(OctoGatherDB.nodes) do
        zones = zones + 1
        nodes = nodes + table.getn(zoneNodes)
    end
    local continent, zone, zoneName = FindCurrentMapZone()
    local currentNodes = 0
    local supported = false
    if continent and zone then
        local zoneNodes = DatabaseZone(continent, zone, false)
        currentNodes = zoneNodes and table.getn(zoneNodes) or 0
        supported = zoneScale[zoneName] or customZoneSize[zoneName]
    end
    Print((OctoGatherDB.enabled and "rings enabled" or "rings hidden") .. "; " ..
        nodes .. " herb locations saved in " .. zones .. " zones; Herbalism " ..
        GetHerbalismSkill() .. ".")
    if continent and zone then
        Print("current map " .. continent .. ":" .. zone .. " (" .. zoneName .. ") has " .. currentNodes ..
            " saved nodes; minimap scaling " .. (supported and "supported." or "NOT supported."))
    else
        Print("current zone could not be matched to a continent map.")
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("SPELLCAST_START")
frame:RegisterEvent("SPELLCAST_STOP")
frame:RegisterEvent("SPELLCAST_FAILED")
frame:RegisterEvent("SPELLCAST_INTERRUPTED")
frame:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF")
frame:RegisterEvent("CHAT_MSG_LOOT")
frame:RegisterEvent("SKILL_LINES_CHANGED")
frame:RegisterEvent("MINIMAP_UPDATE_ZOOM")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("WORLD_MAP_UPDATE")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "OctoGather" then
        InitializeDatabase()
        InstallInteractHook()
    elseif event == "ADDON_LOADED" and arg1 == "Interact" then
        InstallInteractHook()
    elseif event == "PLAYER_ENTERING_WORLD" then
        InitializeDatabase()
        UpdatePins()
        UpdateWorldMapPins()
    elseif event == "SPELLCAST_START" and arg1 == "Herb Gathering" then
        pendingNode, pendingRequirement = ReadNodeTooltip()
        -- Interact.dll starts the native gather without first placing the world
        -- object under GameTooltip, so the cast itself is enough to arm us.
        pendingGather = true
    elseif event == "CHAT_MSG_SPELL_SELF_BUFF" and arg1 then
        local _, _, gatheredName = string.find(arg1, "^You perform Herb Gathering on (.+)%.$")
        if gatheredName then
            RecordNodeOnce(gatheredName, herbRequirements[gatheredName] or
                (pendingNode == gatheredName and pendingRequirement or nil))
            pendingNode, pendingRequirement, pendingGather = nil, nil, false
            UpdatePins()
        end
    elseif event == "CHAT_MSG_LOOT" and GetTime() - lastInteractTime < 10 then
        local gatheredName = HerbNameFromLootMessage(arg1)
        if gatheredName then
            RecordNodeOnce(gatheredName, herbRequirements[gatheredName])
            lastInteractTime = 0
            pendingNode, pendingRequirement, pendingGather = nil, nil, false
            UpdatePins()
        end
    elseif event == "SPELLCAST_STOP" and pendingGather then
        -- Normal right-click gathering supplies a tooltip. This remains a
        -- fallback for clients that do not print the successful gather line.
        if pendingNode then RecordNodeOnce(pendingNode, pendingRequirement) end
        pendingNode, pendingRequirement, pendingGather = nil, nil, false
        UpdatePins()
    elseif event == "SPELLCAST_FAILED" or event == "SPELLCAST_INTERRUPTED" then
        pendingNode, pendingRequirement, pendingGather = nil, nil, false
    elseif event == "WORLD_MAP_UPDATE" then
        UpdateWorldMapPins()
    elseif event == "SKILL_LINES_CHANGED" or event == "MINIMAP_UPDATE_ZOOM" or
            event == "ZONE_CHANGED_NEW_AREA" then
        UpdatePins()
        UpdateWorldMapPins()
    end
end)

frame:SetScript("OnUpdate", function()
    elapsedSinceUpdate = elapsedSinceUpdate + arg1
    if elapsedSinceUpdate >= UPDATE_INTERVAL then
        elapsedSinceUpdate = 0
        InstallInteractHook()
        UpdatePins()
        UpdateWorldMapPins()
        UpdateMarkerHover()
    end
end)

SLASH_OCTOGATHER1 = "/octogather"
SLASH_OCTOGATHER2 = "/ogather"
SlashCmdList["OCTOGATHER"] = function(message)
    local command = string.lower(message or "")
    if command == "on" or command == "show" then
        OctoGatherDB.enabled = true
        UpdatePins()
        Print("minimap markers enabled.")
    elseif command == "off" or command == "hide" then
        OctoGatherDB.enabled = false
        UpdatePins()
        Print("minimap markers hidden; gathering locations will still be learned.")
    elseif command == "count" or command == "status" or command == "" then
        ShowStatus()
    else
        Print("commands: /ogather on, off, or count")
    end
end
