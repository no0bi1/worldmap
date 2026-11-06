-- WorldMap
-- Standalone World Map layout and interaction addon for the WoW 1.12 client.

local MAP_WIDTH = 1024;
local MAP_HEIGHT = 768;
local MAP_SCALE = 0.8;
local FADE_ALPHA = 0.35;
local MAP_STRATA = "LOW";
local OFF_ZONE_CHECK_INTERVAL = 1;

local originalState;
local moduleActive = false;
local escRegistered = false;
local escRegisteredByAddon = false;
local mapFadeFrame;
local clickThroughFrame;
local mapTitleBar;
local mapClickDown;

local eventFrame = CreateFrame("Frame", "WorldMapAddonEventFrame");
local function CaptureWorldMapState()
    if originalState then
        return;
    end

    local point, relativeTo, relativePoint, x, y = WorldMapFrame:GetPoint(1);
    local state = {
        point = point,
        relativeTo = relativeTo,
        relativePoint = relativePoint,
        x = x,
        y = y,
        width = WorldMapFrame:GetWidth(),
        height = WorldMapFrame:GetHeight(),
        scale = WorldMapFrame:GetScale(),
        strata = WorldMapFrame:GetFrameStrata(),
        onShow = WorldMapFrame:GetScript("OnShow"),
        onKeyDown = WorldMapFrame:GetScript("OnKeyDown"),
        worldFrameOnMouseDown = WorldFrame:GetScript("OnMouseDown"),
        worldFrameOnMouseUp = WorldFrame:GetScript("OnMouseUp"),
        frameMouseEnabled = WorldMapFrame:IsMouseEnabled(),
        buttonMouseEnabled = WorldMapButton:IsMouseEnabled(),
        movable = WorldMapFrame:IsMovable(),
        tooltipScale = WorldMapTooltip:GetScale(),
        alpha = WorldMapFrame:GetAlpha(),
        blackoutVisible = BlackoutWorld.IsShown and BlackoutWorld:IsShown() or BlackoutWorld:IsVisible(),
        panelEntry = UIPanelWindows and UIPanelWindows["WorldMapFrame"],
        specialFrameRegistered = false,
    };

    if WorldMapFrame.IsKeyboardEnabled then
        state.keyboardEnabled = WorldMapFrame:IsKeyboardEnabled();
    else
        state.keyboardEnabled = true;
    end

    if UISpecialFrames then
        for _, frameName in ipairs(UISpecialFrames) do
            if frameName == "WorldMapFrame" then
                state.specialFrameRegistered = true;
                break;
            end
        end
    end

    originalState = state;
    escRegistered = state.specialFrameRegistered;
end

local function DisableWorldMap()
    if not moduleActive or not originalState then
        return;
    end

    local state = originalState;

    if mapFadeFrame then
        mapFadeFrame:SetScript("OnUpdate", nil);
    end
    if clickThroughFrame then
        clickThroughFrame:SetScript("OnUpdate", nil);
    end
    if mapTitleBar then
        mapTitleBar:Hide();
    end

    WorldFrame:SetScript("OnMouseDown", state.worldFrameOnMouseDown);
    WorldFrame:SetScript("OnMouseUp", state.worldFrameOnMouseUp);

    WorldMapFrame:SetScript("OnShow", state.onShow);
    WorldMapFrame:SetScript("OnKeyDown", state.onKeyDown);
    WorldMapFrame:SetFrameStrata(state.strata);
    WorldMapFrame:SetScale(state.scale);
    WorldMapFrame:SetWidth(state.width);
    WorldMapFrame:SetHeight(state.height);
    WorldMapFrame:ClearAllPoints();
    if state.point then
        WorldMapFrame:SetPoint(state.point, state.relativeTo, state.relativePoint, state.x, state.y);
    end
    WorldMapFrame:SetMovable(state.movable);
    WorldMapFrame:EnableMouse(state.frameMouseEnabled);
    WorldMapButton:EnableMouse(state.buttonMouseEnabled);
    WorldMapFrame:EnableKeyboard(state.keyboardEnabled);
    WorldMapTooltip:SetScale(state.tooltipScale);
    WorldMapFrame:SetAlpha(state.alpha);

    if state.blackoutVisible then
        BlackoutWorld:Show();
    else
        BlackoutWorld:Hide();
    end

    if UIPanelWindows then
        UIPanelWindows["WorldMapFrame"] = state.panelEntry;
    end

    if escRegisteredByAddon and not state.specialFrameRegistered and UISpecialFrames then
        for i = table.getn(UISpecialFrames), 1, -1 do
            if UISpecialFrames[i] == "WorldMapFrame" then
                table.remove(UISpecialFrames, i);
            end
        end
        escRegistered = false;
        escRegisteredByAddon = false;
    end

    moduleActive = false;
