package main

import "core:math"
import raylib "vendor:raylib"

// Transform component - position, rotation, scale data
Transform :: struct {
	position:     raylib.Vector3, // Position in local space
	rotation:     raylib.Vector3, // Rotation in Euler angles (degrees)
	scale:        raylib.Vector3, // Scale factors
	local_matrix: raylib.Matrix, // Cached local transform matrix
	world_matrix: raylib.Matrix, // Cached world transform matrix
	parent:       Entity, // Parent entity or 0 for root
	dirty:        bool, // Flag to indicate matrix needs updating
}

// Create a default transform
transform_create :: proc() -> Transform {
	return Transform {
		position = {0, 0, 0},
		rotation = {0, 0, 0},
		scale = {1, 1, 1},
		local_matrix = raylib.Matrix(1),
		world_matrix = raylib.Matrix(1),
		parent = 0,
		dirty = true,
	}
}

// Set transform position
transform_set_position :: proc(transform: ^Transform, position: raylib.Vector3) {
	transform.position = position
	transform.dirty = true
}

// Set transform rotation
transform_set_rotation :: proc(transform: ^Transform, rotation: raylib.Vector3) {
	transform.rotation = rotation
	transform.dirty = true
}

// Set transform scale
transform_set_scale :: proc(transform: ^Transform, scale: raylib.Vector3) {
	transform.scale = scale
	transform.dirty = true
}

// Set transform parent
transform_set_parent :: proc(
	registry: ^Component_Registry,
	entity: Entity,
	parent: Entity,
) -> bool {
	transform := component_registry_get(registry, entity, Transform)
	if transform == nil {
		return false
	}

	// Prevent self-parenting
	if entity == parent {
		log_warning(.ENGINE, "Cannot parent entity %d to itself", entity)
		return false
	}

	// Prevent circular parenting
	current := parent
	depth := 0
	for current != 0 {
		if current == entity {
			log_warning(.ENGINE, "Circular parent reference detected: %d -> %d", entity, parent)
			return false
		}

		// Get parent's parent
		parent_transform := component_registry_get(registry, current, Transform)
		if parent_transform == nil {
			break
		}

		current = parent_transform.parent
		depth += 1

		// Prevent infinite loops
		if depth > 100 {
			log_warning(.ENGINE, "Hierarchy depth limit reached")
			break
		}
	}

	// Set the parent
	transform.parent = parent
	transform.dirty = true

	return true
}

// Update the transform matrices
transform_update_matrices :: proc(transform: ^Transform) {
	if !transform.dirty {
		return
	}

	// Create rotation matrix (using Euler angles in XYZ order)
	rotation_radians := raylib.Vector3 {
		math.to_radians(transform.rotation.x),
		math.to_radians(transform.rotation.y),
		math.to_radians(transform.rotation.z),
	}
	rotation_matrix := raylib.MatrixRotateXYZ(rotation_radians)

	// Create scale matrix
	scale_matrix := raylib.MatrixScale(transform.scale.x, transform.scale.y, transform.scale.z)

	// Create translation matrix
	translation_matrix := raylib.MatrixTranslate(
		transform.position.x,
		transform.position.y,
		transform.position.z,
	)

	// Combine matrices: scale, then rotate, then translate
	transform.local_matrix = scale_matrix * rotation_matrix * translation_matrix

	transform.dirty = false
}

// Look at a target point
transform_look_at :: proc(
	transform: ^Transform,
	target: raylib.Vector3,
	up: raylib.Vector3 = {0, 1, 0},
) {
	// Calculate direction
	direction := target - transform.position
	direction = raylib.Vector3Normalize(direction)

	// Calculate rotation angles
	if math.abs(direction.y) > 0.99 {
		// Looking straight up or down
		transform.rotation.x = direction.y > 0 ? -90 : 90
		transform.rotation.y = 0
	} else {
		// Normal case
		transform.rotation.x = math.to_degrees(-math.asin(direction.y))
		transform.rotation.y = math.to_degrees(math.atan2(direction.x, direction.z))
	}

	transform.dirty = true
}
