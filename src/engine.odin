package main

import "base:runtime"

import raylib "vendor:raylib"
import "core:strings"
import "core:log"


// Engine Configuration
Engine_Config :: struct {
    app_name:      string,
    window_width:  i32,
    window_height: i32,
    target_fps:    i32,
    vsync:         bool,
    fullscreen:    bool,
    disable_escape_quit: bool,
    default_context: runtime.Context,
}

// Global engine running state
engine_is_running: bool = false

// Initialize the engine
engine_init :: proc(config: Engine_Config) -> bool {
    log_info(.ENGINE, "Initializing Fenrir Engine")
    
    // Initialize subsystems
    time_init()
    
    // Initialize Raylib window
    raylib.InitWindow(
        config.window_width, 
        config.window_height, 
        strings.clone_to_cstring(config.app_name)
    )
    
    if config.vsync {
        // Set target FPS using our wrapper
        raylib.SetTargetFPS(config.target_fps)
    }
    
    if config.fullscreen {
        log_info(.ENGINE, "Toggling fullscreen mode")
        raylib.ToggleFullscreen()
    }
    
    if config.disable_escape_quit {
        log_info(.ENGINE, "Disabling escape key to quit")
        raylib.SetExitKey(raylib.KeyboardKey.F4)
    }
    
    // Initialize editor in debug builds
    when ODIN_DEBUG {
        editor_init()
    }
    
    engine_is_running = true
    log_info(.ENGINE, "Fenrir Engine initialized successfully")
    
    return true
}

// Update the engine (one frame)
engine_update :: proc() -> bool {
    if raylib.WindowShouldClose() {
        log_debug(.ENGINE, "Window close requested")
        engine_is_running = false
    }
    
    // Update time
    time_update()
    
    // Update editor in debug mode
    when ODIN_DEBUG {
        // Toggle editor with F1 key
        if raylib.IsKeyPressed(.F1) {
            editor_toggle()
        }
        
        editor_update()
    }
    
    return engine_is_running
}

// Render the current frame
engine_render :: proc() {
    raylib.BeginDrawing()
    defer raylib.EndDrawing()
    
    raylib.ClearBackground(raylib.BLACK)

    // Draw 3D scene here (viewport will be adjusted if editor is active)
    
    // Draw editor UI in debug mode
    when ODIN_DEBUG {
        editor_render()
        
        // Draw FPS counter
        raylib.DrawFPS(10, 10)
    }
}

// Shutdown the engine
engine_shutdown :: proc() {
    log_info(.ENGINE, "Shutting down Fenrir Engine")
    
    // Shutdown editor in debug mode
    when ODIN_DEBUG {
        editor_shutdown()
    }
    
    // Shutdown Raylib using our wrapper
    raylib.CloseWindow()
}

// Run the engine main loop
engine_run :: proc() {
    // Main game loop
    for engine_is_running {
        
        // Check if Escape key is pressed
        if raylib.IsKeyPressed(raylib.KeyboardKey.ESCAPE) {
            log_info(.ENGINE, "Escape key pressed, quitting")
            engine_is_running = false
        }

        if !engine_update() {
            break
        }
        engine_render()
    }
} 