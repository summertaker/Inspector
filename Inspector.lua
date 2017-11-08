------------------------
-- 다국어 전역 변수
------------------------
L = INSPECTOR_L;

------------------------
-- 환경설정 변수
------------------------
Inspector_AnimateChecked = true;
Inspector_SpinChecked = true;
Inspector_BackgroundChecked = true;

------------------------
-- 변수 설정
------------------------
Inspector_ModelSpin = true;

local frameSize = "large";
local frameChanging = false;

-- http://us.battle.net/forums/en/wow/topic/8569600188
local animations = {
    0, -- Idle
    67, -- Hi
    80,
    26, 4, 84, 124, 0, 120, 0, 119, 0,
 5, 0, 69, 0, 66, 0, 68, 0, 70, 0, 74, 0, 75 }
local animationIndex = 1;
local animationUpdateInterval = 2.2; -- How often the OnUpdate code will run (in seconds)
local animationSinceLastUpdate = 0.0;

local unitId = nil;
local frameBorderSize = 18;
local mouseFacing = 0;
local modelScale = 1;
local cursorX = 0;
local cursorY = 0;
local isDraging = false;

local backFile = "Interface\\Glues\\LoadingScreens\\LoadScreenZulGurub"
local backNone = "Interface\\DialogFrame\\UI-DialogBox-Background"; -- "Interface\\Tooltips\\UI-Tooltip-Background";
local edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border"; -- "Interface\\Tooltips\\UI-Tooltip-Border";
local backdrop = {
    bgFile = backFile,
    edgeFile = edgeFile,
    tile = false, tileSize = 16, edgeSize = 24,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
}

----------------------
-- 아이템 관련 변수
----------------------
local items = {};
local slots = {
    "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot",
    "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot",
    "MainHandSlot", "SecondaryHandSlot"
}
local continueInspecting = false;
local handsSlotInspecting = false;
local mainHandLink = nil;
local secondaryHandLink = nil;
local isTwoHandWeapon = false;
local isArtifactWeapon = false;
local averageItemLevel = 0;
local averageLevelSum = 0;
local averageLevelCount = 0;

---------------------------
-- 대상 초상화 위의 트리거 버튼
---------------------------
local targetIcon = nil;

---------------------
-- 단축키 변수
---------------------
BINDING_HEADER_INSPECTOR = L["Inspector"];
BINDING_NAME_INSPECTOR_INSPECT = L["Inspect"];

-----------------------------
-- 애드온 로드 시 최초 실행
-----------------------------
function Inspector_OnLoad(self)
    local frame = Inspector;
    frame:RegisterEvent("ADDON_LOADED");
    frame:RegisterEvent("PLAYER_TARGET_CHANGED");
    frame:RegisterForDrag("LeftButton"); --, "RightButton");

    frame:SetScript("OnEvent", Inspector_OnEvent);
    frame:SetScript("OnUpdate", Inspector_OnUpdate);
    frame:SetScript("OnMouseDown", Inspector_OnMouseDown);
    frame:SetScript("OnMouseUp", Inspector_OnMouseUp);
    frame:SetScript("OnMouseWheel", Inspector_OnMouseWheel);
    frame:SetScript("OnDragStart", Inspector_OnDragStart);
    frame:SetScript("OnDragStop", Inspector_OnDragStop);
    frame:SetScript("OnHide", Inspector_OnHide);

    -- 다국어 설정하기
    Inspector_MainFrame_HeaderString:SetText(L["Inspector"]);
    Inspector_ConfigButton:SetText(L["Config"]);
    --Inspector_CloseButton:SetText(L["Close"]);
    Inspector_BlizzardInspectButton:SetText(L["Inspect"]);
    Inspector_InventoryFrameLeft_LoadingString:SetText(L["Loading..."]);
    Inspector_InventoryFrameRight_LoadingString:SetText(L["Loading..."]);

    -- ESC 키로 창 닫기
    tinsert(UISpecialFrames, "Inspector");
    tinsert(UISpecialFrames, "InspectorConfigFrame");

    Inspector_InitTargetIcon();
end

---------------------
-- 이벤트 처리하기
---------------------
function Inspector_OnEvent(self, event, ...)
    if (event == "ADDON_LOADED") then
        Inspector_AddonLoaded();
        Inspector_UpdateSizingUI();
    elseif (event == "PLAYER_TARGET_CHANGED") then
        Inspector_PlayerTargetChanged();
    elseif (event == "INSPECT_READY") then
        Inspector_InspectReady();
    end
end

