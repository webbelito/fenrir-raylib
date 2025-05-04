package main

import "core:fmt"
import "core:log"

main :: proc() {
    // Initialize logging first
    log_init()
    defer log_shutdown()
    
    // Create engine configuration
    config := Engine_Config{
        app_name = "Fenrir Engine Demo",
        window_width = 1280,
        window_height = 720,
        target_fps = 60,
        vsync = false,
        fullscreen = false,
        disable_escape_quit = true,
    }
    
    // Initialize and run engine
    if engine_init(config) {
        engine_run()
    } else {
        log_error(.ENGINE, "Failed to initialize Fenrir Engine")
    }
    defer engine_shutdown()
} 