package main

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:strings"
import raylib "vendor:raylib"

// Light types
Light_Type :: enum {
	DIRECTIONAL,
	POINT,
	SPOT,
}

// Light component
Light :: struct {
	using _base: Component,
	light_type:  Light_Type,
	color:       [3]f32, // RGB color values (0-1)
	intensity:   f32,
	range:       f32,
	spot_angle:  f32, // Only for spot lights
}

// Add light component to an entity
ecs_add_light :: proc(
	entity: Entity,
	light_type: Light_Type = .POINT,
	color: [3]f32 = {1, 1, 1},
	intensity: f32 = 1.0,
	range: f32 = 10.0,
	spot_angle: f32 = 45.0,
) -> ^Light {
	if !ecs_has_component(entity, .LIGHT) {
		light := Light {
			_base = Component{type = .LIGHT, entity = entity, enabled = true},
			light_type = light_type,
			color = color,
			intensity = intensity,
			range = range,
			spot_angle = spot_angle,
		}
		entity_manager.lights[entity] = light
		return &entity_manager.lights[entity]
	}
	return nil
}

// Get light component from an entity
ecs_get_light :: proc(entity: Entity) -> ^Light {
	if ecs_has_component(entity, .LIGHT) {
		return &entity_manager.lights[entity]
	}
	return nil
}

// Get all entities with light component
ecs_get_lights :: proc() -> map[Entity]Light {
	return entity_manager.lights
}

// Render light component in inspector
light_render_inspector :: proc(light: ^Light) {
	if imgui.CollapsingHeader("Light") {
		// Light type selection
		current_type := light.light_type
		type_str := fmt.tprintf("%v", current_type)
		if imgui.BeginCombo("Type", strings.clone_to_cstring(type_str)) {
			if imgui.Selectable("Directional", current_type == .DIRECTIONAL) {
				light.light_type = .DIRECTIONAL
			}
			if imgui.Selectable("Point", current_type == .POINT) {
				light.light_type = .POINT
			}
			if imgui.Selectable("Spot", current_type == .SPOT) {
				light.light_type = .SPOT
			}
			imgui.EndCombo()
		}

		imgui.PushItemWidth(-1)
		imgui.ColorEdit3("Color", &light.color)
		imgui.DragFloat("Intensity", &light.intensity, 0.1)
		imgui.DragFloat("Range", &light.range, 0.1)

		// Only show spot angle for spot lights
		if light.light_type == .SPOT {
			imgui.DragFloat("Spot Angle", &light.spot_angle, 0.1)
		}
		imgui.PopItemWidth()
	}
}