-----------------------------------------
-- 대상(Target) 프레임에 아이콘 표시하기
-----------------------------------------
function Inspector_InitTargetIcon()
    targetIcon = CreateFrame("Button", "Inspector_TargetIcon", TargetFrame);
    targetIcon:SetPoint("TOPLEFT", TargetFrame, "TOPLEFT", 110, -40);
    --[[
    -- 미니맵 위로 올렸을 때 미니맵 기능 아이콘 클릭 시 미니맵 프레임에 가려지는 경우
    -- 아래처럼 Minimap을 기준으로 프레임을 만들면 가려지지 않는다.
    --targetIcon = CreateFrame("Button", "Inspector_TargetIcon", Minimap);
    --targetIcon:SetPoint("TOPLEFT", Minimap, "LEFT", 2, 0);
    ]]
    targetIcon:SetWidth(32);
    targetIcon:SetHeight(32);
    targetIcon:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight");
    -- http://wowprogramming.com/docs/api_types#frameStrata
    -- BACKGROUND, LOW, MEDIUM, HIGH, DIALOG, FULLSCREEN, FULLSCREEN_DIALOG, TOOLTIP
    targetIcon:SetFrameStrata("DIALOG");
    targetIcon:SetMovable(true);
    targetIcon:RegisterForClicks("LeftButtonUp"); --, "RightButtonUp");
    targetIcon:RegisterForDrag("LeftButton");
    targetIcon:SetScript("OnMouseDown", function(self, button)
        SetDesaturation(targetIcon.icon, true);
    end);
    targetIcon:SetScript("OnMouseUp", function(self, button)
        if (button == "LeftButton") then
            Inspector_Inspect_OnPress();
        elseif (button == "RightButton") then
            --InterfaceOptionsFrame_OpenToCategory("Inspector");
        end
        SetDesaturation(targetIcon.icon, false);
    end);
    targetIcon:SetScript("OnDragStart", function(self)
        self:StartMoving();
    end);
    targetIcon:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing();
        SetDesaturation(targetIcon.icon, false);
    end);
    targetIcon:SetScript("OnHide", function(self)
        self:StopMovingOrSizing();
        SetDesaturation(targetIcon.icon, false);
    end);

    -- http://wowprogramming.com/docs/api_types#layer
    -- BACKGROUND, ARTWORK, OVERLAY, HIGHLIGHT
    targetIcon.back = targetIcon:CreateTexture("TargetClassBackground", "BACKGROUND");
    targetIcon.back:SetTexture("Interface\\Minimap\\UI-Minimap-Background");
    targetIcon.back:SetWidth(22);
    targetIcon.back:SetHeight(22);
    targetIcon.back:SetPoint("CENTER");
    targetIcon.back:SetVertexColor(0, 0, 0, 0.7);

    targetIcon.icon = targetIcon:CreateTexture("TargetClassIcon", "ARTWORK");
    targetIcon.icon:SetTexture("Interface\\PvPRankBadges\\PvPRank12");
    targetIcon.icon:SetWidth(16);
    targetIcon.icon:SetHeight(16);
    targetIcon.icon:SetPoint("CENTER");

    targetIcon.border = targetIcon:CreateTexture("TargetClassBorder", "OVERLAY");
    targetIcon.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
    targetIcon.border:SetWidth(54);
    targetIcon.border:SetHeight(54);
    targetIcon.border:SetPoint("CENTER", 11, -12);

    -- http://wowprogramming.com/docs/widgets/Texture/SetTexCoord
    -- 클래스 아이콘 표시하기
    --[[CreateFrame("Frame","Test",UIParent)
    Test:SetWidth(96)
    Test:SetHeight(96)
    Test:SetPoint("CENTER",0,0)
    Test:CreateTexture("TestTexture")
    TestTexture:SetAllPoints()
    TestTexture:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
    --TestTexture:SetTexCoord(0, 0.25, 0, 0.25);]]
end

function Inspector_PlayerTargetChanged()
    if (UnitExists("target")) then
        unitId = "target";
        Inspector_PlayerModel:SetUnit(unitId);

        if Inspector:IsVisible() then
            Inspector_Hide();
            Inspector_Show();
        end
        animationIndex = 1;
    else
        --Inspector_Hide();
    end
end

function Inspector_Inspect_OnPress()
    if (Inspector:IsVisible()) then
    --if (DressUpFrame:IsVisible()) then
        Inspector_Hide();
    else
        if (not UnitExists("target")) then
            unitId = "player";
            Inspector_PlayerModel:SetUnit(unitId);
        end
        Inspector_Show();
    end
end

function Inspector_OnMouseDown(self, button)
    --print("OnMouseDown");
    cursorX, cursorY = GetCursorPosition();
    if (button == "LeftButton") then
        mouseFacing = 1; -- Model Rotation Start.
    end
    isDraging = false;
end

function Inspector_OnMouseUp(self, button)
    --print("OnMouseUp");
    local cx, cy = GetCursorPosition();
    if (cursorX == cx and cursorY == cy) then
        if (not isDraging) then
            Inspector_Hide();
        end
    else
        isDraging = true;
    end
    mouseFacing = 0; -- Model Rotation End.
end

function Inspector_OnMouseWheel(self, delta)
    local model = Inspector_PlayerModel;
    local scale = 0.02;
    if (delta == -1) then
        modelScale = modelScale - scale;
        if (modelScale < 0.7) then
            modelScale = 0.7;
        end
    else
        modelScale = modelScale + scale;
        if (modelScale > 1.3) then
            modelScale = 1.3;
        end
    end
    model:SetScale(modelScale);
end

function Inspector_OnDragStart()
    --print("OnDragStart");
    if (Inspector_SpinChecked) then
        Inspector_ModelSpin = false;
    end
    mouseFacing = 1;
    isDraging = true;
end

function Inspector_OnDragStop()
    --print("OnDragStop");
    if (Inspector_SpinChecked) then
        Inspector_ModelSpin = true;
    end
    mouseFacing = 0;
end

function Inspector_OnUpdate(self, elapsed)
    local model = Inspector_PlayerModel;

    if (Inspector_ModelSpin) then
        model:SetFacing(model:GetFacing() + elapsed);
    else
        if (mouseFacing == 1) then
            local cx, cy = GetCursorPosition();
            model:SetFacing(model:GetFacing() + ((cx - cursorX) / 50));
            cursorX, cursorY = GetCursorPosition();
        end
    end

    if (Inspector_AnimateChecked) then
        -- http://wowwiki.wikia.com/wiki/Using_OnUpdate_correctly
        animationSinceLastUpdate = animationSinceLastUpdate + elapsed;
        if (animationSinceLastUpdate > animationUpdateInterval) then
            local max = table.getn(animations);
            animationIndex = animationIndex + 1;
            if (animationIndex > max) then
                animationIndex = 1;
            end
            model:SetAnimation(animations[animationIndex], 0);
            animationSinceLastUpdate = 0.0;
        end
    else
        --model:SetAnimation(0, 0);
    end

    if (continueInspecting) then
        Inspector_InspectReady();
    elseif (handsSlotInspecting) then
        Inspector_InspectHansSlotReady();
    end
