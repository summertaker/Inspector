local unitId = "player";

local positionX = 0;
local positionY = 0;

function InspectorMiniature_OnLoad(self)
    local frame = InspectorMiniature;

    --frame:RegisterEvent("VARIABLES_LOADED");
    --frame:RegisterEvent("PLAYER_LOGIN");
    frame:RegisterEvent("PLAYER_TARGET_CHANGED");
    frame:RegisterForDrag("LeftButton"); --, "RightButton");

    frame:SetScript("OnEvent", InspectorMiniature_OnEvent);
    --frame:SetScript("OnUpdate", InspectorMiniature_OnUpdate);
    --frame:SetScript("OnMouseDown", InspectorMiniature_OnMouseDown);
    --frame:SetScript("OnMouseUp", InspectorMiniature_OnMouseUp);
    --frame:SetScript("OnMouseWheel", InspectorMiniature_OnMouseWheel);
    frame:SetScript("OnDragStart", InspectorMiniature_OnDragStart);
    frame:SetScript("OnDragStop", InspectorMiniature_OnDragStop);
    --frame:SetScript("OnHide", Inspector_OnHide);
end

function InspectorMiniature_OnEvent(self, event, ...)
    --print(event);
    --if (event == "VARIABLES_LOADED") then
        --InspectorMiniature_OnVariablesLoaded();
    if (event == "PLAYER_LOGIN") then
        --InspectorMiniature_TargetChanged();
    elseif (event == "PLAYER_TARGET_CHANGED") then
        InspectorMiniature_TargetChanged();
    end
end

function InspectorMiniature_OnUpdate(self, elapsed)
    -------------------------------
    -- Update Model Rotation.
    -------------------------------
    if (unitId == nil or unitId == "player") then
        return;
    end

    local model = MiniatureFrame_TargetModel;
    local facing = model:GetFacing();
    facing = facing + elapsed;
    model:SetFacing(facing);

    -- http://wowwiki.wikia.com/wiki/Using_OnUpdate_correctly
    animationSinceLastUpdate = animationSinceLastUpdate + elapsed;
    if (animationSinceLastUpdate > animationUpdateInterval) then
        local max = table.getn(animations);
        animationIndex = animationIndex + 1;
        if (animationIndex > max) then
            animationIndex = 1;
        end
        --model:SetAnimation(animations[animationIndex], 0);
        animationSinceLastUpdate = 0.0;
    end
end

function InspectorMiniature_OnDragStart()
    InspectorMiniature:StartMoving();
end

function InspectorMiniature_OnDragStop()
    InspectorMiniature:StopMovingOrSizing();
    positionX, positionY = GetCursorPosition();
    --InspectorMiniature_SaveVariables();
end

function InspectorMiniature_TargetChanged()
    if (UnitExists("target")) then
        unitId = "target";
    else
        unitId = nil; --"player";
    end

    local frame = InspectorMiniature;
    if (unitId ~= nil) then
        -- https://us.battle.net/forums/en/wow/topic/18300011311
        local model = InspectorMiniature_PlayerModel;
        model:SetUnit(unitId);
        model:RefreshUnit();

        local name, realm = UnitName(unitId);
        InspectorMiniature_NameButton:SetText(name);
        --if (CanInspect(unitId)) then
        --    InspectorMiniature_NameButton:Enable();
        --else
        --    InspectorMiniature_NameButton:Disable();
        --end
        frame:Show();
    else
        frame:Hide();
    end
end

function InspectorMiniature_NameButton_OnClick()
    Inspector_Inspect_OnPress();

    --if (InspectFrame ~= nil and InspectFrame:IsVisible()) then
    --    InspectFrame:Hide();
    --else
    --    InspectUnit(targetid);
    --end
end

function InspectorMiniature_OnVariablesLoaded()
    if (InspectorSettings ~= nil) then
        if (InspectorSettings.InspectorMiniature_PositionX == nil) then
            positionX = InspectorSettings.InspectorMiniature_PositionX;
        end
        if (InspectorSettings.InspectorMiniature_PositionY == nil) then
            positionY = InspectorSettings.InspectorMiniature_PositionY;
        end
    end
    InspectorMiniature:SetPoint("CENTER", "UIParent", "CENTER", positionX, positionY);
end

function InspectorMiniature_SaveVariables()
    InspectorSettings = {
        InspectorMiniature_PositionX = positionX,
        InspectorMiniature_PositionY = positionY
    }
end
