--[[
    CombatHitFX — the ONE path that turns a landed combat swing into its attack visual, shared by
    pets (PetFollowController, off Combat_PetHit) and enemies (EnemyMotion, off Combat_EnemyHit).

    Pets and enemies attack the same way (Jason: "enemy actions and pet actions should be largely
    the same... one code path if possible"), so "how a swing looks" lives here, not duplicated per
    actor: decide the projectile/impact KIND, then fire it origin->target through the shared RangedFX
    engine. Melee -> an impact at the target; ranged -> a themed travelling bolt. The per-actor bits
    that are NOT "how they attack" stay in each handler: a pet's floating damage number + ranged
    cast-lock, the target's hit-react, the network payload shape.

    resolveKind is pure (no Roblox deps) so the choice is one tested rule for both actors; RangedFX
    is lazy-required inside play() so this module can be required headlessly to test resolveKind.
]]

local CombatHitFX = {}

-- Pick the kind for a swing. Melee -> "melee" (impact at the target). Ranged resolves, in order:
-- an explicit kind (enemy bolt_kind, or a pet by_type override passed as kind) -> the by_type map
-- (pet PetType) -> the element map (pet biome element) -> the config default. Pure.
function CombatHitFX.resolveKind(opts)
    if not opts.ranged then
        return "melee"
    end
    if opts.kind and opts.kind ~= "" then
        return opts.kind
    end
    if opts.byType and opts.byTypeMap and opts.byTypeMap[opts.byType] then
        return opts.byTypeMap[opts.byType]
    end
    if opts.element and opts.elementKind and opts.elementKind[opts.element] then
        return opts.elementKind[opts.element]
    end
    return opts.defaultKind or "lightning"
end

-- Fire the swing's visual: resolve the kind, then play it attacker->target via the shared engine.
-- `opts.boltCfg` is the ranged_bolt config (projectile themes + melee look); `opts.element` lets
-- the engine pick the per-biome melee/impact skin.
function CombatHitFX.play(attacker, target, opts)
    local RangedFX = require(script.Parent.RangedFX) -- lazy: keeps resolveKind headless-testable
    local kind = CombatHitFX.resolveKind(opts)
    RangedFX.Play(attacker, opts.boltCfg, target, kind, opts.crit == true, opts.element)
end

return CombatHitFX
