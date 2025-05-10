package main

import "core:fmt"
import "core:log"
import "core:strings"
import raylib "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

main :: proc() {
	// Initialize logging first
	log_init()
	defer log_shutdown()

	// Create engine configuration
	config := Engine_Config {
		app_name            = "Fenrir Engine Demo",
		window_width        = 1920,
		window_height       = 1080,
		target_fps          = 60,
		vsync               = true,
		fullscreen          = false,
		disable_escape_quit = true,
	}

	// Initialize raylib
	if !init_raylib(config) {
		log_error(.ENGINE, "Failed to initialize raylib")
		return
	}

	// Initialize time system
	time_init()

	// Initialize engine first
	if !engine_init(config) {
		log_error(.ENGINE, "Failed to initialize Fenrir Engine")
		return
	}
	defer engine_shutdown()

	// Initialize ImGui first
	if !imgui_init() {
		log_error(.ENGINE, "Failed to initialize ImGui")
		return
	}
	defer imgui_shutdown()

	// Initialize editor
	if !editor_manager_init() {
		log_error(.ENGINE, "Failed to initialize editor")
		return
	}
	defer editor_manager_shutdown()

	log_info(.ENGINE, "All systems initialized successfully")

	// Main game loop
	for !raylib.WindowShouldClose() {
		// Update time
		time_update()

		// Update engine
		engine_update()

		// Render engine
		engine_render()
	}
}

// Initialize raylib with the given configuration
init_raylib :: proc(config: Engine_Config) -> bool {
	// Set window flags
	raylib.SetConfigFlags({.VSYNC_HINT})

	// Initialize window
	raylib.InitWindow(
		config.window_width,
		config.window_height,
		strings.clone_to_cstring(config.app_name),
	)

	// Set target FPS
	raylib.SetTargetFPS(config.target_fps)

	// Check if window was created successfully
	if !raylib.IsWindowReady() {
		log_error(.ENGINE, "Failed to initialize raylib window")
		return false
	}

	return true
}
