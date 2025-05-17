package main

import math "core:math"
import raylib "vendor:raylib"

// Camera component for viewing the scene
Camera :: struct {
	fov:     f32, // Field of view in degrees
	near:    f32, // Near clip plane
	far:     f32, // Far clip plane
	is_main: bool, // Whether this is the main camera
}

// Create a default camera
camera_create :: proc() -> Camera {
	return Camera{fov = 60.0, near = 0.1, far = 1000.0, is_main = false}
}

// Set camera field of view
camera_set_fov :: proc(camera: ^Camera, fov: f32) {
	camera.fov = fov
}

// Set camera near clip plane
camera_set_near :: proc(camera: ^Camera, near: f32) {
	camera.near = near
}

// Set camera far clip plane
camera_set_far :: proc(camera: ^Camera, far: f32) {
	camera.far = far
}

// Set camera as main camera
camera_set_main :: proc(camera: ^Camera, registry: ^Component_Registry, entity: Entity) {
	// First clear any existing main cameras
	entities := component_registry_view_single(registry, Camera)
	defer delete(entities)

	for cam_entity in entities {
		if cam_entity != entity {
			cam := component_registry_get(registry, cam_entity, Camera)
			if cam != nil && cam.is_main {
				cam.is_main = false
			}
		}
	}

	// Set this camera as main
	camera.is_main = true
}

// Get main camera entity from registry
camera_get_main :: proc(registry: ^Component_Registry, allocator := context.allocator) -> Entity {
	entities := component_registry_view_single(registry, Camera, allocator)
	defer delete(entities)

	for entity in entities {
		camera := component_registry_get(registry, entity, Camera)
		if camera != nil && camera.is_main {
			return entity
		}
	}

	return 0 // No main camera found
}

// Create a raylib Camera3D from a camera component and transform
camera_create_camera3d :: proc(camera: ^Camera, transform: ^Transform) -> raylib.Camera3D {
	// Calculate position from transform
	position := transform.position

	// Calculate forward direction from rotation
	forward := raylib.Vector3 {
		math.sin(math.to_radians(transform.rotation.y)) *
		math.cos(math.to_radians(transform.rotation.x)),
		-math.sin(math.to_radians(transform.rotation.x)),
		math.cos(math.to_radians(transform.rotation.y)) *
		math.cos(math.to_radians(transform.rotation.x)),
	}

	// Target is position + forward
	target := position + forward

	// Up vector is just world up for now
	up := raylib.Vector3{0, 1, 0}

	return raylib.Camera3D {
		position = position,
		target = target,
		up = up,
		fovy = camera.fov,
		projection = .PERSPECTIVE,
	}
}
