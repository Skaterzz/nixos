--!nonstrict

local checking = false
local active = false

local function render()
    barWidget.setGlyph("device-gamepad-2")
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip("GameMode active")
    barWidget.setVisible(active)
end

local function check()
    if checking then
        return
    end

    checking = true
    noctalia.runAsync(
        [[if [ -n "$(gamemode-status)" ] || pgrep -u "$(id -u)" -f '(^|/)gamemoderun([[:space:]]|$)' >/dev/null; then printf active; fi]],
        function(output)
            checking = false
            active = noctalia.string.trim(output or "") == "active"
            render()
        end
    )
end

function update()
    noctalia.setUpdateInterval(2000)
    check()
end

render()
check()
