package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"

// Render the editor layout - now renders windows that can be docked
editor_layout_render :: proc() {
	// Render scene tree panel 
	// No explicit SetNextWindowPos/Size needed; let the docking system handle it.
	if editor.scene_tree_open {
		// Standard window flags, can be customized (e.g., add .MenuBar if a window has its own menu)
		// For now, default flags are fine, or remove specific NoResize/NoMove flags.
		// Let's use no specific flags initially to allow full docking behavior.
		if imgui.Begin("Scene Tree", &editor.scene_tree_open) {
			editor_scene_tree_render()
		}
		imgui.End()
	}

	// Render inspector panel
	// No explicit SetNextWindowPos/Size needed.
	if editor.inspector_open {
		if imgui.Begin("Inspector", &editor.inspector_open) {
			editor_inspector_render()
		}
		imgui.End()
	}
}
