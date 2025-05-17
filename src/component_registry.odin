package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:slice"

// Registry holds all components and entities
Component_Registry :: struct {
	// Map of type ID to component storage
	storages:          map[typeid]rawptr,
	// Map of type ID to storage destruction callbacks
	destroy_callbacks: map[typeid]proc(_: rawptr),
}

// Initialize the component registry
component_registry_init :: proc() -> Component_Registry {
	return Component_Registry {
		storages = make(map[typeid]rawptr),
		destroy_callbacks = make(map[typeid]proc(_: rawptr)),
	}
}

// Destroy the component registry
component_registry_destroy :: proc(registry: ^Component_Registry) {
	// Free all component storages
	for type_id, storage in registry.storages {
		if destroy_callback, has_callback := registry.destroy_callbacks[type_id]; has_callback {
			destroy_callback(storage)
		}
	}

	delete(registry.storages)
	delete(registry.destroy_callbacks)
}

// Register a component type
component_registry_register :: proc(registry: ^Component_Registry, $T: typeid) {
	if typeid_of(T) in registry.storages {
		return // Already registered
	}

	storage := component_storage_init(T)
	registry.storages[typeid_of(T)] = storage

	// Register destruction callback
	registry.destroy_callbacks[typeid_of(T)] = proc(storage: rawptr) {
		component_storage_destroy(cast(^Component_Storage(T))storage)
	}
}

// Get storage for a component type
component_registry_get_storage :: proc(
	registry: ^Component_Registry,
	$T: typeid,
) -> ^Component_Storage(T) {
	if storage, ok := registry.storages[typeid_of(T)]; ok {
		return cast(^Component_Storage(T))storage
	}

	// Auto-register if not found
	component_registry_register(registry, T)
	return cast(^Component_Storage(T))registry.storages[typeid_of(T)]
}

// Add a component to an entity
component_registry_add :: proc(
	registry: ^Component_Registry,
	entity: Entity,
	$T: typeid,
	component: T,
) -> ^T {
	storage := component_registry_get_storage(registry, T)
	return component_storage_add(storage, entity, component)
}

// Get a component from an entity
component_registry_get :: proc(registry: ^Component_Registry, entity: Entity, $T: typeid) -> ^T {
	storage := component_registry_get_storage(registry, T)
	return component_storage_get(storage, entity)
}

// Remove a component from an entity
component_registry_remove :: proc(registry: ^Component_Registry, entity: Entity, $T: typeid) {
	if storage := component_registry_get_storage(registry, T); storage != nil {
		component_storage_remove(storage, entity)
	}
}

// Check if entity has component
component_registry_has :: proc(registry: ^Component_Registry, entity: Entity, $T: typeid) -> bool {
	if storage := component_registry_get_storage(registry, T); storage != nil {
		return component_storage_has(storage, entity)
	}
	return false
}

// Remove all components from an entity
component_registry_remove_all :: proc(registry: ^Component_Registry, entity: Entity) {
	for type_id, storage_ptr in registry.storages {
		// We need to manually check if the entity has this component type
		storage_type_info := type_info_of(type_id)
		if storage_type_info == nil do continue

		// Cast to the specific component storage type and check
		if type_id == typeid_of(Transform) {
			storage := cast(^Component_Storage(Transform))storage_ptr
			if component_storage_has(storage, entity) {
				component_storage_remove(storage, entity)
			}
		} else if type_id == typeid_of(Renderer) {
			storage := cast(^Component_Storage(Renderer))storage_ptr
			if component_storage_has(storage, entity) {
				component_storage_remove(storage, entity)
			}
		} else if type_id == typeid_of(Camera) {
			storage := cast(^Component_Storage(Camera))storage_ptr
			if component_storage_has(storage, entity) {
				component_storage_remove(storage, entity)
			}
		} else if type_id == typeid_of(Light) {
			storage := cast(^Component_Storage(Light))storage_ptr
			if component_storage_has(storage, entity) {
				component_storage_remove(storage, entity)
			}
		} else if type_id == typeid_of(Script) {
			storage := cast(^Component_Storage(Script))storage_ptr
			if component_storage_has(storage, entity) {
				component_storage_remove(storage, entity)
			}
		}
		// Add cases for other component types
	}
}

// Get all entities with a specific component
component_registry_view_single :: proc(
	registry: ^Component_Registry,
	$T: typeid,
	allocator := context.allocator,
) -> []Entity {
	storage := component_registry_get_storage(registry, T)
	return component_storage_entities(storage, allocator)
}

// Get all entities with two specific components (intersection)
component_registry_view_pair :: proc(
	registry: ^Component_Registry,
	$T1, $T2: typeid,
	allocator := context.allocator,
) -> []Entity {
	storage1 := component_registry_get_storage(registry, T1)
	storage2 := component_registry_get_storage(registry, T2)

	// Filter entities that have both components
	entities := make([dynamic]Entity, allocator)
	defer delete(entities)

	// Always use the first storage as the base and check against the second
	entities1 := component_storage_entities(storage1, allocator)
	defer delete(entities1)

	for entity in entities1 {
		if component_storage_has(storage2, entity) {
			append(&entities, entity)
		}
	}

	return slice.clone(entities[:], allocator)
}

// Get all entities with three specific components (intersection)
component_registry_view_triple :: proc(
	registry: ^Component_Registry,
	$T1, $T2, $T3: typeid,
	allocator := context.allocator,
) -> []Entity {
	// First get intersection of first two types
	pair_entities := component_registry_view_pair(registry, T1, T2, allocator)
	defer delete(pair_entities)

	storage3 := component_registry_get_storage(registry, T3)

	// Then filter by third type
	entities := make([dynamic]Entity, allocator)
	defer delete(entities)

	for entity in pair_entities {
		if component_storage_has(storage3, entity) {
			append(&entities, entity)
		}
	}

	return slice.clone(entities[:], allocator)
}
