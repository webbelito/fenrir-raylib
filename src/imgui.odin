package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:log"

// Initialize ImGui with default configuration
imgui_init :: proc() -> bool {
	log_info(.ENGINE, "Initializing ImGui")

	// Create ImGui context
	ctx := imgui.CreateContext(nil)
	if ctx == nil {
		log_error(.ENGINE, "Failed to create ImGui context")
		return false
	}

	// Configure ImGui
	io := imgui.GetIO()
	io.ConfigFlags += {.NavEnableKeyboard, .NavEnableGamepad, .DockingEnable}
	io.ConfigDockingWithShift = true // Enable docking with Shift key
	io.IniFilename = nil // Disable imgui.ini
	io.LogFilename = nil // Disable imgui_log.txt
	io.DeltaTime = 1.0 / 60.0 // Set initial delta time

	// Set ImGui style
	imgui.StyleColorsDark(nil)

	// Initialize ImGui with Raylib
	if !imgui_rl.init() {
		log_error(.ENGINE, "Failed to initialize ImGui with Raylib")
		imgui.DestroyContext(ctx)
		return false
	}

	// Build font atlas
	if err := imgui_rl.build_font_atlas(); err != nil {
		log_error(.ENGINE, "Failed to build font atlas: %v", err)
		imgui_rl.shutdown()
		imgui.DestroyContext(ctx)
		return false
	}

	log_info(.ENGINE, "ImGui initialized successfully")
	return true
}

// Shutdown ImGui
imgui_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down ImGui")

	// Get the current context
	ctx := imgui.GetCurrentContext()
	if ctx != nil {
		imgui_rl.shutdown()
		imgui.DestroyContext(ctx)
		log_info(.ENGINE, "ImGui shut down successfully")
	} else {
		log_warning(.ENGINE, "No ImGui context to shut down")
	}
}

// Start a new ImGui frame
imgui_begin_frame :: proc() {
	// Update ImGui IO with our delta time
	io := imgui.GetIO()
	io.DeltaTime = get_delta_time()

	imgui_rl.process_events()
	imgui_rl.new_frame()
	imgui.NewFrame()
}

// End the ImGui frame and render
imgui_end_frame :: proc() {
	imgui.Render()
	draw_data := imgui.GetDrawData()
	if draw_data != nil {
		imgui_rl.render_draw_data(draw_data)
	}
}

// Show the ImGui demo window
imgui_show_demo :: proc() {
	demo_open := true
	imgui.ShowDemoWindow(&demo_open)
}

// Explicitly re-upload ImGui font texture
imgui_reupload_font_texture :: proc() {
	if err := imgui_rl.build_font_atlas(); err != nil {
		log_error(.EDITOR, "Failed to re-build font atlas: %v", err)
	} else {
		log_info(.EDITOR, "Re-built ImGui font atlas.")
	}
}
