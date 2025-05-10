package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"

// Inspector state
Inspector_State :: struct {
	initialized: bool,
}

inspector: Inspector_State

// Initialize the inspector
editor_inspector_init :: proc() -> bool {
	if inspector.initialized {
		return true
	}

	inspector = Inspector_State {
		initialized = true,
	}

	log_info(.ENGINE, "Inspector initialized")
	return true
}

// Shutdown the inspector
editor_inspector_shutdown :: proc() {
	if !inspector.initialized {
		return
	}

	inspector.initialized = false
	log_info(.ENGINE, "Inspector shut down")
}

// Update the inspector
editor_inspector_update :: proc() {
	if !editor.inspector_open {
		return
	}

	// Handle any inspector updates here
	// For example, handle property changes, component additions, etc.
}

// Render the inspector
editor_inspector_render :: proc() {
	if !editor.inspector_open {
		return
	}

	// Render the inspector content
	if editor.selected_entity == 0 {
		imgui.Text("No entity selected")
		return
	}

	// Render transform component
	if transform := ecs_get_transform(editor.selected_entity); transform != nil {
		transform_render_inspector(transform)
	}

	// Render renderer component
	if renderer := ecs_get_renderer(editor.selected_entity); renderer != nil {
		renderer_render_inspector(renderer)
	}

	// Render camera component
	if camera := ecs_get_camera(editor.selected_entity); camera != nil {
		camera_render_inspector(camera)
	}

	// Render light component
	if light := ecs_get_light(editor.selected_entity); light != nil {
		light_render_inspector(light)
	}

	// Render script component
	if script := ecs_get_script(editor.selected_entity); script != nil {
		script_render_inspector(script)
	}

	// Add component button
	if imgui.Button("Add Component") {
		imgui.OpenPopup("AddComponent")
	}

	if imgui.BeginPopup("AddComponent") {
		if imgui.MenuItem("Transform") {
			ecs_add_transform(editor.selected_entity)
		}
		if imgui.MenuItem("Renderer") {
			ecs_add_renderer(editor.selected_entity)
		}
		if imgui.MenuItem("Camera") {
			ecs_add_camera(editor.selected_entity, 45.0, 0.1, 1000.0, false)
		}
		if imgui.MenuItem("Light") {
			ecs_add_light(editor.selected_entity, .POINT)
		}
		if imgui.MenuItem("Script") {
			ecs_add_script(editor.selected_entity, "default_script")
		}
		imgui.EndPopup()
	}
}
