local modSymbols = {
    cmd = "⌘",
    command = "⌘",
    ctrl = "⌃",
    control = "⌃",
    alt = "⌥",
    option = "⌥",
    shift = "⇧",
}

--- @param mods table
--- @param key string
--- @return string
local function formatHotkey(mods, key)
    local result = ""
    for _, mod in ipairs(mods) do
        result = result .. (modSymbols[mod] or mod)
    end
    return result .. string.upper(key)
end


return formatHotkey