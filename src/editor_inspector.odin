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

	// Selected entity inspector
	if editor.selected_entity == 0 {
		imgui.Text("No entity selected")
		return
	}

	// Entity metadata section
	if imgui.CollapsingHeader("Entity", {imgui.TreeNodeFlag.DefaultOpen}) {
		// Entity name input
		name := ecs_get_entity_name(editor.selected_entity)
		name_buf: [256]u8
		copy(name_buf[:], name)
		if imgui.InputText(
			"Name",
			cstring(raw_data(name_buf[:])),
			len(name_buf),
			{imgui.InputTextFlag.EnterReturnsTrue},
		) {
			// Convert buffer to string properly by finding the null terminator
			name_str := ""
			for i := 0; i < len(name_buf); i += 1 {
				if name_buf[i] == 0 {
					name_str = string(name_buf[:i])
					break
				}
			}

			// Make sure we got a valid name
			if len(name_str) > 0 {
				ecs_set_entity_name(editor.selected_entity, name_str)
			} else {
				// If empty, revert to default name based on entity ID
				default_name := fmt.tprintf("Entity_%d", editor.selected_entity)
				ecs_set_entity_name(editor.selected_entity, default_name)
			}
		}

		// Active toggle
		active := ecs_is_entity_active(editor.selected_entity)
		if imgui.Checkbox("Active", &active) {
			ecs_set_entity_active(editor.selected_entity, active)
		}

		// Tags
		tags := ecs_get_entity_tags(editor.selected_entity)
		tag_label := fmt.caprintf("%s", len(tags) > 0 ? tags[0] : "No Tags")
		defer delete(tag_label)
		if imgui.BeginCombo("Tags", tag_label) {
			for tag in tags {
				tag_cstr := strings.clone_to_cstring(tag)
				defer delete(tag_cstr)
				if imgui.Selectable(tag_cstr) {
					// TODO: Handle tag selection
				}
			}
			if imgui.MenuItem("Add Tag") {
				// TODO: Implement tag adding
			}
			imgui.EndCombo()
		}
	}

	// Component inspectors
	if transform := ecs_get_component(editor.selected_entity, Transform); transform != nil {
		transform_render_inspector(cast(^Transform)transform)
	}

	if renderer := ecs_get_component(editor.selected_entity, Renderer); renderer != nil {
		renderer_render_inspector(cast(^Renderer)renderer)
	}

	if camera := ecs_get_component(editor.selected_entity, Camera); camera != nil {
		camera_render_inspector(cast(^Camera)camera)
	}

	if light := ecs_get_component(editor.selected_entity, Light); light != nil {
		light_render_inspector(cast(^Light)light)
	}

	if script := ecs_get_component(editor.selected_entity, Script); script != nil {
		script_render_inspector(cast(^Script)script)
	}

	// Add component button
	if imgui.Button("Add Component") {
		imgui.OpenPopup("AddComponent")
	}

	if imgui.BeginPopup("AddComponent") {
		if !ecs_has_component(editor.selected_entity, Renderer) {
			if imgui.MenuItem("Renderer") {
				_ = ecs_add_renderer(editor.selected_entity)
			}
		}
		if !ecs_has_component(editor.selected_entity, Camera) {
			if imgui.MenuItem("Camera") {
				_ = ecs_add_camera(editor.selected_entity)
			}
		}
		if !ecs_has_component(editor.selected_entity, Light) {
			if imgui.MenuItem("Light") {
				_ = ecs_add_light(editor.selected_entity)
			}
		}
		if !ecs_has_component(editor.selected_entity, Script) {
			if imgui.MenuItem("Script") {
				_ = ecs_add_script(editor.selected_entity)
			}
		}
		imgui.EndPopup()
	}
}
