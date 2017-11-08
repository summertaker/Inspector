
function InspectorConfig_OnLoad()
	-- 다국어 처리
    InspectorConfig_HeaderString:SetText(" "..L["Config"]);
    InspectorConfig_AnimateCheckButtonText:SetText(" "..L["Animation"]);
    InspectorConfig_SpinCheckButtonText:SetText(" "..L["Spin"]);
    InspectorConfig_BackgroundCheckButtonText:SetText(" "..L["Background"]);
    InspectorConfig_CloseButton:SetText(L["Close"]);
end

function InspectorConfig_OnShow()
    InspectorConfig_AnimateCheckButton:SetChecked(Inspector_AnimateChecked);
    InspectorConfig_SpinCheckButton:SetChecked(Inspector_SpinChecked);
    InspectorConfig_BackgroundCheckButton:SetChecked(Inspector_BackgroundChecked);
end

----------------------------------
-- CheckButton: Animate
----------------------------------
function InspectorConfig_AnimateCheckButton_OnClick()
    if InspectorConfig_AnimateCheckButton:GetChecked() then
        Inspector_AnimateChecked = true;
        Inspector_StartAnimation();
    else
        Inspector_AnimateChecked = false;
        Inspector_StopAnimation();
    end

end

----------------------------------
-- CheckButton: Spin
----------------------------------
function InspectorConfig_SpinCheckButton_OnClick()
    if InspectorConfig_SpinCheckButton:GetChecked() then
        Inspector_SpinChecked = true;
        Inspector_ModelSpin = true;
    else
        Inspector_SpinChecked = false;
        Inspector_ModelSpin = false;
    end
end

----------------------------------
-- CheckButton: Background
----------------------------------
function InspectorConfig_BackgroundCheckButton_OnClick()
    if InspectorConfig_BackgroundCheckButton:GetChecked() then
        Inspector_BackgroundChecked = true;
        Inspector_ShowBackground();
    else
        Inspector_BackgroundChecked = false;
        Inspector_HideBackground();
    end
end

----------------------------------
-- Button: Close
----------------------------------
function InspectorConfig_CloseButton_OnClick()
    HideUIPanel(InspectorConfig);
end

function InspectorConfig_OnHide()
	Inspector_SaveVariables();
end

function InspectorConfig_OnMouseDown()

end

function InspectorConfig_OnMouseUp()

end
