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
	imgui.PushStyleVarImVec2(imgui.StyleVar.FramePadding, imgui.Vec2{4, 4})
	imgui.PushStyleVarImVec2(imgui.StyleVar.ItemSpacing, imgui.Vec2{8, 8})

	// Entity name
	name := ecs_get_entity_name(editor.selected_entity)
	name_buffer: [256]u8
	copy(name_buffer[:], transmute([]u8)name)
	if imgui.InputText(
		"##EntityName",
		cstring(raw_data(name_buffer[:])),
		len(name_buffer),
		imgui.InputTextFlags{.EnterReturnsTrue},
	) {
		ecs_set_entity_name(editor.selected_entity, string(name_buffer[:]))
	}

	// Active toggle
	is_active := ecs_is_entity_active(editor.selected_entity)
	if imgui.Checkbox("Active", &is_active) {
		ecs_set_entity_active(editor.selected_entity, is_active)
	}

	// Tags
	imgui.Separator()
	imgui.Text("Tags")
	tags := ecs_get_entity_tags(editor.selected_entity)
	for tag in tags {
		imgui.SameLine()
		imgui.PushStyleColor(imgui.Col.Button, 0xFF2D2D2D)
		imgui.PushStyleColor(imgui.Col.ButtonHovered, 0xFF3D3D3D)
		imgui.PushStyleColor(imgui.Col.ButtonActive, 0xFF4D4D4D)
		if imgui.Button(strings.clone_to_cstring(tag), imgui.Vec2{0, 20}) {
			ecs_remove_entity_tag(editor.selected_entity, tag)
		}
		imgui.PopStyleColor(3)
	}

	// Add tag button
	imgui.SameLine()
	if imgui.Button("+", imgui.Vec2{20, 20}) {
		imgui.OpenPopup("AddTag")
	}

	if imgui.BeginPopup("AddTag") {
		tag_buffer: [64]u8
		if imgui.InputText(
			"##NewTag",
			cstring(raw_data(tag_buffer[:])),
			len(tag_buffer),
			imgui.InputTextFlags{.EnterReturnsTrue},
		) {
			if len(tag_buffer) > 0 {
				ecs_add_entity_tag(editor.selected_entity, string(tag_buffer[:]))
			}
			imgui.CloseCurrentPopup()
		}
		imgui.EndPopup()
	}

	imgui.PopStyleVar(2)
	imgui.Separator()
	imgui.Spacing()

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
