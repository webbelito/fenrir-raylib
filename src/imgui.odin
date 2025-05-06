package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:log"

// Initialize ImGui with default configuration
imgui_init :: proc() -> bool {
	// Create ImGui context
	imgui.CreateContext(nil)

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
		return false
	}

	// Build font atlas
	imgui_rl.build_font_atlas()

	return true
}

// Shutdown ImGui
imgui_shutdown :: proc() {
	imgui_rl.shutdown()
	imgui.DestroyContext(nil)
}

// Start a new ImGui frame
imgui_begin_frame :: proc() {
	imgui_rl.process_events()
	imgui_rl.new_frame()
	imgui.NewFrame()
}

// End the ImGui frame and render
imgui_end_frame :: proc() {
	imgui.Render()
	imgui_rl.render_draw_data(imgui.GetDrawData())
}

// Show the ImGui demo window
imgui_show_demo :: proc() {
	demo_open := true
	imgui.ShowDemoWindow(&demo_open)
}
