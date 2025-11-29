local alertStyle = {
    fillColor = { hex = "#171520", alpha = 1 },
    strokeColor = { hex = "#272131" },
    strokeWidth = 1,
    radius = 18,
    padding = 16,
    fadeInDuration = 0.1,
    fadeOutDuration = 0.15,
}

--- Shows a styled alert with icon and message
--- @param icon string The emoji/icon to display
--- @param message string The message text
local function prettyAlert(icon, message)
    local accentColor = { red = 0.4, green = 0.8, blue = 0.4, alpha = 1.0 }

    local iconStyle = {
        font = { name = ".AppleSystemUIFont", size = 16 },
        color = accentColor,
    }

    local messageStyle = {
        font = { name = ".AppleSystemUIFont", size = 16 },
        color = { white = 0.95, alpha = 1.0 },
    }

    local styledIcon = hs.styledtext.new(icon .. "  ", iconStyle)
    local styledMessage = hs.styledtext.new(message, messageStyle)
    local styledText = styledIcon .. styledMessage

    hs.alert.show(styledText, alertStyle, nil, 1.5)
end

return prettyAlert
