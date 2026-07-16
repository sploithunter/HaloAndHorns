local ConfigSchemas = {}

local SCHEMA_REVISION = 1

local function schema(required)
    return {
        revision = SCHEMA_REVISION,
        policy = "required_keys_allow_extensions",
        required = required,
    }
end

local SCHEMAS = {
    admins = schema({ authorizedUsers = "table", permissions = "table", security = "table" }),
    archetypes = schema({ respec_cost = "table", generic_pool = "table", archetypes = "table" }),
    area_fx = schema({ self = "table", targeted = "table", themes = "table" }),
    augmentation = schema({
        slot_grant_levels = "table",
        slots_per_grant = "number",
        slot_types = "table",
    }),
    biomes = schema({ order = "table", biomes = "table" }),
    flora = schema({ layers = "table", realms = "table" }),
    boot = schema({ milestones = "table", player_gates = "table", phases = "table" }),
    buff_auras = schema({ poll_interval = "number", auras = "table" }),
    buffs = schema({ axes = "table", default_cap = "number" }),
    build_info = schema({ version = "string", commit = "string", branch = "string" }),
    combat = schema({ auto_target = "string", group_scaling = "table" }),
    combat_fx = schema({ origin = "table", reskins = "table", attached = "table" }),
    controls = schema({ keybinds = "table", enemy_cycle = "table" }),
    creators = schema({ creators = "table", server_luck = "table", meet = "table" }),
    daily = schema({ max_gap_days = "number", cycle_length = "number", calendar = "table" }),
    drops = schema({ gem_bonus = "table", collect_radius = "number", despawn_seconds = "number" }),
    egg_hatching = schema({ version = "string", speed_presets = "table", timing = "table" }),
    elements = schema({ biome = "table", resonance = "table" }),
    enemies = schema({ spawners = "table", enemies = "table" }),
    enemy_leash = schema({
        inset = "number",
        surface_probe = "table",
        region_order = "table",
        spawner_root = "string",
        spawner_bindings = "table",
        regions = "table",
    }),
    enhancements = schema({ origins = "table", values = "table", types = "table" }),
    flash_effects = schema({ default_effect = "string", sound = "table", effects = "table" }),
    focus = schema({ focus_max = "number", regen_per_second = "number" }),
    fusion = schema({ output_element = "string", required_elements = "table", recipes = "table" }),
    game_events = schema({
        toggle_crash = "table",
        power_cast_failed = "table",
        level_up = "table",
    }),
    gems = schema({ meshes = "table", textures = "table", default_color = "string" }),
    guardians = schema({ model_asset = "table", colossus = "table", djinn = "table" }),
    hotbar = schema({ slot_count = "number", bind_types = "table", tactical_commands = "table" }),
    layers = schema({ traversal = "table", earning = "table", depth_rewards = "table" }),
    level_track = schema({ version = "string", max_level = "number", milestones = "table" }),
    leveling = schema({ xp_rewards = "table", combat_xp = "table", scale = "table" }),
    logging = schema({ global = "table", performance_monitor = "table", services = "table" }),
    party = schema({ max_size = "number", loot_rule = "string", mvp_bonus_percent = "number" }),
    pet_follow = schema({ ring_mining = "table", formation = "table", movement = "table" }),
    pet_power = schema({
        base_scale = "number",
        variant_mult = "table",
        context_defaults = "table",
    }),
    pet_roles = schema({ default = "string", by_type = "table", roles = "table" }),
    pet_thumbnail_assets = schema({ pets = "table", eggs = "table" }),
    pill_ui = schema({ frames = "table", panels = "table", rings = "table" }),
    potions = schema({ tick_seconds = "number", meters = "table", potions = "table" }),
    power_descriptions = schema({ stone_skin = "string", bulwark = "string" }),
    power_fx = schema({ primitives = "table", probe = "table", sounds = "table" }),
    power_icons = schema({ powers = "table", status = "table", actions = "table" }),
    power_icons_assets = schema({ discs = "table", rings = "table" }),
    powers = schema({ selection_levels = "table", scaling = "table", powers = "table" }),
    quests = schema({ tracks = "table", defs = "table" }),
    ratelimits = schema({ baseRates = "table", effectModifiers = "table", antiExploit = "table" }),
    rewards = schema({
        grant_log_limit = "number",
        default_item_bucket = "string",
        slot_upgrades = "table",
    }),
    rifts = schema({ multipliers = "table", default_multiplier = "number", schedule = "table" }),
    rosters = schema({ injury_rules = "table", default_injury_rule = "string" }),
    shop = schema({ offers = "table" }),
    showcase = schema({ place_ids = "table", apply = "function" }),
    soul = schema({ delta_per_conquest = "number", range = "table", bands = "table" }),
    sounds = schema({ egg_hatch_pop = "table", egg_roll_snare = "table" }),
    spirit_form = schema({ cooldown_tiers = "table", heaven_recharge_multiplier = "number" }),
    squad = schema({ limits = "table", swap_cooldown_seconds = "number", slot_recovery = "table" }),
    squad_diversity = schema({ archetype = "table", origin = "table", max_mult = "number" }),
    stack_pool = schema({ recharge_per_instance_seconds = "number", contribution_curve = "string" }),
    theme_utility = schema({ passives = "table" }),
    trade = schema({
        tradeable = "table",
        tradeable_currencies = "table",
        max_offer_items = "number",
    }),
    tutorial = schema({ veteran_skip = "table", steps = "table", completion = "table" }),
    ui_theme = schema({ default_color = "string", areas = "table", palettes = "table" }),
    veteran = schema({ xp_per_level = "number", rewards = "table" }),
    zone_tracker = schema({
        poll_interval = "number",
        vertical_band = "number",
        default_area = "string",
    }),
}

function ConfigSchemas.get(configName)
    return SCHEMAS[configName]
end

function ConfigSchemas.validate(configName, config)
    local definition = SCHEMAS[configName]
    if not definition then
        return false, string.format("configs/%s.lua:<root> has no explicit schema", configName)
    end
    if type(config) ~= "table" then
        return false,
            string.format("configs/%s.lua:<root> expected table, got %s", configName, type(config))
    end

    for key, expectedType in pairs(definition.required) do
        local actualType = type(config[key])
        if actualType ~= expectedType then
            return false,
                string.format(
                    "configs/%s.lua:%s expected %s, got %s (schema revision %d)",
                    configName,
                    key,
                    expectedType,
                    actualType,
                    definition.revision
                )
        end
    end
    return true
end

return ConfigSchemas
