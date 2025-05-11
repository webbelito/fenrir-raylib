package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:log"
import raylib "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

// Viewport state
Viewport_State :: struct {
	initialized: bool,
	rect_x:      i32,
	rect_y:      i32,
	rect_width:  i32,
	rect_height: i32,
}

viewport_state: Viewport_State

// Initialize the viewport
editor_viewport_init :: proc() -> bool {
	if viewport_state.initialized {
		return true
	}
	viewport_state = Viewport_State {
		initialized = true,
		rect_x      = 0,
		rect_y      = 0,
		rect_width  = 0,
		rect_height = 0,
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
	// Reset viewport rect if invalid to prevent drawing with old values if window is hidden/minimized
	if width <= 0 || height <= 0 {
		viewport_state.rect_width = 0
		viewport_state.rect_height = 0
		return
	}

	// Get current screen dimensions for resetting viewport later
	screen_width := raylib.GetScreenWidth()
	screen_height := raylib.GetScreenHeight()

	raylib.BeginScissorMode(x, y, width, height)
	{
		// Set the OpenGL viewport to the scissor rectangle
		rlgl.Viewport(x, screen_height - (y + height), width, height)

		raylib.BeginMode3D(engine.editor_camera)
		{
			scene_manager_render()
		}
		raylib.EndMode3D()

		// Reset the OpenGL viewport to full screen
		rlgl.Viewport(0, 0, screen_width, screen_height)
	}
	raylib.EndScissorMode()
}

// Render the viewport ImGui UI (which now acts as a frame/overlay)
editor_viewport_render_ui :: proc() {
	// Simplify flags: only .NoBackground. Add others back if this works.
	window_flags := imgui.WindowFlags{.NoBackground}

	// Convert Vec4 to u32 for PushStyleColor
	transparent_color_u32 := imgui.GetColorU32ImVec4(imgui.Vec4{0.0, 0.0, 0.0, 0.0})
	imgui.PushStyleColor(imgui.Col.WindowBg, transparent_color_u32) // Force transparent background
	if imgui.Begin("Viewport", &editor.viewport_open, window_flags) {
		window_pos := imgui.GetWindowPos()
		content_min_relative := imgui.GetWindowContentRegionMin()
		content_max_relative := imgui.GetWindowContentRegionMax()

		// Calculate the current viewport rect in screen space
		current_rect_x := i32(window_pos.x + content_min_relative.x)
		current_rect_y := i32(window_pos.y + content_min_relative.y)
		current_rect_width := i32(content_max_relative.x - content_min_relative.x)
		current_rect_height := i32(content_max_relative.y - content_min_relative.y)

		// Update viewport_state only if the size is valid
		if current_rect_width > 0 && current_rect_height > 0 {
			viewport_state.rect_x = current_rect_x
			viewport_state.rect_y = current_rect_y
			viewport_state.rect_width = current_rect_width
			viewport_state.rect_height = current_rect_height
		} else {
			// If window is collapsed or too small, invalidate the rect
			viewport_state.rect_width = 0
			viewport_state.rect_height = 0
		}

		// Example: Display viewport size or other info as an overlay
		imgui.SetCursorPos(imgui.Vec2{10, 25})
		imgui.Text(
			"3D Viewport (Size: %dx%d)",
			viewport_state.rect_width,
			viewport_state.rect_height,
		)

	}
	imgui.End()
	imgui.PopStyleColor(1)
}