end

local function SwitchMapAndGetPlayerPosition()
    local viewedContinent, viewedZone = GetCurrentMapContinent(), GetCurrentMapZone();

    SetMapToCurrentZone();

    local continent, zone = GetCurrentMapContinent(), GetCurrentMapZone();
    local px, py = GetPlayerMapPosition("player");

    if viewedContinent ~= continent or viewedZone ~= zone then
        if viewedZone and viewedZone > 0 then
            SetMapZoom(viewedContinent, viewedZone);
        else
            SetMapZoom(viewedContinent);
        end
    end

    if px and py and (px ~= 0 or py ~= 0) then
        return continent, zone, px, py;
    end

    return nil;
end

local function SetupMapFade()
    if not mapFadeFrame then
        mapFadeFrame = CreateFrame("Frame", "WorldMapAddonFadeFrame");
        mapFadeFrame.elapsed = 0;
        mapFadeFrame.nextCheck = 0;
        mapFadeFrame.movingUntil = 0;
    end

    mapFadeFrame:SetScript("OnUpdate", function()
        if not WorldMapFrame:IsVisible() then
            this.elapsed = 0;
            this.nextCheck = 0;
            this.lastX = nil;
            return;
        end

        this.elapsed = this.elapsed + arg1;
        if this.elapsed < 0.1 then
            return;
        end
        this.elapsed = 0;

        local now = GetTime();
        local x, y = GetPlayerMapPosition("player");
        local continent, zone, hold;
        local sample = true;

        if x and y and (x ~= 0 or y ~= 0) then
            continent, zone = GetCurrentMapContinent(), GetCurrentMapZone();
            hold = 0.3;
        elseif now >= this.nextCheck then
            this.nextCheck = now + OFF_ZONE_CHECK_INTERVAL;
            continent, zone, x, y = SwitchMapAndGetPlayerPosition();
            hold = OFF_ZONE_CHECK_INTERVAL + 0.2;
        else
            sample = false;
        end

        if sample then
            if continent then
                if this.lastX and this.lastC == continent and this.lastZ == zone and
                   (x ~= this.lastX or y ~= this.lastY) then
                    this.movingUntil = now + hold;
                end
                this.lastC, this.lastZ, this.lastX, this.lastY = continent, zone, x, y;
            else
                this.lastX = nil;
            end
        end

        if UnitOnTaxi("player") then
            this.movingUntil = 0;
            WorldMapFrame:SetAlpha(1.0);
        elseif now < this.movingUntil then
            WorldMapFrame:SetAlpha(FADE_ALPHA);
        else
            WorldMapFrame:SetAlpha(1.0);
        end
    end);
end

local function SetupClickThrough()
    if not clickThroughFrame then
        clickThroughFrame = CreateFrame("Frame", "WorldMapAddonClickThroughFrame");
    end

    clickThroughFrame:SetScript("OnUpdate", function()
        if not WorldMapFrame:IsVisible() then
            return;
        end

        local interactive = IsShiftKeyDown() or IsControlKeyDown();
        local isOn = WorldMapButton:IsMouseEnabled();

        if interactive and not isOn then
            WorldMapFrame:EnableMouse(true);
            WorldMapButton:EnableMouse(true);
        elseif not interactive and isOn then
            WorldMapFrame:EnableMouse(false);
            WorldMapButton:EnableMouse(false);
        end
    end);
end

local function SetupTitleBar()
    if mapTitleBar then
        mapTitleBar:Show();
        return;
    end

    local bar = CreateFrame("Frame", "WorldMapAddonTitleBar", WorldMapFrame);
    bar:SetHeight(28);
    bar:SetPoint("TOPLEFT", WorldMapFrame, "TOPLEFT", 0, 0);
    bar:SetPoint("TOPRIGHT", WorldMapFrame, "TOPRIGHT", 0, 0);
    bar:SetFrameLevel(WorldMapFrame:GetFrameLevel() + 1);
    bar:EnableMouse(true);
    bar:RegisterForDrag("LeftButton");

    bar:SetScript("OnDragStart", function()
        WorldMapFrame:StartMoving();
    end);

    bar:SetScript("OnDragStop", function()
        WorldMapFrame:StopMovingOrSizing();
        WorldMapFrame:SetWidth(MAP_WIDTH);
        WorldMapFrame:SetHeight(MAP_HEIGHT);

        local x, y = WorldMapFrame:GetCenter();
        local scale = UIParent:GetEffectiveScale() / 2 / WorldMapFrame:GetScale();
        x = x - GetScreenWidth() * scale;
        y = y - GetScreenHeight() * scale;

        WorldMapFrame:ClearAllPoints();
        WorldMapFrame:SetPoint("CENTER", "UIParent", "CENTER", x, y);
    end);

    mapTitleBar = bar;
