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
engine_is_playing: bool = false

// Initialize the engine
engine_init :: proc(config: Engine_Config) -> bool {
    log_info(.ENGINE, "Initializing Fenrir Engine")
    
    // Initialize subsystems
    time_init()
    ecs_init()
    scene_init()
    
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
    
    // Create a default scene if none exists
    if !scene_is_loaded() {
        scene_new("Default Scene")
    }
    
    engine_is_running = true
    log_info(.ENGINE, "Fenrir Engine initialized successfully")
    
    return true
}

// Start play mode (run the actual game)
engine_play :: proc() {
    if !engine_is_playing {
        log_info(.ENGINE, "Starting play mode")
        engine_is_playing = true
        
        // TODO: Additional play mode setup
    }
}

// Stop play mode (return to edit mode)
engine_stop :: proc() {
    if engine_is_playing {
        log_info(.ENGINE, "Stopping play mode")
        engine_is_playing = false
        
        // TODO: Additional play mode cleanup
    }
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
        
        // Toggle play mode with F5 key
        if raylib.IsKeyPressed(.F5) {
            if engine_is_playing {
                engine_stop()
            } else {
                engine_play()
            }
        }
        
        editor_update()
    }
    
    // TODO: Update game systems (physics, AI, etc.)
    
    return engine_is_running
}

// Render the current frame
engine_render :: proc() {
    raylib.BeginDrawing()
    defer raylib.EndDrawing()
    
    raylib.ClearBackground(raylib.BLACK)

    // Draw 3D scene here (viewport will be adjusted if editor is active)
    if scene_is_loaded() {
        // Get all renderable entities
        renderer_entities := ecs_get_entities_with_component(.RENDERER)
        defer delete(renderer_entities)
        
        // Get main camera
        main_camera_entity := scene_get_main_camera()
        camera_valid := main_camera_entity != 0
        
        if camera_valid {
            // Set up camera for 3D rendering
            camera_component := ecs_get_camera(main_camera_entity)
            camera_transform := ecs_get_transform(main_camera_entity)
            
            if camera_component != nil && camera_transform != nil {
                camera := raylib.Camera3D{
                    position = {
                        camera_transform.position[0], 
                        camera_transform.position[1], 
                        camera_transform.position[2],
                    },
                    target = {
                        camera_transform.position[0], 
                        camera_transform.position[1], 
                        0,
                    }, // Looking at Z direction
                    up = {0, 1, 0},
                    fovy = camera_component.fov,
                    projection = raylib.CameraProjection.PERSPECTIVE,
                }
                
                // Begin 3D mode with this camera
                raylib.BeginMode3D(camera)
                
                // Draw a simple grid for reference
                raylib.DrawGrid(20, 1.0)
                
                // Draw all renderable entities
                for entity in renderer_entities {
                    renderer := ecs_get_renderer(entity)
                    transform := ecs_get_transform(entity)
                    
                    if renderer != nil && transform != nil && renderer.visible {
                        // Draw a cube at the entity position for now
                        position := raylib.Vector3{
                            transform.position[0],
                            transform.position[1],
                            transform.position[2],
                        }
                        size := raylib.Vector3{
                            transform.scale[0],
                            transform.scale[1],
                            transform.scale[2],
                        }
                        
                        raylib.DrawCube(position, size.x, size.y, size.z, raylib.RED)
                        raylib.DrawCubeWires(position, size.x, size.y, size.z, raylib.WHITE)
                    }
                }
                
                // End 3D mode
                raylib.EndMode3D()
            }
        }
    }
    
    // Draw editor UI in debug mode
    when ODIN_DEBUG {
        editor_render()
        
        // Draw FPS counter
        raylib.DrawFPS(10, 10)
        
        // Draw play mode indicator
        if engine_is_playing {
            raylib.DrawText("PLAY MODE", raylib.GetScreenWidth() - 120, 10, 20, raylib.GREEN)
        }
    }
}

// Shutdown the engine
engine_shutdown :: proc() {
    log_info(.ENGINE, "Shutting down Fenrir Engine")
    
    // Shutdown editor in debug mode
    when ODIN_DEBUG {
        editor_shutdown()
    }
    
    // Shutdown subsystems in reverse order
    scene_shutdown()
    ecs_shutdown()
    
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