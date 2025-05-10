package main

import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:strings"
import raylib "vendor:raylib"

// Camera component
ProjectionType :: enum {
	PERSPECTIVE,
	ORTHOGRAPHIC,
}

Camera :: struct {
	using _base:       Component,
	fov:               f32,
	near:              f32,
	far:               f32,
	is_main:           bool,
	projection_type:   ProjectionType,
	orthographic_size: f32,
}

// Add camera component to an entity
ecs_add_camera :: proc(
	entity: Entity,
	fov: f32 = 45.0,
	near: f32 = 0.1,
	far: f32 = 1000.0,
	is_main: bool = false,
) -> ^Camera {
	if !ecs_has_component(entity, .CAMERA) {
		camera := Camera {
			_base = Component{type = .CAMERA, entity = entity, enabled = true},
			fov = fov,
			near = near,
			far = far,
			is_main = is_main,
		}
		entity_manager.cameras[entity] = camera
		return &entity_manager.cameras[entity]
	}
	return nil
}

// Get camera component from an entity
ecs_get_camera :: proc(entity: Entity) -> ^Camera {
	if ecs_has_component(entity, .CAMERA) {
		return &entity_manager.cameras[entity]
	}
	return nil
}

// Get all entities with camera component
ecs_get_cameras :: proc() -> map[Entity]Camera {
	return entity_manager.cameras
}

// Get the main camera entity
ecs_get_main_camera :: proc() -> Entity {
	for entity, camera in entity_manager.cameras {
		if camera.is_main {
			return entity
		}
	}
	return 0
}

// Render camera component in inspector
camera_render_inspector :: proc(camera: ^Camera) {
	if render_component_header("Camera", camera.entity, .CAMERA) {
		// Projection type selection
		current_type := camera.projection_type
		type_str := fmt.tprintf("%v", current_type)
		if imgui.BeginCombo("Projection", strings.clone_to_cstring(type_str)) {
			if imgui.Selectable("Perspective", current_type == .PERSPECTIVE) {
				camera.projection_type = .PERSPECTIVE
			}
			if imgui.Selectable("Orthographic", current_type == .ORTHOGRAPHIC) {
				camera.projection_type = .ORTHOGRAPHIC
			}
			imgui.EndCombo()
		}

		imgui.PushItemWidth(-1)
		imgui.DragFloat("FOV", &camera.fov, 0.1)
		imgui.DragFloat("Near", &camera.near, 0.1)
		imgui.DragFloat("Far", &camera.far, 0.1)

		// Only show orthographic size for orthographic cameras
		if camera.projection_type == .ORTHOGRAPHIC {
			imgui.DragFloat("Orthographic Size", &camera.orthographic_size, 0.1)
		}

		imgui.Checkbox("Main Camera", &camera.is_main)
		imgui.PopItemWidth()
	}
}
