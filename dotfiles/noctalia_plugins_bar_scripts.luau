local COLORS = { error = "error", warn = "tertiary", unset = "on_surface_variant" }
local command = noctalia.getConfig("command") or ""
local interval = noctalia.getConfig("interval") or 60

function update()
    if command == "" then
        barWidget.setVisible(false)
        return
    end
    noctalia.setUpdateInterval(interval * 1000)
    noctalia.runAsync(command, function(result)
        local ok, payload = pcall(noctalia.json.decode, result.stdout or "")
        if result.exitCode ~= 0 or not ok or type(payload) ~= "table" or payload.text == nil then
            barWidget.setVisible(false)
            return
        end
        barWidget.setText(payload.text)
        barWidget.setTooltip(payload.tooltip or "")
        barWidget.setColor(COLORS[payload.class] or "on_surface")
        barWidget.setVisible(true)
    end)
end
