local ADDON, T = ...

-- ElvUI is optional and loads on its own schedule, so everything here is
-- resolved at runtime and stays silent when it is absent.

local function skinList()
    local list = _G.TrovekeeperListFrame
    if not list or list.__elvuiSkinned then return end
    list:StripTextures()
    list:SetTemplate("Transparent")
    -- Refresh() must stop repainting the backdrop once ElvUI owns it.
    list.__elvuiSkinned = true
end

function T.SkinElvUI()
    if T.ApplyElvUISkin then return T.ApplyElvUISkin() end
    if not _G.ElvUI then return end
    if not T.DB:Profile().elvuiSkin then return end

    local ok, E = pcall(function() return unpack(_G.ElvUI) end)
    if not ok or not E then return end
    local S = E:GetModule("Skins", true)
    if not S then return end

    local function skin()
        if not E.private or not E.private.skins or not E.private.skins.misc
           or not E.private.skins.misc.enable then
            return
        end
        skinList()
    end

    T.ApplyElvUISkin = skin

    local EP = LibStub("LibElvUIPlugin-1.0", true)
    if EP then
        EP:RegisterPlugin(ADDON, skin)
    else
        skin()
    end
end
