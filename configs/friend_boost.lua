-- Launch-period social boost. `active_phase` is the one switch to change after the
-- experience reaches 10,000 public plays; Roblox's visit counter is platform-owned,
-- so the threshold is recorded here rather than inferred from partial server sessions.
return {
    enabled = true,
    active_phase = "launch",
    launch_play_target = 10000,
    max_friends = 4,

    phases = {
        launch = {
            hatch_luck_per_friend = 0.20,
            xp_per_friend = 0.10,
            coins_per_friend = 0.10,
        },
        post_launch = {
            hatch_luck_per_friend = 0.025,
            xp_per_friend = 0.05,
            coins_per_friend = 0.05,
        },
    },
}
