-- Routine progress coalesces with ProfileStore's normal recovery cadence. Critical ownership
-- barriers still request promptly, but never turn a confirmation timeout into another writer.
return {
    auto_save_seconds = 60,
    ordinary_debounce_seconds = 60,
    critical_debounce_seconds = 1,
    periodic_save_seconds = 60,
    confirmation_timeout_seconds = 30,
}
