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
	using _base: Component,
	model_type:  Model_Type,
	mesh:        string, // Path to mesh
	material:    string, // Path to material
	visible:     bool,
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
		imgui.Checkbox("Visible", &renderer.visible)

		// Model type selection
		current_type := renderer.model_type
		type_str := fmt.tprintf("%v", current_type)
		if imgui.BeginCombo("Model Type", strings.clone_to_cstring(type_str)) {
			if imgui.Selectable("Cube", current_type == .CUBE) {
				renderer.model_type = .CUBE
				renderer.mesh = "cube"
				renderer.material = ""
			}
			if imgui.Selectable("Ambulance", current_type == .AMBULANCE) {
				renderer.model_type = .AMBULANCE
				renderer.mesh = "assets/meshes/ambulance.glb"
				renderer.material = "assets/meshes/Textures/colormap.png"
			}
			imgui.EndCombo()
		}

		imgui.Text("Mesh: %s", renderer.mesh)
		imgui.Text("Material: %s", renderer.material)
	}
}
