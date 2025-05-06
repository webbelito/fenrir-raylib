package main

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import raylib "vendor:raylib"

// Renderer component
Renderer :: struct {
	using _base: Component,
	mesh:        string, // Path to mesh
	material:    string, // Path to material
	visible:     bool,
}

// Add renderer component to an entity
ecs_add_renderer :: proc(entity: Entity, mesh: string = "", material: string = "") -> ^Renderer {
	if !ecs_has_component(entity, .RENDERER) {
		renderer := Renderer {
			_base = Component{type = .RENDERER, entity = entity, enabled = true},
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
		imgui.Text("Mesh: %s", renderer.mesh)
		imgui.Text("Material: %s", renderer.material)
	}
}
