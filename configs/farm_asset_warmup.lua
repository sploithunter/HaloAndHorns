-- Owner-only previews from the prebuilt server catalog. Never an inventory of every pet.
return {
    enabled = true,
    cache_folder = "FarmAssetWarmCache",
    boot_egg_sources = { "basic_egg" },
    nearby_egg_count = 2, -- nearest stand plus the next nearby stand, including locked previews
    maximum_predictive_pet_types = 24,
    recent_owned_models = 16,
    nearby_pet_radius = 150,
    retention_seconds = 30,
    requested_retention_seconds = 60,
    maximum_requested_models = 16,
    request_interval_seconds = 0.25,
    template_wait_seconds = 8,
    reconcile_interval = 2,
    preload_batch_size = 12,
    preload_debounce_seconds = 0.15,
}
