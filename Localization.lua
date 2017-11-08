INSPECTOR_L = GetLocale() == "koKR" and {
	["Inspector"] = "인스펙터",
	["Loading..."] = "로드 중...",
	["Config"] = "설정",
	["Close"] = "닫기",
	["Inspect"] = "살펴보기",
	["Animation"] = "애니메이션",
	["Spin"] = "회전",
	["Background"] = "배경",
	["If it takes a long time to load, please close and open the window again."] = "로드하는 시간이 오래 걸리면 창을 닫았다가 다시 열어주세요."
--[[
} or GetLocale() == "zhCN" and {
	["Inspector"] = "인스펙터",
	["Close"] = "닫기",
]]--
} or { }

setmetatable(INSPECTOR_L, {__index = function(self, key) rawset(self, key, key); return key; end})