end

function Inspector_Show()
    if (unitId == nil) then
        return;
    end

    local frame = Inspector;
    local back = Inspector_MainFrame;
    local model = Inspector_PlayerModel;
    local invenLeft = Inspector_InventoryFrameLeft;
    local invenRight = Inspector_InventoryFrameRight;

    --PlaySound("GAMEDIALOGOPEN", "master"); -- http://wowwiki.wikia.com/wiki/API_PlaySound

    local scale = UIParent:GetEffectiveScale();
    local width = GetScreenWidth() * scale;
    local height = GetScreenHeight() * scale;

    local wScale = (frameSize == "small") and 1.7 or 2.2;
    local hScale = (frameSize == "small") and 3.0 or 8;
    width = width - (width / wScale);
    height = height - (height / hScale);

    frame:SetWidth(width);
    frame:SetHeight(height);
    frame:ClearAllPoints();
    frame:SetPoint("CENTER", "UIParent");

    back:SetWidth(width);
    back:SetHeight(height);
    if (Inspector_BackgroundChecked) then
        Inspector_ShowBackground();
    else
        Inspector_HideBackground();
    end

    --------------
    -- 모델 설정
    --------------
    width = height;
    model:SetWidth(width - frameBorderSize);
    model:SetHeight(height - frameBorderSize);

    if (not frameChanging) then
        model:SetScale(1);

        if (Inspector_SpinChecked) then
            Inspector_ModelSpin = true;
            model:SetFacing(180);
        else
            model:SetFacing(0);
        end

        if (Inspector_AnimateChecked) then
            animationIndex = 1;
            model:SetAnimation(0, 0);
        end
    end

    invenLeft:SetHeight(height - 30); -- 아이템 목록 좌측 프레임
    invenRight:SetHeight(height - 30); -- 아이템 목록 우측 프레임

    ShowUIPanel(frame);

    Inspector_ShowUnitInfo();

    if CanInspect(unitId) then -- and CheckInteractDistance(unitId, 1) then
        Inspector_ShowInventory();
    else
        Inspector_HideInventory();
    end
end

function Inspector_Hide()
    if (Inspector:IsVisible() and frameChanging == false) then
        --PlaySound("GAMEDIALOGCLOSE", "master"); -- http://wowwiki.wikia.com/wiki/API_PlaySound
    end

    HideUIPanel(Inspector);

    Inspector_HideInventory();

    if (InspectorConfig:IsVisible()) then
        HideUIPanel(InspectorConfig);
    end
    BlizzardInspectUI_Hide();
end

function Inspector_OnHide()
    continueInspecting = false;
    handsSlotInspecting = false;
    Inspector:UnregisterEvent("INSPECT_READY");
    --ClearInspectPlayer();
end

function Inspector_ShowUnitInfo()

    local name, realm = UnitName(unitId);

    if (unitId and name) then

        local level = UnitLevel(unitId);
        local factionGroup, factionName = UnitFactionGroup(unitId);

        if (factionGroup ~= nil) then
            --local factionTexture = "Interface\\FriendsFrame\\PlusManz-"..factionGroup..".blp";
            local factionTexture = "Interface\\AddOns\\Inspector\\Textures\\"..factionGroup..".tga";
            Inspector_MainFrame_FactionTexture:SetTexture(factionTexture);
            Inspector_MainFrame_FactionTexture:Show();

            Inspector_MainFrame_InfoBackTexture:Show();

            -- NAME
            Inspector_MainFrame_NameString:SetText(name);
            Inspector_MainFrame_NameString:Show();

            -- LEVEL
            Inspector_MainFrame_LevelString:SetText("Lv."..level);
            Inspector_MainFrame_LevelString:Show();

            -- NPC
            Inspector_MainFrame_NpcBack:Hide();
            Inspector_MainFrame_NpcString:Hide();
        else
            Inspector_MainFrame_FactionTexture:Hide();
            Inspector_MainFrame_InfoBackTexture:Hide();
            Inspector_MainFrame_NameString:Hide();
            Inspector_MainFrame_LevelString:Hide();
            Inspector_MainFrame_GuildString:Hide();

            -- NPC
            Inspector_MainFrame_NpcBack:Show();
            Inspector_MainFrame_NpcString:SetText(name);
            Inspector_MainFrame_NpcString:Show();
        end

        -- GUILD
        local guildName, guildRankName, guildRankIndex = GetGuildInfo(unitId);
        if (guildName) then
            Inspector_MainFrame_GuildString:SetText(guildName);
            Inspector_MainFrame_GuildString:Show();
        else
            Inspector_MainFrame_GuildString:Hide();
        end

        -- CLASS
        local class, classFileName = UnitClass(unitId);
        local classColor = nil;
        if (class ~= nil and class ~= name) then
            --print("class: "..class); -- "마법사"
            --print("classFileName: "..classFileName); -- "MAGE"
            local classTexture = "Interface\\AddOns\\Inspector\\Textures\\"..classFileName..".tga";
            Inspector_MainFrame_ClassTexture:SetTexture(classTexture);
            Inspector_MainFrame_ClassTexture:Show();
            Inspector_MainFrame_ClassBack:Show();

            classColor = RAID_CLASS_COLORS[classFileName];
            Inspector_MainFrame_ClassString:SetText(class);
            Inspector_MainFrame_ClassString:SetTextColor(classColor.r, classColor.g, classColor.b, 1);
            Inspector_MainFrame_ClassString:Show();
        else
            Inspector_MainFrame_ClassTexture:Hide();
            Inspector_MainFrame_ClassBack:Hide();
            Inspector_MainFrame_ClassString:Hide();
        end

        -- RACE
        local race, raceFileName = UnitRace(unitId);
        if (race ~= nil) then
            --print("race: "..race); -- "인간", "판다렌", ...
            --print("raceFileName: "..raceFileName); -- "Human", "Pandaren", ...

            if (raceFileName == "Scourge") then
                raceFileName = "Undead";
            end
            local raceTexture = "Interface\\AddOns\\Inspector\\Textures\\"..raceFileName..".tga";
            Inspector_MainFrame_RaceTexture:SetTexture(raceTexture);
            Inspector_MainFrame_RaceTexture:Show();
            Inspector_MainFrame_RaceBack:Show();

            if (classColor ~= nil) then
                Inspector_MainFrame_RaceString:SetTextColor(classColor.r, classColor.g, classColor.b, 1);
            else
                Inspector_MainFrame_RaceString:SetTextColor(0.9, 0.9, 0.9, 1);
            end
            Inspector_MainFrame_RaceString:SetText(race);
            Inspector_MainFrame_RaceString:Show();
        else
            Inspector_MainFrame_RaceTexture:Hide();
            Inspector_MainFrame_RaceBack:Hide();
            Inspector_MainFrame_RaceString:Hide();
        end

        --local type = UnitCreatureType(unitId);
        --print("type: "..type); -- "인간형", "야수", "정령" ...

        --if UnitCreatureFamily(unitId) then
        --    print(UnitCreatureFamily(unitId));
        --end

        --if UnitClassification(unitId) then
        --    print(UnitClassification(unitId));
        --end
    end
