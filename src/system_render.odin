package main

import "core:fmt"
import "core:math"
import raylib "vendor:raylib"

// Initialize the render system
render_system_init :: proc(registry: ^Component_Registry) {
	log_info(.ENGINE, "Render system initialized")
}

// Update render state (like animations, etc.)
render_system_update :: proc(registry: ^Component_Registry, dt: f32) {
	// Any per-frame updates to renderable entities
	// This could include things like material updates, animation blending, etc.
}

// Render all renderable entities
render_system_render :: proc(registry: ^Component_Registry, camera: raylib.Camera3D) {
	// Begin 3D mode with the provided camera
	raylib.BeginMode3D(camera)
	defer raylib.EndMode3D()

	// Draw a grid for reference
	raylib.DrawGrid(10, 1.0)

	// Get all entities with both transform and renderer components
	entities := component_registry_view_pair(registry, Transform, Renderer)
	defer delete(entities)

	// Render each entity
	for entity in entities {
		transform := component_registry_get(registry, entity, Transform)
		renderer := component_registry_get(registry, entity, Renderer)

		// Skip disabled renderers
		if !renderer.visible {
			continue
		}

		// Get world position from transform
		position := raylib.Vector3 {
			transform.world_matrix[3][0], // x position (m03 in traditional notation)
			transform.world_matrix[3][1], // y position (m13 in traditional notation)
			transform.world_matrix[3][2], // z position (m23 in traditional notation)
		}

		// Render based on model type
		#partial switch renderer.model_type {
		case .CUBE:
			raylib.DrawCube(position, 1.0, 1.0, 1.0, raylib.WHITE)

		case .SPHERE:
			raylib.DrawSphere(position, 0.5, raylib.WHITE)

		case .PLANE:
			raylib.DrawPlane(position, {1.0, 1.0}, raylib.WHITE)

		case .AMBULANCE, .CUSTOM:
			if model, ok := asset_manager.models[renderer.mesh_path]; ok {
				// Create transform matrix from world matrix
				model_copy := model.model
				model_copy.transform = transform.world_matrix

				// Draw model
				raylib.DrawModel(model_copy, {0, 0, 0}, 1.0, raylib.WHITE)
			}
		}

		// Draw wireframe bounding box if entity is selected
		if editor.selected_entity == entity {
			raylib.DrawCubeWires(position, 1.2, 1.2, 1.2, raylib.RED)
		}
	}

	// Render lights (if we're in editor mode)
	if !engine.playing {
		render_light_gizmos(registry)
	}
}

// Render light gizmos in editor mode
render_light_gizmos :: proc(registry: ^Component_Registry) {
	// Get all entities with both transform and light components
	light_entities := component_registry_view_pair(registry, Transform, Light)
	defer delete(light_entities)

	for entity in light_entities {
		transform := component_registry_get(registry, entity, Transform)
		light := component_registry_get(registry, entity, Light)

		position := raylib.Vector3 {
			transform.world_matrix[3][0], // x position (m03 in traditional notation)
			transform.world_matrix[3][1], // y position (m13 in traditional notation)
			transform.world_matrix[3][2], // z position (m23 in traditional notation)
		}

		// Draw different gizmos based on light type
		#partial switch light.light_type {
		case .DIRECTIONAL:
			// Draw a sun-like symbol for directional lights
			raylib.DrawSphere(position, 0.2, raylib.YELLOW)

			// Draw direction indicator
			forward := raylib.Vector3 {
				math.sin(transform.rotation.y) * math.cos(transform.rotation.x),
				-math.sin(transform.rotation.x),
				math.cos(transform.rotation.y) * math.cos(transform.rotation.x),
			}
			raylib.DrawLine3D(position, position + forward, raylib.YELLOW)

		case .POINT:
			// Draw a small sphere for point lights
			raylib.DrawSphere(
				position,
				0.2,
				raylib.Color {
					u8(light.color.x * 255),
					u8(light.color.y * 255),
					u8(light.color.z * 255),
					255,
				},
			)

			// Draw range indicator (wireframe)
			raylib.DrawSphereWires(
				position,
				light.range,
				8,
				8,
				raylib.Color {
					u8(light.color.x * 128),
					u8(light.color.y * 128),
					u8(light.color.z * 128),
					128,
				},
			)

		case .SPOT:
			// Draw a cone for spot lights
			raylib.DrawSphere(
				position,
				0.2,
				raylib.Color {
					u8(light.color.x * 255),
					u8(light.color.y * 255),
					u8(light.color.z * 255),
					255,
				},
			)

			// Draw cone direction
			forward := raylib.Vector3 {
				math.sin(transform.rotation.y) * math.cos(transform.rotation.x),
				-math.sin(transform.rotation.x),
				math.cos(transform.rotation.y) * math.cos(transform.rotation.x),
			}

			// TODO: Draw proper cone visualization - this is simplified
			raylib.DrawLine3D(
				position,
				position + forward * light.range,
				raylib.Color {
					u8(light.color.x * 255),
					u8(light.color.y * 255),
					u8(light.color.z * 255),
					255,
				},
			)
		}

		// Highlight selected light
		if editor.selected_entity == entity {
			raylib.DrawSphereWires(position, 0.3, 8, 8, raylib.RED)
		}
	}
}

// Shutdown the render system
render_system_shutdown :: proc(registry: ^Component_Registry) {
	log_info(.ENGINE, "Render system shut down")
}

// Create render system
render_system_create :: proc() -> System {
	return System {
		name         = "Render",
		init         = render_system_init,
		update       = render_system_update,
		fixed_update = nil, // Render doesn't need fixed update
		shutdown     = render_system_shutdown,
		enabled      = true,
		priority     = 500, // Lower priority - should run after transform system
	}
}
