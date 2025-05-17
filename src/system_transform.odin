package main

import "core:math"
import "core:slice"
import "core:sort"
import raylib "vendor:raylib"

// Transform node for hierarchical sorting
Transform_Node :: struct {
	entity: Entity,
	parent: Entity,
	depth:  int,
}

// Initialize the transform system
transform_system_init :: proc(registry: ^Component_Registry) {
	log_info(.ENGINE, "Transform system initialized")
}

// Update transform hierarchy
transform_system_update :: proc(registry: ^Component_Registry, dt: f32) {
	// Get all entities with transform components
	entities := component_registry_view_single(registry, Transform)
	defer delete(entities)

	// Identity matrix for root entities
	identity_matrix := raylib.Matrix(1)

	// First pass: update root entities (no parent)
	for entity in entities {
		transform := component_registry_get(registry, entity, Transform)
		if transform.parent == 0 {
			// Update local matrix
			update_local_transform_matrix(transform)

			// For root entities, world = local
			transform.world_matrix = transform.local_matrix
		}
	}

	// Build a list of child entities with their parents for sorting
	transform_nodes := make([dynamic]Transform_Node)
	defer delete(transform_nodes)

	for entity in entities {
		transform := component_registry_get(registry, entity, Transform)
		if transform.parent != 0 {
			append(
				&transform_nodes,
				Transform_Node {
					entity = entity,
					parent = transform.parent,
					depth = calculate_hierarchy_depth(registry, entity),
				},
			)
		}
	}

	// Sort by depth to ensure parents are processed before children
	sort.quick_sort_proc(transform_nodes[:], proc(a, b: Transform_Node) -> int {
			if a.depth < b.depth do return -1
			if a.depth > b.depth do return 1
			return 0
		})

	// Second pass: update children in hierarchy order
	for node in transform_nodes {
		transform := component_registry_get(registry, node.entity, Transform)
		parent_transform := component_registry_get(registry, transform.parent, Transform)

		// Update local matrix
		update_local_transform_matrix(transform)

		if parent_transform != nil {
			// Calculate world matrix by combining with parent's world matrix
			transform.world_matrix = transform.local_matrix * parent_transform.world_matrix
		} else {
			// Parent entity exists but doesn't have a transform - use identity
			transform.world_matrix = transform.local_matrix
		}
	}
}

// Update local transform matrix from position, rotation, scale
update_local_transform_matrix :: proc(transform: ^Transform) {
	if !transform.dirty {
		return
	}

	// Calculate rotation matrix (using Euler angles in XYZ order)
	rotation_radians := raylib.Vector3 {
		math.to_radians(transform.rotation.x),
		math.to_radians(transform.rotation.y),
		math.to_radians(transform.rotation.z),
	}
	rotation_matrix := raylib.MatrixRotateXYZ(rotation_radians)

	// Calculate scale matrix
	scale_matrix := raylib.MatrixScale(transform.scale.x, transform.scale.y, transform.scale.z)

	// Calculate translation matrix
	translation_matrix := raylib.MatrixTranslate(
		transform.position.x,
		transform.position.y,
		transform.position.z,
	)

	// Combine matrices: scale, then rotate, then translate
	transform.local_matrix = (scale_matrix * rotation_matrix) * translation_matrix

	transform.dirty = false
}

// Calculate depth in hierarchy (root = 0)
calculate_hierarchy_depth :: proc(registry: ^Component_Registry, entity: Entity) -> int {
	depth := 0
	current := entity

	for {
		transform := component_registry_get(registry, current, Transform)
		if transform == nil || transform.parent == 0 {
			break
		}

		current = transform.parent
		depth += 1

		// Prevent infinite loops in case of circular references
		if depth > 100 {
			log_warning(
				.ENGINE,
				"Possible circular hierarchy reference detected for entity %d",
				entity,
			)
			break
		}
	}

	return depth
}

// Shutdown the transform system
transform_system_shutdown :: proc(registry: ^Component_Registry) {
	log_info(.ENGINE, "Transform system shut down")
}

// Create transform system
transform_system_create :: proc() -> System {
	return System {
		name         = "Transform",
		init         = transform_system_init,
		update       = transform_system_update,
		fixed_update = nil, // Transform doesn't need fixed update
		shutdown     = transform_system_shutdown,
		enabled      = true,
		priority     = 100, // High priority - should run before other systems
	}
}
