package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:log"
import raylib "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Viewport state - simplified, no render_texture needed for this approach
Viewport_State :: struct {
	initialized: bool,
	open:        bool,
	// width:       i32, // May still be useful for camera aspect if calculated from ImGui window
	// height:      i32,
}

viewport_state: Viewport_State // Renamed from viewport to avoid conflict with rlgl.Viewport

// Initialize the viewport
editor_viewport_init :: proc() -> bool {
	if viewport_state.initialized {
		return true
	}
	viewport_state = Viewport_State {
		initialized = true,
		open        = true,
	}
	log_info(.ENGINE, "Viewport initialized (Scissor Mode)")
	return true
}

// Shutdown the viewport
editor_viewport_shutdown :: proc() {
	if !viewport_state.initialized {
		return
	}
	viewport_state.initialized = false
	log_info(.ENGINE, "Viewport shut down (Scissor Mode)")
}

// Render the 3D scene directly into a specified region of the main window
editor_viewport_draw_3d_scene :: proc(x, y, width, height: i32) {
	if width <= 0 || height <= 0 {return} 	// Ensure valid dimensions

	// Get current screen dimensions for resetting viewport later
	screen_width := raylib.GetScreenWidth()
	screen_height := raylib.GetScreenHeight()

	raylib.BeginScissorMode(x, y, width, height)
	{
		// Set the OpenGL viewport to the scissor rectangle
		rlgl.Viewport(x, screen_height - (y + height), width, height)

		raylib.BeginMode3D(engine.editor_camera) // Camera's projection matrix will now be set up for this viewport
		{
			scene_manager_render() // Renders the 3D scene
		}
		raylib.EndMode3D()

		// Reset the OpenGL viewport to full screen
		rlgl.Viewport(0, 0, screen_width, screen_height)
	}
	raylib.EndScissorMode()
}

// Render the viewport ImGui UI (which now acts as a frame/overlay)
editor_viewport_render_ui :: proc() {
	// Calculate ImGui window position and size (as before)
	window_size := imgui.GetIO().DisplaySize
	panel_width := window_size.x * 0.2
	menu_bar_height := imgui.GetFrameHeight()

	viewport_imgui_x := panel_width
	viewport_imgui_y := menu_bar_height
	viewport_imgui_width := window_size.x - (panel_width * 2)
	viewport_imgui_height := window_size.y - menu_bar_height

	imgui.SetNextWindowPos(imgui.Vec2{viewport_imgui_x, viewport_imgui_y})
	imgui.SetNextWindowSize(imgui.Vec2{viewport_imgui_width, viewport_imgui_height})

	window_flags := imgui.WindowFlags {
		.NoTitleBar,
		.NoResize,
		.NoMove,
		.NoScrollbar,
		.NoScrollWithMouse,
		.NoCollapse,
		.NoBackground,
		.NoBringToFrontOnFocus,
		.NoDocking,
	}

	if imgui.Begin("Viewport", &viewport_state.open, window_flags) {

		imgui.SetCursorPos(imgui.Vec2{10, 10})
		imgui.Text("3D Viewport (Scissor Mode)")

		// 

	}
	imgui.End()
}
