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

	// Entity selection and creation
	if imgui.Button("Create Entity") {
		imgui.OpenPopup("CreateEntityPopup")
	}

	if imgui.BeginPopup("CreateEntityPopup") {
		if imgui.MenuItem("Empty") {
			entity := ecs_create_entity("Empty")
			editor.selected_entity = entity
		}
		if imgui.BeginMenu("3D Object") {
			if imgui.MenuItem("Cube") {
				entity := ecs_create_entity("Cube")
				transform := ecs_add_transform(entity)
				renderer := ecs_add_renderer(entity)
				if transform != nil && renderer != nil {
					renderer.model_type = .CUBE
					renderer.mesh_path = "cube"
					renderer.material_path = "default"
				}
				editor.selected_entity = entity
			}
			if imgui.MenuItem("Ambulance") {
				entity := ecs_create_entity("Ambulance")
				transform := ecs_add_transform(entity)
				renderer := ecs_add_renderer(entity)
				if transform != nil && renderer != nil {
					renderer.model_type = .AMBULANCE
					renderer.mesh_path = "assets/meshes/ambulance.glb"
					renderer.material_path = "assets/meshes/Textures/colormap.png"
				}
				editor.selected_entity = entity
			}
			imgui.EndMenu()
		}
		if imgui.BeginMenu("Light") {
			if imgui.MenuItem("Directional Light") {
				entity := ecs_create_entity("Directional Light")
				transform := ecs_add_transform(entity)
				light := ecs_add_light(entity, .DIRECTIONAL)
				if transform != nil && light != nil {
					editor.selected_entity = entity
				}
			}
			if imgui.MenuItem("Point Light") {
				entity := ecs_create_entity("Point Light")
				transform := ecs_add_transform(entity)
				light := ecs_add_light(entity, .POINT)
				if transform != nil && light != nil {
					editor.selected_entity = entity
				}
			}
			if imgui.MenuItem("Spot Light") {
				entity := ecs_create_entity("Spot Light")
				transform := ecs_add_transform(entity)
				light := ecs_add_light(entity, .SPOT)
				if transform != nil && light != nil {
					editor.selected_entity = entity
				}
			}
			imgui.EndMenu()
		}
		if imgui.MenuItem("Camera") {
			entity := ecs_create_entity("Camera")
			transform := ecs_add_transform(entity)
			camera := ecs_add_camera(entity, 45.0, 0.1, 1000.0, true)
			if transform != nil && camera != nil {
				editor.selected_entity = entity
			}
		}
		imgui.EndPopup()
	}

	imgui.Separator()

	// Entity list
	if imgui.CollapsingHeader("Entities", {imgui.TreeNodeFlag.DefaultOpen}) {
		for entity in scene_manager.current_scene.entities {
			name := ecs_get_entity_name(entity)
			label := fmt.caprintf("%s###entity_%d", name, entity)
			defer delete(label)
			if imgui.Selectable(label, editor.selected_entity == entity) {
				editor.selected_entity = entity
			}
		}
	}

	imgui.Separator()

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
			ecs_set_entity_name(editor.selected_entity, string(name_buf[:]))
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
	if transform := ecs_get_component(editor.selected_entity, .TRANSFORM); transform != nil {
		transform_render_inspector(cast(^Transform_Component)transform)
	}

	if renderer := ecs_get_component(editor.selected_entity, .RENDERER); renderer != nil {
		renderer_render_inspector(cast(^Renderer)renderer)
	}

	if camera := ecs_get_component(editor.selected_entity, .CAMERA); camera != nil {
		camera_render_inspector(cast(^Camera)camera)
	}

	if light := ecs_get_component(editor.selected_entity, .LIGHT); light != nil {
		light_render_inspector(cast(^Light)light)
	}

	if script := ecs_get_component(editor.selected_entity, .SCRIPT); script != nil {
		script_render_inspector(cast(^Script)script)
	}

	// Add component button
	if imgui.Button("Add Component") {
		imgui.OpenPopup("AddComponent")
	}

	if imgui.BeginPopup("AddComponent") {
		if !ecs_has_component(editor.selected_entity, .RENDERER) {
			if imgui.MenuItem("Renderer") {
				if renderer := create_component(.RENDERER, editor.selected_entity);
				   renderer != nil {
					ecs_add_component(editor.selected_entity, renderer)
				}
			}
		}
		if !ecs_has_component(editor.selected_entity, .CAMERA) {
			if imgui.MenuItem("Camera") {
				if camera := create_component(.CAMERA, editor.selected_entity); camera != nil {
					ecs_add_component(editor.selected_entity, camera)
				}
			}
		}
		if !ecs_has_component(editor.selected_entity, .LIGHT) {
			if imgui.MenuItem("Light") {
				if light := create_component(.LIGHT, editor.selected_entity); light != nil {
					ecs_add_component(editor.selected_entity, light)
				}
			}
		}
		if !ecs_has_component(editor.selected_entity, .SCRIPT) {
			if imgui.MenuItem("Script") {
				if script := create_component(.SCRIPT, editor.selected_entity); script != nil {
					ecs_add_component(editor.selected_entity, script)
				}
			}
		}
		imgui.EndPopup()
	}
}
