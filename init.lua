--- === WindowStrider ===
---
--- Keyboard-driven window switcher that cycles through windows of specified applications.
---

local obj = {}
obj.__index = obj

obj.name = "WindowStrider"
obj.version = "1.0"
obj.author = "Dubzer"
obj.license = "MIT"

local log = hs.logger.new("WindowStrider")
local prettyAlert = dofile(hs.spoons.resourcePath("prettyAlert.lua"))

local tinsert, tsort = table.insert, table.sort

local modSymbols = {
    cmd = "⌘", command = "⌘",
    ctrl = "⌃", control = "⌃",
    alt = "⌥", option = "⌥",
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

-- keep references to listeners to avoid getting garbage collected
local _keep = {}
---@generic T
---@param it T
---@return T
local function keep(it)
    tinsert(_keep, it)
    return it
end

local function wf_getWindowList(self, reverse)
    local r = {}
    for window, _ in pairs(self.windows) do
        tinsert(r, window)
    end
    if reverse then
        tsort(r, function(a, b)
            return a.timeFocused < b.timeFocused
        end)
    else
        tsort(r, function(a, b)
            return a.timeFocused > b.timeFocused
        end)
    end
    return r
end

---@class CycleState
---@field visited table<number, boolean> @Set-like table keyed by window id
---@field count integer                 @Number of windows currently in `visited`
---@field reversed boolean              @Whether the list should be traversed in reverse
local CycleState = {}
CycleState.__index = CycleState

function CycleState.new()
    ---@type CycleState
    local self = setmetatable({}, CycleState)
    self:reset()
    return self
end

function CycleState:reset()
    self.visited = {}
    self.count   = 0
    self.reversed = false
end

---@param windowId number
function CycleState:add(windowId)
    if self.visited[windowId] == nil then
        self.visited[windowId] = true
        self.count = self.count + 1
    end
end

--- @param apps table
--- @return function cycleWindows
local function createWindowSwitcher(apps)
    local filter = keep(hs.window.filter.new(function(window)
        local application = window:application()
        if not application then return false end
        local bundleID = application:bundleID()
        for _, app in ipairs(apps) do
            if bundleID == app and window:isStandard() then
                return true
            end
        end
        return false
    end))

    local cycleState = CycleState.new()

    -- force wf to populate its internal list of windows
    ---@diagnostic disable-next-line: undefined-field
    filter:keepActive()

    return function()
        local starttime = hs.timer.secondsSinceEpoch()

        local focused = hs.window.focusedWindow()
        if focused and focused:isFullScreen() then
            return
        end

        local focusedApp = focused and focused:application()
        local cycling = focusedApp and hs.fnutils.contains(apps, focusedApp:bundleID())

        local windows = wf_getWindowList(filter, cycleState.reversed)

        if cycling then
            local focusedId = focused:id()
            assert(focusedId ~= nil)

            cycleState:add(focusedId)

            -- wrap around if we've visited all windows
            if cycleState.count == #windows then
                cycleState:reset()
                cycleState:add(focusedId)
                cycleState.reversed = true
            end
        else
            cycleState:reset()
        end

        -- find first unvisited window
        for _, w in ipairs(windows) do
            if cycleState.visited[w.id] == nil then
                if not focused or w.id ~= focused:id() then
                    w.window:focus()
                end
                cycleState:add(w.id)
                break
            end
        end

        local timeTaken = hs.timer.secondsSinceEpoch() - starttime
        if timeTaken > 0.03 then
            log.d("long time taken: " .. timeTaken)
        end
    end
end

--- Binds a hotkey to switch between windows of the specified applications.
--- @param mods table The modifiers for the hotkey (e.g., {"option"})
--- @param key string The key for the hotkey (e.g., "2")
--- @param apps table A list of application bundle IDs (e.g., {"com.brave.Browser"})
function obj:bindHotkey(mods, key, apps)
    local cycleWindows = createWindowSwitcher(apps)
    keep(hs.hotkey.bind(mods, key, cycleWindows))
    return self
end

--- Binds a hotkey for dynamic app pinning.
--- When pressed with the record modifier, pins the currently focused app.
--- When pressed without, cycles through windows of the pinned app.
--- @param mods table The base modifiers for the hotkey (e.g., {"option"})
--- @param key string The key for the hotkey (e.g., "1")
--- @param recordMod string Additional modifier for recording (e.g., "shift")
function obj:bindPinHotkey(mods, key, recordMod)
    local pinnedBundleID = nil
    local cycleWindows = nil

    local recordModifiers = {}
    for _, mod in ipairs(mods) do
        tinsert(recordModifiers, mod)
    end
    tinsert(recordModifiers, recordMod)

    keep(hs.hotkey.bind(recordModifiers, key, function()
        local focused = hs.window.focusedWindow()
        if not focused then
            prettyAlert("⚠️", "No focused window to pin")
            return
        end

        local app = focused:application()
        if not app then
            log.e("focused:application() returned nil")
            return
        end

        pinnedBundleID = app:bundleID()
        cycleWindows = createWindowSwitcher({pinnedBundleID})

        prettyAlert("📌", app:name() .. " → " .. formatHotkey(mods, key))
    end))

    -- Switch hotkey: cycles through pinned app's windows
    keep(hs.hotkey.bind(mods, key, function()
        if not pinnedBundleID then
            prettyAlert("⚠️", "No app pinned")
            return
        end

        cycleWindows()
    end))

    return self
end

return obj