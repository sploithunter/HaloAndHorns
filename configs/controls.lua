--[[
    Controls / keybinds — Halo & Horns [PROTOTYPE].

    Player input bindings, config-assignable so they can be rebound without code
    changes (and, later, surfaced in a Settings rebind UI). Key names are
    Enum.KeyCode names (e.g. "Tab", "Q", "E", "R", "F"); an unknown name falls back
    to the documented default. Read client-side by the input systems.
]]

return {
    keybinds = {
        -- Cycle the SELECTED squad pet in the right-side HUD. Hold Shift to cycle
        -- backward. Selecting a pet is what routes Recall/Summon (and, later, support
        -- powers) at it. (Tab gets swallowed by Roblox GUI navigation — using Q.)
        squad_cycle = "Q",

        -- Cycle the ASSIST target through nearby ENEMIES (Z), so you can direct the squad
        -- to focus one (e.g. the healer first). Hold Shift to cycle backward. Pressing it
        -- with no enemy in range clears the assist.
        enemy_cycle = "Z",
    },

    -- Z-cycle scope. By default it only steps through real enemies that need attention;
    -- set include_mining = true to also cycle plain mining targets (ore/breakables).
    enemy_cycle = {
        range = 80,
        include_mining = false,
    },
}
