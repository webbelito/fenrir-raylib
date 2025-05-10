package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"

// Render the editor layout
editor_layout_render :: proc() {
	// Get the main window size
	window_size := imgui.GetIO().DisplaySize
	panel_width := window_size.x * 0.2 // 20% of screen width
	menu_bar_height := imgui.GetFrameHeight() // Get the height of the menu bar

	// Render scene tree panel (fixed on left)
	if editor.scene_tree_open {
		imgui.SetNextWindowPos({0, menu_bar_height})
		imgui.SetNextWindowSize({panel_width, window_size.y - menu_bar_height})
		window_flags := imgui.WindowFlags{.NoCollapse, .NoResize, .NoMove}
		if imgui.Begin("Scene Tree", &editor.scene_tree_open, window_flags) {
			editor_scene_tree_render()
		}
		imgui.End()
	}

	// Render inspector panel (fixed on right)
	if editor.inspector_open {
		imgui.SetNextWindowPos({window_size.x - panel_width, menu_bar_height})
		imgui.SetNextWindowSize({panel_width, window_size.y - menu_bar_height})
		window_flags := imgui.WindowFlags{.NoCollapse, .NoResize, .NoMove}
		if imgui.Begin("Inspector", &editor.inspector_open, window_flags) {
			editor_inspector_render()
		}
		imgui.End()
	}
}