end

function Inspector_HideUnitInfo()
    Inspector_MainFrame_FactionTexture:Hide();
    Inspector_MainFrame_InfoBackTexture:Hide();
    Inspector_MainFrame_NameString:Hide();
    Inspector_MainFrame_LevelString:Hide();
    Inspector_MainFrame_GuildString:Hide();

    Inspector_HideAverageItemLevel();

    Inspector_MainFrame_ClassTexture:Hide();
    Inspector_MainFrame_ClassBack:Hide();
    Inspector_MainFrame_ClassString:Hide();

    Inspector_MainFrame_RaceTexture:Hide();
    Inspector_MainFrame_RaceBack:Hide();
    Inspector_MainFrame_RaceString:Hide();

    Inspector_MainFrame_NpcBack:Hide();
    Inspector_MainFrame_NpcString:Hide();
end

--------------------------------------------------------------
-- 대상("target")의 아이템 목록을 서버에서 제대로 가져왔는 지 체크
-- http://us.battle.net/forums/en/wow/topic/13569416912
--------------------------------------------------------------
function Inspector_InspectReady()
    Inspector:UnregisterEvent("INSPECT_READY");
    continueInspecting = false;

    -- first make sure all links are valid (cached)
    -- trying to get a link will cache it, so we check all slots
    for i, v in ipairs(slots) do
        local itemId = GetInventoryItemID(unitId, i);
        if (itemId) then
            if (not GetItemInfo(itemId)) then
                continueInspecting = true;
                return; -- if any links were missing, come back next frame and try again
            end
        end

        local itemLink = GetInventoryItemLink(unitId, i);
        if (itemLink) then
            if (not GetItemInfo(itemLink)) then
                continueInspecting = true;
                return; -- if any links were missing, come back next frame and try again
            end
        end
    end

    Inspector_RenderInventory();
end

function Inspector_ShowInventory()
    Inspector_InventoryFrameLeft:Show();
    Inspector_InventoryFrameRight:Show();

    Inspector_ShowAverageItemLevel();

    if (frameChanging) then
        Inspector_RenderInventory();
    else
        -- Loading...
        Inspector_InventoryFrameLeft_LoadingString:Show();
        Inspector_InventoryFrameRight_LoadingString:Show();

        NotifyInspect(unitId); -- Server is queried for inspection
        Inspector:RegisterEvent("INSPECT_READY");
    end
end

