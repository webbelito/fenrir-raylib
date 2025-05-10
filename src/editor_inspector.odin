package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:math"
import "core:strings"
import raylib "vendor:raylib"

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

	// Entity metadata section
	if imgui.CollapsingHeader("Entity", {imgui.TreeNodeFlag.DefaultOpen}) {
		// Get the node for this entity
		if node, ok := scene_manager.current_scene.nodes[editor.selected_entity]; ok {
			// Entity name input
			name_buf: [256]u8
			copy(name_buf[:], node.name)
			if imgui.InputText(
				"Name",
				cstring(raw_data(name_buf[:])),
				len(name_buf),
				{imgui.InputTextFlag.EnterReturnsTrue},
			) {
				// Update the node name
				delete(node.name)
				node.name = strings.clone(string(name_buf[:]))
				scene_manager.current_scene.nodes[editor.selected_entity] = node
				scene_manager.current_scene.dirty = true
			}

			// Active toggle
			if imgui.Checkbox("Active", &node.expanded) {
				scene_manager.current_scene.nodes[editor.selected_entity] = node
				scene_manager.current_scene.dirty = true
			}

			// Tags section
			if imgui.CollapsingHeader("Tags", {imgui.TreeNodeFlag.DefaultOpen}) {
				// Add tag button
				if imgui.Button("Add Tag") {
					// TODO: Implement tag adding
				}

				// Display existing tags
				// TODO: Implement tag display and removal
			}
		}
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
		if imgui.MenuItem("Renderer") {
			if renderer := create_component(.RENDERER, editor.selected_entity); renderer != nil {
				ecs_add_component(editor.selected_entity, renderer)
			}
		}
		if imgui.MenuItem("Camera") {
			if camera := create_component(.CAMERA, editor.selected_entity); camera != nil {
				ecs_add_component(editor.selected_entity, camera)
			}
		}
		if imgui.MenuItem("Light") {
			if light := create_component(.LIGHT, editor.selected_entity); light != nil {
				ecs_add_component(editor.selected_entity, light)
			}
		}
		if imgui.MenuItem("Script") {
			if script := create_component(.SCRIPT, editor.selected_entity); script != nil {
				ecs_add_component(editor.selected_entity, script)
			}
		}
		imgui.EndPopup()
	}
}
