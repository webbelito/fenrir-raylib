package main

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:strings"
import raylib "vendor:raylib"

// Model types that can be rendered
Model_Type :: enum {
	CUBE,
	AMBULANCE,
}

// Renderer component
Renderer :: struct {
	using _base:    Component,
	model_type:     Model_Type,
	mesh:           string, // Path to mesh
	material:       string, // Path to material
	visible:        bool,
	mesh_path:      string,
	material_path:  string,
	material_color: [3]f32,
}

// Add renderer component to an entity
ecs_add_renderer :: proc(entity: Entity, mesh: string = "", material: string = "") -> ^Renderer {
	if !ecs_has_component(entity, .RENDERER) {
		renderer := Renderer {
			_base = Component{type = .RENDERER, entity = entity, enabled = true},
			model_type = .CUBE, // Default to cube
			visible = true,
			mesh = mesh,
			material = material,
		}
		entity_manager.renderers[entity] = renderer
		return &entity_manager.renderers[entity]
	}
	return nil
}

// Get renderer component from an entity
ecs_get_renderer :: proc(entity: Entity) -> ^Renderer {
	if ecs_has_component(entity, .RENDERER) {
		return &entity_manager.renderers[entity]
	}
	return nil
}

// Get all entities with renderer component
ecs_get_renderers :: proc() -> map[Entity]Renderer {
	return entity_manager.renderers
}

// Render renderer component in inspector
renderer_render_inspector :: proc(renderer: ^Renderer) {
	if imgui.CollapsingHeader("Renderer") {
		imgui.PushItemWidth(-1)
		imgui.Checkbox("Visible", &renderer.visible)

		// Model type selection
		current_type := renderer.model_type
		type_str := fmt.tprintf("%v", current_type)
		if imgui.BeginCombo("Model Type", strings.clone_to_cstring(type_str)) {
			if imgui.Selectable("Cube", current_type == .CUBE) {
				renderer.model_type = .CUBE
			}
			if imgui.Selectable("Ambulance", current_type == .AMBULANCE) {
				renderer.model_type = .AMBULANCE
			}
			imgui.EndCombo()
		}

		// Material color
		imgui.ColorEdit3("Material Color", &renderer.material_color)

		// Mesh path with file browser
		imgui.Text("Mesh Path:")
		imgui.SameLine()
		if imgui.Button("Browse##Mesh") {
			// TODO: Implement file browser
		}
		imgui.Text(strings.clone_to_cstring(renderer.mesh_path))

		// Material path with file browser
		imgui.Text("Material Path:")
		imgui.SameLine()
		if imgui.Button("Browse##Material") {
			// TODO: Implement file browser
		}
		imgui.Text(strings.clone_to_cstring(renderer.material_path))

		imgui.PopItemWidth()
	}
}