function Inspector_RenderInventory()
    Inspector_InventoryFrameLeft_LoadingString:Hide();
    Inspector_InventoryFrameRight_LoadingString:Hide();

    Inspector_BlizzardInspectTexture:Show();
    Inspector_BlizzardInspectButton:Show();

    if (frameChanging == false) then
        averageLevelSum = 0;
        averageLevelCount = 0;
    end

    local parent;
    local itemW = (frameSize == "small") and 25 or 35;
    local itemH = itemW;
    local itemY = 15;
    local itemMargin = 3;
    local itemOffset = (frameSize == "small") and 21 or 27;
    local stringH = 20;
    local nameW = Inspector_InventoryFrameLeft:GetWidth() - 25;
    local nameY = -itemH;
    local levelW = 30;
    local levelY = (frameSize == "small") and 0 or 4;
    local transLevelY = (frameSize == "small") and 0 or -4;
    local transOverayScale = (frameSize == "small") and 0.5 or 0.5;
    local transOverlayPoint = "LEFT";
    local transOverlayAnchor = "LEFT";

    for i, v in ipairs(slots) do
        local slotId, slotTexture, checkRelic = GetInventorySlotInfo(v);

        local point = "TOPRIGHT";
        local anchor = "TOPRIGHT";
        local itemX = 15;
        local nameX = 0;
        local levelX = itemMargin;
        local levelPoint = "BOTTOMRIGHT";
        local levelAnchor = "BOTTOMLEFT";
        local transX = itemX + itemW + itemMargin;
        local transLevelPoint = "TOPRIGHT";
        local transLevelAnchor = "TOPLEFT";
        local transLevelX = itemW + (itemMargin * 2);
        local justifyH = "RIGHT";

        if (i <= 8) then
            parent = Inspector_InventoryFrameLeft; -- UIParent; (전체 화면으로 보여 줄 때)
            itemX = -itemX;
            nameX = -nameX;
            levelX = -levelX;
            transX = -transX;
            transLevelX = -transLevelX;
        else
            parent = Inspector_InventoryFrameRight; -- UIParent; (전체 화면으로 보여 줄 때)
            point = "TOPLEFT";
            anchor = "TOPLEFT";
            justifyH = "LEFT";
            levelPoint = "BOTTOMLEFT";
            levelAnchor = "BOTTOMRIGHT";
            transLevelPoint = "TOPLEFT";
            transLevelAnchor = "TOPRIGHT";
            transOverlayPoint = "RIGHT";
            transOverlayAnchor = "RIGHT";
            justifyH = "LEFT";

            if (i == 9) then -- 오픈쪽 첫번째 아이템
                itemY = 15;
            end
        end

        local item = items[i];

        if (item == nil) then
            item = CreateFrame("frame", nil, parent); -- 착용 아이템

            item.icon = item:CreateTexture();
            item.icon:SetTexture(slotTexture);
            item.icon:SetAllPoints(item);

            item.name = item:CreateFontString(nil, "OVERLAY", "GameFontNormal");
            item.name:SetParent(item);
            item.name:SetSize(nameW, stringH);
            item.name:SetJustifyH(justifyH);
            item.name:SetWordWrap(false);

            item.level = item:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall");
            item.level:SetParent(item);
            item.level:SetJustifyH(justifyH);
            item.level:SetTextColor(1, 1, 0.2, 1); -- yellow

            item.trans = CreateFrame("frame", nil, parent); -- 형상변환 아이템
            item.trans.exist = false;

            item.trans.icon = item.trans:CreateTexture(nil, "BACKGROUND");
            item.trans.icon:SetAllPoints(item.trans);
            item.trans.icon:SetTexture(slotTexture);

            item.trans.overlay = item.trans:CreateTexture(nil, "OVERLAY"); -- 형상변환 아이템 위에 표시되는 도트 아이콘
            item.trans.overlay:SetSize(itemW * transOverayScale, itemH * transOverayScale);
            item.trans.overlay:SetPoint(transOverlayPoint, item.trans, transOverlayAnchor, 0, 0);
            item.trans.overlay:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon");

            item.trans.level = item.trans:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); -- 아이템 레벨
            item.trans.level:SetParent(item.trans);
            item.trans.level:SetJustifyH(justifyH);
            item.trans.level:SetTextColor(1, 0.2, 1, 1); -- pink

            items[i] = item;
        else
            if (frameChanging == false) then
                item.trans.exist = false;
            end

            if (frameChanging == false) then
                item:SetScript("OnEnter", nil);
                item:SetScript("OnLeave", nil);
                item.icon:SetTexture(slotTexture);
                item.name:SetText("");
                item.level:SetText("");
            end
            item:Show();

            if (frameChanging == false) then
                item.trans:SetScript("OnEnter", nil);
                item.trans:SetScript("OnLeave", nil);
                item.trans.icon:SetTexture(slotTexture);
                item.trans.level:SetText("");
            end
        end

        item:SetWidth(itemW);
        item:SetHeight(itemH);
        item:SetPoint(point, itemX, -itemY);
        item.name:SetPoint(point, item, anchor, nameX, nameY);

        -- 아이템 레벨 위치
        if (item.trans.exist) then
            local newLevelX = itemW + (itemMargin * 2);
            if (i <= 8) then
                newLevelX = -newLevelX;
            end
            item.level:SetPoint(levelPoint, item, levelAnchor, newLevelX, levelY);
            item.trans:Show();
        else
            item.level:SetPoint(levelPoint, item, levelAnchor, levelX, levelY);
            item.trans:Hide();
        end

        item.trans:SetWidth(itemW);
        item.trans:SetHeight(itemH);
        item.trans:SetPoint(point, transX, -itemY);
        item.trans.level:SetPoint(transLevelPoint, item, transLevelAnchor, transLevelX, transLevelY);

        if (slotId and frameChanging == false) then
            -- http://us.battle.net/forums/en/wow/topic/13569416912
            -- http://wowprogramming.com/docs/api/GetItemInfo
            local scanLevel;
            local lName, lLink, lQuality, lLevel, lReqLevel, lClass, lSubclass, lMaxStack, lSlot, lTexture, lVendorPrice;
            local iName, iLink, iQuality, iLevel, iReqLevel, iClass, iSubclass, iMaxStack, iSlot, iTexture, iVendorPrice;

            local itemLink = GetInventoryItemLink(unitId, slotId);
            local itemId = GetInventoryItemID(unitId, slotId);

            if (itemLink) then
                lName, lLink, lQuality, lLevel, lReqLevel, lClass, lSubclass, lMaxStack, lSlot, lTexture, lVendorPrice = GetItemInfo(itemLink);
                scanLevel = Inspector_ScanItemLevel(itemLink);

                itemLink = itemLink:gsub("[\[]", "");
                itemLink = itemLink:gsub("[\]]", "");
                item.name:SetText(itemLink);
                item.level:SetText(scanLevel);
                item.icon:SetTexture(lTexture);

                item:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT");
                    GameTooltip:SetHyperlink(itemLink);
                    GameTooltip:Show();
                end);
                item:SetScript("OnLeave", function(self)
                    GameTooltip:Hide();
                end);

                if (v == "MainHandSlot") then
                    if (lSlot == "INVTYPE_2HWEAPON" or lSlot == "INVTYPE_RANGED" or lSlot == "INVTYPE_RANGEDRIGHT") then
                        isTwoHandWeapon = true;
                    end
                    mainHandLink = itemLink;
                elseif (v == "SecondaryHandSlot") then
                    secondaryHandLink = itemLink;
                end

                if (lQuality == 6) then
                    -- 유물 무기의 경우 평균 값 계산할 때는 MainHand와 SecondaryHand의 레벨 중에 높은 사용한다.
                    isArtifactWeapon = true;
                elseif (v ~= "ShirtSlot" and v ~= "TabardSlot" and v ~= "MainHandSlot" and v ~= "SecondaryHandSlot") then
                    -- 셔츠와 휘장은 제외 (무기는 아이템 정보를 한번 더 업데이트 받기 위해 제외)
                    averageLevelSum = averageLevelSum + scanLevel;
                    averageLevelCount = averageLevelCount + 1;
                end
                item.trans.exist = true;
            end

            if (itemId) then
                iName, iLink, iQuality, iLevel, iReqLevel, iClass, iSubclass, iMaxStack, iSlot, iTexture, iVendorPrice = GetItemInfo(itemId);
                --print(i..": "..iLink.."("..iLevel..")");

                if (iLink and iName ~= lName and iTexture ~= lTexture) then
                    iLevel = Inspector_ScanItemLevel(iLink);
                    item.trans.level:SetText(iLevel);
                    item.trans.icon:SetTexture(iTexture);

                    item.trans:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT"); --"ANCHOR_CURSOR");
                        GameTooltip:SetHyperlink(iLink);
                        GameTooltip:Show();
                    end);
                    item.trans:SetScript("OnLeave", function(self)
                        GameTooltip:Hide();
                    end);
                else
                    -----------------------------------
                    -- 착용 아이템과 형상변환 아이템이 같은 경우
                    -----------------------------------
                    item.trans.exist = false;
                end
            end

            if (item.trans.exist) then
                local newLevelX = itemW + (itemMargin * 2);
                if (i <= 8) then
                    newLevelX = -newLevelX;
                end
                item.level:SetPoint(levelPoint, item, levelAnchor, newLevelX, levelY); -- 아이템 레벨 위치 변경

                item.trans:Show();
            else
                item.trans:Hide();
            end
        end

        itemY = itemY + itemH + itemOffset;
    end

    ---------------------------------------------------------------------------------------
    -- 인스펙터 창을 열었을 때 무기(MainHandSlot, SecondaryHandSlot)의 레벨이 정확히 표시되지 않는다.
    -- 그런데 툴팁에는 제대로 표시된다. 또한 창을 닫고 바로 다시 열면 제대로 표시된다. 흠...
    -- 아무래도 서버로부터 데이터를 제대로 가져오지 못하는 것 같아서 다시 한번 출력하는 로직을 실행시킨다.
    -- 다시 실행시키니 정상적으로 표시된다. 2016-09-26
    ---------------------------------------------------------------------------------------
    Inspector_UpdateHandsSlot();
