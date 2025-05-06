#+feature dynamic-literals
package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:os"
import "core:strconv"
import "core:strings"
import raylib "vendor:raylib"

// Editor state
Editor_State :: struct {
	active:      bool,
	initialized: bool,
}

editor_state: Editor_State

// Initialize the editor (only in debug mode)
editor_init :: proc() -> bool {
	when ODIN_DEBUG {
		if editor_state.initialized {
			return true
		}

		log_info(.ENGINE, "Initializing editor")

		// Initialize ImGui
		if !imgui_init() {
			log_error(.ENGINE, "Failed to initialize ImGui")
			return false
		}

		// Set default state
		editor_state.active = true
		editor_state.initialized = true

		return true
	} else {
		return false
	}
}

// Update the editor (only in debug mode)
editor_update :: proc() -> bool {
	when ODIN_DEBUG {
		if !editor_state.initialized || !editor_state.active {
			return false
		}
		return true
	}
	return false
}

// Render the editor UI
editor_render :: proc() {
	when ODIN_DEBUG {
		if !editor_state.initialized || !editor_state.active {
			return
		}

		// Start ImGui frame
		imgui_begin_frame()

		// Show the ImGui demo window
		imgui_show_demo()

		// End ImGui frame
		imgui_end_frame()
	}
}

// Shutdown the editor (only in debug mode)
editor_shutdown :: proc() {
	when ODIN_DEBUG {
		if !editor_state.initialized {
			return
		}

		log_info(.ENGINE, "Shutting down editor")

		// Shutdown ImGui
		imgui_shutdown()

		editor_state.initialized = false
		editor_state.active = false
	}
}

// Toggle editor visibility
editor_toggle :: proc() -> bool {
	when ODIN_DEBUG {
		if !editor_state.initialized {
			editor_init()
		}

		editor_state.active = !editor_state.active
		log_info(.ENGINE, "Editor active: %v", editor_state.active)
		return editor_state.active
	} else {
		return false
	}
}

// Check if editor is active
editor_is_active :: proc() -> bool {
	when ODIN_DEBUG {
		return editor_state.initialized && editor_state.active
	} else {
		return false
	}
}