end

local function SetupWorldClicks()
    WorldFrame:SetScript("OnMouseDown", function()
        mapClickDown = GetTime();
    end);

    WorldFrame:SetScript("OnMouseUp", function()
        if not WorldMapFrame:IsVisible()
           or not MouseIsOver(WorldMapButton)
           or IsShiftKeyDown() or IsControlKeyDown()
           or not mapClickDown or GetTime() - mapClickDown > 0.25 then
            return;
        end

        if arg1 == "LeftButton" then
            local x, y = GetCursorPosition();
            local scale = WorldMapButton:GetEffectiveScale();
            ProcessMapClick(
                (x / scale - WorldMapButton:GetLeft()) / WorldMapButton:GetWidth(),
                (WorldMapButton:GetTop() - y / scale) / WorldMapButton:GetHeight()
            );
        elseif arg1 == "RightButton" and
            (GetCurrentMapZone() > 0 or GetCurrentMapContinent() > 0) then
            WorldMapZoomOutButton_OnClick();
        end
    end);
end

local function EnableWorldMap()
    if moduleActive then
        return;
    end

    CaptureWorldMapState();

    if UIPanelWindows then
        UIPanelWindows["WorldMapFrame"] = nil;
    end

    if not escRegistered and UISpecialFrames then
        escRegistered = true;
        escRegisteredByAddon = true;
        tinsert(UISpecialFrames, "WorldMapFrame");
    end

    WorldMapFrame:SetFrameStrata(MAP_STRATA);
    WorldMapFrame:SetScript("OnKeyDown", nil);
    WorldMapFrame:EnableKeyboard(false);
    WorldMapFrame:EnableMouse(false);
    WorldMapFrame:SetMovable(true);
    WorldMapFrame:SetScale(MAP_SCALE);
    WorldMapTooltip:SetScale(1);
    WorldMapFrame:SetWidth(MAP_WIDTH);
    WorldMapFrame:SetHeight(MAP_HEIGHT);
    WorldMapFrame:ClearAllPoints();
    WorldMapFrame:SetPoint("CENTER", "UIParent", "CENTER", 0, 0);
    BlackoutWorld:Hide();

    WorldMapFrame:SetScript("OnShow", function()
        SetMapZoom(GetCurrentMapContinent(), GetCurrentMapZone());
        SetMapToCurrentZone();
    end);

    SetupMapFade();
    SetupClickThrough();
    SetupTitleBar();
    SetupWorldClicks();
    moduleActive = true;
end

local function UpdateWorldMap()
    if not WorldMapAddonDB or not WorldMapAddonDB.enabled then
        DisableWorldMap();
        return;
    end

    if IsAddOnLoaded("Cartographer") or IsAddOnLoaded("MetaMap") then
        DisableWorldMap();
        return;
    end

    local inInstance, instanceType = false, "none";
    if IsInInstance then
        inInstance, instanceType = IsInInstance();
    elseif GetInstanceInfo then
        local _, instance = GetInstanceInfo();
        instanceType = instance;
        inInstance = instance and instance ~= "none";
    end

    if inInstance and (instanceType == "party" or instanceType == "raid") then
        DisableWorldMap();
    else
        EnableWorldMap();
    end
end

local function SetEnabled(enabled)
    WorldMapAddonDB.enabled = enabled and true or false;
    UpdateWorldMap();
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WorldMap:|r " ..
        (WorldMapAddonDB.enabled and "enabled." or "disabled."));
end

local function OnEvent()
    if event == "VARIABLES_LOADED" then
        WorldMapAddonDB = WorldMapAddonDB or {};
        if WorldMapAddonDB.enabled == nil then
            WorldMapAddonDB.enabled = true;
        end
        UpdateWorldMap();
        eventFrame:UnregisterEvent("VARIABLES_LOADED");
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD");
        eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA");
        eventFrame:RegisterEvent("ZONE_CHANGED");
        eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS");
    else
        UpdateWorldMap();
    end
end

eventFrame:RegisterEvent("VARIABLES_LOADED");
eventFrame:SetScript("OnEvent", OnEvent);

SLASH_WORLDMAP1 = "/worldmap";
SLASH_WORLDMAP2 = "/wmap";
SlashCmdList["WORLDMAP"] = function(msg)
    msg = string.lower(msg or "");
    if msg == "on" then
        SetEnabled(true);
    elseif msg == "off" then
        SetEnabled(false);
    elseif msg == "toggle" or msg == "" then
        SetEnabled(not WorldMapAddonDB.enabled);
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99WorldMap commands:|r /worldmap on, off, toggle");
    end
end
