function TGDbg(str)
    local s = LIGHTYELLOW_FONT_COLOR_CODE.."TGDbg: "..FONT_COLOR_CODE_CLOSE..str
    DEFAULT_CHAT_FRAME:AddMessage(s)
end

function TGMsg(str)
    local s = LIGHTYELLOW_FONT_COLOR_CODE.."TGMsg: "..FONT_COLOR_CODE_CLOSE..str
    DEFAULT_CHAT_FRAME:AddMessage(s)
end

TGDbg("Hello, world!")
