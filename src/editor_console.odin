package main

import imgui "../vendor/odin-imgui"
import "core:log"

// Console State (if needed in the future)
// Console_State :: struct {
// 	initialized: bool,
// }

// console_state: Console_State

// Initialize the console
editor_console_init :: proc() -> bool {
	// console_state.initialized = true
	log_info(.EDITOR, "Console initialized")
	return true
}

// Shutdown the console
editor_console_shutdown :: proc() {
	// if !console_state.initialized {
	// 	return
	// }
	// console_state.initialized = false
	log_info(.EDITOR, "Console shut down")
}

// Render the console ImGui UI
editor_console_render_ui :: proc() {
	// Use editor.console_open (from editor_manager) to control visibility
	if !editor.console_open {
		return
	}

	imgui.SetNextWindowSize(imgui.Vec2{600, 150}, imgui.Cond.FirstUseEver)
	if imgui.Begin("Console", &editor.console_open) {
		imgui.Text("Console Output Will Go Here...")
		// TODO: Add text buffer and scrolling for log messages
	}
	imgui.End()
}