end

function Inspector_UpdateHandsSlot()
    if (frameChanging == false) then
        handsSlotInspecting = true;
        NotifyInspect(unitId); -- Server is queried for inspection
        Inspector:RegisterEvent("INSPECT_READY");
    else
        Inspector_InspectHansSlotReady();
    end
end

function Inspector_InspectHansSlotReady()
    if (frameChanging == false) then
        Inspector:UnregisterEvent("INSPECT_READY");
        handsSlotInspecting = false;

        local mainHandLevel = 0;
        local secondHandLevel = 0;

        if (mainHandLink) then
            mainHandLevel = Inspector_ScanItemLevel(mainHandLink);
            items[17].level:SetText(mainHandLevel);
        end
        if (secondaryHandLink) then
            secondHandLevel = Inspector_ScanItemLevel(secondaryHandLink);
            items[18].level:SetText(secondHandLevel);
        end

        if (isArtifactWeapon) then
            -- 유물 무기를 장착한 경우 MainHand와 SecondaryHand의 레벨 값이 다를 수 있지만
            -- 평균값 계산할 때는 둘 중에 높은 값을 사용해서 계산한다.
            local level = mainHandLevel;
            if (secondHandLevel > mainHandLevel) then
                level = secondHandLevel;
            end
            averageLevelSum = averageLevelSum + (level * 2);
            averageLevelCount = averageLevelCount + 2;
        else
            if (mainHandLink) then
                averageLevelSum = averageLevelSum + mainHandLevel;
                averageLevelCount = averageLevelCount + 1;

                if (isTwoHandWeapon and secondaryHandLink == nil) then -- 양손무기
                    averageLevelSum = averageLevelSum + mainHandLevel;
                    averageLevelCount = averageLevelCount + 1;
                end
            end
            if (secondaryHandLink) then
                averageLevelSum = averageLevelSum + secondHandLevel;
                averageLevelCount = averageLevelCount + 1;
            end
        end
    end

    local averageLevel = 0;
    if (unitId == "player" or UnitIsUnit(unitId, "player")) then
        local overall, equipped = GetAverageItemLevel();
        averageLevel = overall;
    else
        --print("1. "..averageLevelSum.." / "..averageLevelCount.." = "..(averageLevelSum / averageLevelCount));
        averageLevel = averageLevelSum / averageLevelCount;
    end

    local averageItemText = string.format("%.1f", averageLevel);
    Inspector_MainFrame_AverageString:SetText(averageItemText);

    mainHandLink = nil;
    secondaryHandLink = nil;
    isTwoHandWeapon = false;
    isArtifactWeapon = false;

    -- 창 전환 시 다시 사용하기 위해 초기화하지 않음
    --averageLevelSum = 0;
    --averageLevelCount = 0;

    frameChanging = false;
