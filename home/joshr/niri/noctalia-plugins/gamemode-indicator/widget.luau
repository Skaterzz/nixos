--!nonstrict

-- The GameMode bar slot: a controller pad in the accent colour while the
-- session is in GameMode, and no widget at all the rest of the time.
-- `setVisible` is only a render patch on the widget's next paint, so hiding it
-- does not stop the entry ticking — the poll below keeps running while the
-- slot is gone.

-- Substituted at build time by home/joshr/niri/noctalia.nix, because a bare
-- `niri-gamemode` is not something this can count on finding: the shell runs
-- as a systemd user service, whose PATH is the user manager's rather than the
-- one a login shell builds from the profile.
local statusCommand = "@niriGamemode@ status"

local checking = false
local active = false
local tooltip = ""

local function render()
    barWidget.setGlyph("device-gamepad-2")
    barWidget.setGlyphColor("primary")
    barWidget.setTooltip(tooltip)
    barWidget.setVisible(active)
end

local function check()
    -- One poll in flight at a time. `niri-gamemode status` stats a file and
    -- may fall through to pgrep and a D-Bus round trip, either of which can
    -- outlast the tick interval.
    if checking then
        return
    end

    checking = true

    -- The callback is handed a CommandResult table — exitCode, stdout, stderr
    -- and the two truncation flags — not the output as a string. Trimming the
    -- table itself is what left this permanently inactive.
    --
    -- `niri-gamemode status` prints exactly one of four words. The tooltip is
    -- the only place the three lit states are told apart, and it is worth
    -- telling them apart: a pad that appeared because a game started goes away
    -- on its own, one that appeared because Mod+G was pressed does not, and
    -- `daemon` means gamemode is engaged system-side while the session itself
    -- is *not* stripped back — which is what a Mod+G pressed mid-game leaves
    -- behind.
    local started = noctalia.runAsync(statusCommand, function(result)
        checking = false

        local state = noctalia.string.trim((result and result.stdout) or "")
        if state == "game" then
            active = true
            tooltip = "GameMode — a game is holding it"
        elseif state == "manual" then
            active = true
            tooltip = "GameMode — on by hand · Mod+G to leave"
        elseif state == "daemon" then
            active = true
            tooltip = "A game holds gamemode · session effects off"
        else
            active = false
            tooltip = ""
        end

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
