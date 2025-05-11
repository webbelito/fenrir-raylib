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
	// defer imgui_shutdown() // Defer shutdown to the very end

	// ---- Experimental: Load and unload dummy textures ----
	log_info(.ENGINE, "Creating more substantial dummy textures to offset IDs...")
	// Create a few small, valid textures
	for i in 0 ..< 3 {
		dummy_image := raylib.GenImageColor(16, 16, raylib.BLUE)
		dummy_tex := raylib.LoadTextureFromImage(dummy_image)
		raylib.UnloadImage(dummy_image)
		if raylib.IsTextureReady(dummy_tex) {
			// log_info(.ENGINE, "Dummy texture %d created with ID: %d", i, dummy_tex.id)
			// We could even try drawing with it briefly to ensure GPU interaction
			// raylib.BeginDrawing() 
			// raylib.DrawTexture(dummy_tex, 0,0, raylib.WHITE)
			// raylib.EndDrawing()
			raylib.UnloadTexture(dummy_tex)
		} else {
			// log_warning(.ENGINE, "Failed to create dummy texture %d", i)
		}
	}
	// And a dummy render texture
	dummy_rt := raylib.LoadRenderTexture(16, 16)
	if raylib.IsRenderTextureReady(dummy_rt) {
		// log_info(.ENGINE, "Dummy render texture created. ID: %d, Texture.ID: %d", dummy_rt.id, dummy_rt.texture.id)
		raylib.UnloadRenderTexture(dummy_rt)
	}
	log_info(.ENGINE, "Dummy textures processed.")
	// ---- End Experimental ----

	// Initialize editor
	if !editor_init() {
		log_error(.ENGINE, "Failed to initialize editor")
		return
	}

	log_info(.ENGINE, "All systems initialized successfully")

	// Main game loop
	for !raylib.WindowShouldClose() {
		// Update
		engine_update()

		// Render
		engine_render()
	}

	// Shutdown
	editor_shutdown()
	imgui_shutdown() // Shutdown ImGui after editor
	scene_manager_shutdown()
	engine_shutdown()
	time_shutdown()
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
