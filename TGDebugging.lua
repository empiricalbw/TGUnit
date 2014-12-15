function TGDbg(str)
    local s = LIGHTYELLOW_FONT_COLOR_CODE.."TGDbg: "..FONT_COLOR_CODE_CLOSE..str
    DEFAULT_CHAT_FRAME:AddMessage(s)
end

TGDbg("Hello, world!")

local function TGDbg_Slash(str)
    local f = loadstring("return "..str)
    TGDbg(tostring(f()))
end

SlashCmdList["TGUF3DBG"] = TGDbg_Slash
SLASH_TGUF3DBG1 = "/tg"
