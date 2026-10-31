local ADDON, T = ...

T.L = setmetatable({}, {
    __index = function(_, key) return key end,
})