end

function Inspector_HideInventory()
    local count = table.getn(items);
    if (count > 0) then
        for i, v in ipairs(slots) do
            items[i]:Hide();
            items[i].trans:Hide();
        end
    end

    Inspector_InventoryFrameLeft:Hide();
    Inspector_InventoryFrameRight:Hide();

    -- 블리자드 살펴보기 버튼
    Inspector_BlizzardInspectTexture:Hide();
    Inspector_BlizzardInspectButton:Hide();

    -- 평균 아이템 레벨
    Inspector_HideAverageItemLevel();
end

function Inspector_ScanItemLevel(itemLink)
    --local tooltip = Inspector_GameTooltip;
    --if (not tooltip) then
    local tooltip = CreateFrame("GameTooltip", "Inspector_GameTooltip", nil, "GameTooltipTemplate");
    --end
    tooltip:SetOwner(UIParent, "ANCHOR_NONE");
    tooltip:SetHyperlink(itemLink);
    tooltip:Show();

    local itemLevel = 0;
    for i = 2, tooltip:NumLines() do
        local text = _G[tooltip:GetName().."TextLeft"..i]:GetText();
        if (text) then
            local value = tonumber(text:match(ITEM_LEVEL:gsub("%%d", "(%%d+)")));
            if (value) then
                itemLevel = value;
                break;
            end
        end
    end
    tooltip:Hide();
    return itemLevel;
end

function Inspector_ShowAverageItemLevel()
    Inspector_MainFrame_AverageBack:Show();
    Inspector_MainFrame_AverageBorder:Show();
    Inspector_MainFrame_AverageIcon:Show();
    Inspector_MainFrame_AverageString:SetText("");
    Inspector_MainFrame_AverageString:Show();
end

function Inspector_HideAverageItemLevel()
    Inspector_MainFrame_AverageBack:Hide();
    Inspector_MainFrame_AverageBorder:Hide();
    Inspector_MainFrame_AverageIcon:Hide();
    Inspector_MainFrame_AverageString:SetText("");
    Inspector_MainFrame_AverageString:Hide();
end

function Inspector_StartAnimation()
    local model = Inspector_PlayerModel;
    model:SetAnimation(26, 0); -- attack stance
end

function Inspector_StopAnimation()
    local model = Inspector_PlayerModel;
    model:SetAnimation(0, 0); -- idle
end

function Inspector_ShowBackground()
    local frame = Inspector_MainFrame;
    local max = table.getn(blps);
    local key = math.random (1, max);
    backdrop.bgFile = "Interface\\Glues\\LoadingScreens\\"..blps[key];
    --backdrop.bgFile = "Interface\\AddOns\\Inspector\\Textures\\Druid_Background.tga";
    backdrop.title = false;
    frame:SetBackdrop(backdrop);
end

function Inspector_HideBackground()
    local frame = Inspector_MainFrame;
    backdrop.bgFile = backNone;
    backdrop.title = true;
    frame:SetBackdrop(backdrop);
    frame:SetBackdropColor(0, 0, 0, 0.7);
end

function BlizzardInspectUI_Show()
    if CanInspect(unitId) then --and CheckInteractDistance(unitId, 1) then
        InspectUnit(unitId);
    end
end

function BlizzardInspectUI_Hide()
    HideUIPanel(InspectFrame);
end

-- "Config" 버튼 클릭 시
function Inspector_ConfigButton_OnClick()
    ShowUIPanel(InspectorConfig);
end

-- "Inspect" 버튼 클릭 시
function Inspector_BlizzardInspectButton_OnClick()
    if (InspectFrame and InspectFrame:IsVisible()) then
        HideUIPanel(InspectFrame);
    else
        if CanInspect(unitId) then
            InspectUnit(unitId);
        end
    end
end

function Inspector_SmallerButton_OnClick()
    local button = Inspector_SmallerButton;
    if (frameSize == "large") then
        frameSize = "small";
    else
        frameSize = "large";
    end
    Inspector_UpdateSizingUI();
    Inspector_SaveVariables();

    frameChanging = true;

    Inspector_Hide();
    Inspector_Show();
end

function Inspector_UpdateSizingUI()
    local factionSize = 104;
    local averageBorder = 128;
    local textureSize = 150;
    local button = Inspector_SmallerButton;
    if (frameSize == "small") then
        button:SetNormalTexture("Interface\\BUTTONS\\UI-Panel-BiggerButton-Up");
        button:SetPushedTexture("Interface\\BUTTONS\\UI-Panel-BiggerButton-Down");
        factionSize = 80;
        averageBorder = 115;
        textureSize = 120;
    else
        button:SetNormalTexture("Interface\\BUTTONS\\UI-Panel-SmallerButton-Up");
        button:SetPushedTexture("Interface\\BUTTONS\\UI-Panel-SmallerButton-Down");
    end
    Inspector_MainFrame_FactionTexture:SetSize(factionSize, factionSize);
    Inspector_MainFrame_AverageBorder:SetSize(averageBorder, averageBorder);
    Inspector_MainFrame_ClassTexture:SetSize(textureSize, textureSize);
    Inspector_MainFrame_RaceTexture:SetSize(textureSize, textureSize);
