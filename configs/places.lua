-- Published-place roles for the Halo and Horns universe.
--
-- Place identity is authoritative. Map hooks and coordinates validate/bind content after the
-- role is known; they must never be used to guess which product experience is running.
return {
    version = 1,
    universe_id = 10307183003,
    default_role = "main",
    roles = {
        main = {
            place_ids = {
                77766176054993,
            },
        },
        merge = {
            walk_speed = 24,
            place_ids = {
                84544653387905,
            },
            initial_area = "MergeEggPrototype",
            authored_root = "Workspace.Maps.MergeEggRealm",
        },
    },
}
