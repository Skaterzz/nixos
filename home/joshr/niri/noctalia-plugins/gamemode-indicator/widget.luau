--!nonstrict

-- The GameMode bar slot: a controller pad in the accent colour while a game
-- holds gamemode, and no widget at all the rest of the time. `setVisible` is
-- only a render patch on the widget's next paint, so hiding it does not stop
-- the entry ticking — the poll below keeps running while the slot is gone.

-- Substituted at build time by home/joshr/niri/noctalia.nix, because a bare
-- `gamemode-status` is not something this can count on finding: the shell runs
-- as a systemd user service, whose PATH is the user manager's rather than the
-- one a login shell builds from the profile.
local statusCommand = "@gamemodeStatus@"

local checking = false
local active = false

local function render()
    barWidget.setGlyph("device-gamepad-2")
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip("GameMode active")
    barWidget.setVisible(active)
end

local function check()
    -- One poll in flight at a time. `gamemode-status` runs pgrep and possibly
    -- a D-Bus round trip, either of which can outlast the tick interval.
    if checking then
        return
    end

    checking = true

    -- The callback is handed a CommandResult table — exitCode, stdout, stderr
    -- and the two truncation flags — not the output as a string. Trimming the
    -- table itself is what left this permanently inactive.
    --
    -- `gamemode-status` prints the pad glyph while a client holds gamemode and
    -- an empty line otherwise (it deliberately does not ask gamemoded anything
    -- unless gamemoded is already running, since the daemon is D-Bus activated
    -- and asking would start it), so any non-empty output is the answer.
    local started = noctalia.runAsync(statusCommand, function(result)
        checking = false
        active = noctalia.string.trim((result and result.stdout) or "") ~= ""
        render()
    end)

    -- A launch that never happened calls nothing back, and the guard above
    -- would then wedge the widget on whichever state it was last in.
    if not started then
        checking = false
    end
end

function update()
    noctalia.setUpdateInterval(2000)
    check()
end

render()
check()