end

-- "Close" 버튼 클릭 시
function Inspector_CloseButton_OnClick()
    Inspector_Hide();
end

function Inspector_AddonLoaded()
    if (InspectorSettings) then
        frameSize = InspectorSettings.Inspector_FrameSize;
        if (frameSize == nil) then frameSize = "large"; end

        Inspector_AnimateChecked = InspectorSettings.Inspector_AnimateChecked;
        if (Inspector_AnimateChecked == nil) then Inspector_AnimateChecked = true; end

        Inspector_SpinChecked = InspectorSettings.Inspector_SpinChecked;
        if (Inspector_SpinChecked == nil) then Inspector_SpinChecked = true; end
        Inspector_ModelSpin = Inspector_SpinChecked;

        Inspector_BackgroundChecked = InspectorSettings.Inspector_BackgroundChecked;
        if (Inspector_BackgroundChecked == nil) then Inspector_BackgroundChecked = true; end
    end
end

function Inspector_SaveVariables()
    InspectorSettings = {
        Inspector_FrameSize = frameSize;
        Inspector_AnimateChecked = Inspector_AnimateChecked,
        Inspector_SpinChecked = Inspector_SpinChecked,
        Inspector_BackgroundChecked = Inspector_BackgroundChecked,
    }
end

-- -----------------------------------------------------------------------------------------------
-- https://us.battle.net/support/en/article/download-the-world-of-warcraft-interface-addon-kit
-- -----------------------------------------------------------------------------------------------
blps = {
"LoadScreenArgentDungeon.blp",
"LOADSCREENARGENTRAID.BLP",
"LOADSCREENAUCHINDOUN.BLP",
"LOADSCREENAZJOLNERUB76.BLP",
"LoadScreenAzjolUpperCity.blp",
"LoadScreenBaradinHold.blp",
"LoadScreenBlackrockCaverns.blp",
"LoadScreenBlackrockDepths.blp",
"LoadScreenBlackwingDescentRaid.blp",
"LoadScreenBlackWingLair.blp",
"LoadScreenBladesEdgeArena.blp",
"LoadScreenCave.blp",
"LOADSCREENCAVERNSTIME.BLP",
"LoadScreenChamberBlack.blp",
"LoadScreenChampionsHall.blp",
"LoadScreenDalaranPrison.blp",
"LoadScreenDalaranSewersArena.blp",
"LoadScreenDeadmines.blp",
"LOADSCREENDEATHKNIGHT.BLP",
"LoadScreenDeepholm.blp",
"LOADSCREENDEEPHOLMDUNGEON.BLP",
"LoadScreenDireMaul.blp",
"LoadScreenDrakTharon.blp",
"LoadScreenDungeon.blp",
"LoadScreenEnviroment.blp",
"LoadScreenGilneasBG.blp",
"LoadScreenGilneasBG2.blp",
"LoadScreenGnomeregan.blp",
"LOADSCREENGRIMBATOL.BLP",
"LoadScreenGrimBatolRaid.blp",
"LOADSCREENGUNDRAK.BLP",
"LoadScreenHallofLegends.blp",
"LoadScreenHallsofOrigination.blp",
"LoadScreenHallsofReflection.blp",
"LOADSCREENHELLFIRECITADEL5MAN.BLP",
"LOADSCREENHELLFIRECITADELRAID.BLP",
"LoadScreenHyjal.blp",
"LoadScreenIcecrown5man.blp",
"LoadScreenIcecrownCitadel.blp",
"LOADSCREENISLEOFCONQUEST.BLP",
"LoadScreenKarazhan.blp",
"LOADSCREENMALYGOS.BLP",
"LoadScreenMaraudon.blp",
"LoadScreenMoltenCore.blp",
"LoadScreenMonastery.blp",
"LoadScreenNagrandArenaBattlegrounds.blp",
"LoadScreenNexus70.blp",
"LoadScreenNexus80.blp",
"LoadScreenNorthrendBG.blp",
"LoadScreenOldStrathome.blp",
"LoadScreenOrgrimmarArena.blp",
"LoadScreenPitofSaron.blp",
"LoadScreenRagefireChasm.blp",
"LoadScreenRazorfenDowns.blp",
"LoadScreenRazorfenKraul.blp",
"LoadScreenRubySanctum.blp",
"LoadScreenRuinedCity.blp",
"LoadScreenRuinsofLordaeronBattlegrounds.blp",
"LoadScreenScholomance.blp",
"LOADSCREENSHADOWFANGKEEP.BLP",
"LoadScreenSkywall.blp",
"LoadScreenSkywallRaid.blp",
"LoadScreenStormwindStockade.blp",
"LoadScreenStrathome.blp",
"LoadScreenSunkenTemple.blp",
"LoadScreenSunwell5Man.blp",
"LOADSCREENTEMPESTKEEP.BLP",
"LoadScreenThroneoftheTides.blp",
"LoadScreenTolBarad.blp",
"LoadScreenTwinPeaksBG.blp",
"LOADSCREENULDAMAN.BLP",
"LoadScreenUlduar77.blp",
"LoadScreenUlduar80.blp",
"LOADSCREENULDUARRAID.BLP",
"LoadScreenUldumDungeon.blp",
"LOADSCREENUTGARDE.BLP",
"LoadScreenUtgardePinnecle.blp",
"LoadScreenWailingCaverns.blp",
"LoadScreenWintergrasp.blp",
"LOADSCREENZULAMAN.BLP",
"LoadScreenZulFarrak.blp",
"LoadScreenZulGurub.blp"
}