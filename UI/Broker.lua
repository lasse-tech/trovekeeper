local ADDON, T = ...
local L = T.L
local DB = T.DB
local Zones = T.Zones

local Broker = {}
T.Broker = Broker

local LDB = LibStub("LibDataBroker-1.1", true)
local LDBIcon = LibStub("LibDBIcon-1.0", true)

function Broker:Initialize()
    if not LDB then return end

    local object = LDB:NewDataObject(T.ADDON, {
        type = "launcher",
        icon = "Interface\\AddOns\\Trovekeeper\\Media\\Icon.png",
        label = L["Trovekeeper"],

        OnClick = function(_, button)
            if button == "RightButton" then
                T.Options:Toggle()
            else
                T.List:Toggle()
            end
        end,

        OnTooltipShow = function(tooltip)
            tooltip:AddLine(L["Trovekeeper"], 1, 0.82, 0)

            -- Twelve delves is too many to list in full, so this is the total
            -- plus whatever is still outstanding.
            local doneAll, totalAll, outstanding = 0, 0, {}
            for _, delve in ipairs(T.Delves) do
                local done, total = T.Progress:Counts(delve)
                doneAll, totalAll = doneAll + done, totalAll + total
                if total > 0 and done < total then
                    outstanding[#outstanding + 1] = { delve = delve, done = done, total = total }
                end
            end

            local colour = (totalAll > 0 and doneAll >= totalAll) and "|cff40ff40" or "|cffffd100"
            tooltip:AddDoubleLine(L["All delves"],
                colour .. format(L["%d of %d found"], doneAll, totalAll) .. "|r")

            if #outstanding > 0 then
                tooltip:AddLine(" ")
                for _, row in ipairs(outstanding) do
                    tooltip:AddDoubleLine(row.delve.name,
                        "|cffffd100" .. format(L["%d of %d found"], row.done, row.total) .. "|r")
                end
            end

            tooltip:AddLine(" ")
            tooltip:AddLine(L["Click"] .. ": " .. L["Toggle the chest list"], 0.6, 0.8, 1)
            tooltip:AddLine(L["Right-Click"] .. ": " .. L["Open options"], 0.6, 0.8, 1)
        end,
    })

    if LDBIcon then
        DB:Minimap().hide = not DB:Profile().minimapButton
        LDBIcon:Register(T.ADDON, object, DB:Minimap())
    end
end
