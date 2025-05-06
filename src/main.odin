package main

import "core:fmt"
import "core:log"
import "core:strings"

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"

import raylib "vendor:raylib"

main :: proc() {
	// Initialize logging first
	log_init()
	defer log_shutdown()

	// Create engine configuration
	config := Engine_Config {
		app_name            = "Fenrir Engine Demo",
		window_width        = 1280,
		window_height       = 720,
		target_fps          = 60,
		vsync               = false,
		fullscreen          = false,
		disable_escape_quit = true,
	}

	// Initialize raylib first
	raylib.SetConfigFlags({.VSYNC_HINT})
	raylib.InitWindow(
		config.window_width,
		config.window_height,
		strings.clone_to_cstring(config.app_name),
	)
	raylib.SetTargetFPS(config.target_fps)

	// Initialize time system
	time_init()

	// Initialize ImGUI
	imgui.CreateContext(nil)
	defer imgui.DestroyContext(nil)

	// Configure ImGUI
	io := imgui.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad, .DockingEnable}
	io.ConfigDockingWithShift = true // Enable docking with Shift key to reduce visual noise
	io.IniFilename = nil // Disable imgui.ini
	io.LogFilename = nil // Disable imgui_log.txt
	io.DeltaTime = 1.0 / 60.0 // Set initial delta time

	// Set ImGUI style
	imgui.StyleColorsDark(nil)

	// Initialize ImGUI with Raylib
	imgui_rl.init()
	defer imgui_rl.shutdown()

	// Build font atlas
	imgui_rl.build_font_atlas()

	// Initialize engine
	if engine_init(config) {
		// Main game loop
		for !raylib.WindowShouldClose() {
			// Update time
			time_update()

			// Update engine
			engine_update()

			// Process ImGui events
			imgui_rl.process_events()

			// Start new ImGui frame
			imgui_rl.new_frame()
			imgui.NewFrame()

			// Begin raylib drawing
			raylib.BeginDrawing()
			defer raylib.EndDrawing()

			// Clear the background
			raylib.ClearBackground(raylib.BLACK)

			// Render engine
			engine_render()

			// Show ImGui demo window
			demo_open := true
			imgui.ShowDemoWindow(&demo_open)

			// End ImGui frame
			imgui.Render()
			imgui_rl.render_draw_data(imgui.GetDrawData())
		}
	} else {
		log_error(.ENGINE, "Failed to initialize Fenrir Engine")
	}
	defer engine_shutdown()
}
