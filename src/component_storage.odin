package main

import "core:fmt"
import "core:mem"
import "core:slice"

// Component storage using sparse set for efficient iteration and lookup
Component_Storage :: struct($T: typeid) {
	dense:           [dynamic]T, // Components stored densely
	entity_to_index: map[Entity]int, // Entity ID to dense array index
	index_to_entity: [dynamic]Entity, // Reverse mapping for fast iteration
}

// Initialize a component storage
component_storage_init :: proc($T: typeid) -> ^Component_Storage(T) {
	storage := new(Component_Storage(T))
	storage.dense = make([dynamic]T)
	storage.entity_to_index = make(map[Entity]int)
	storage.index_to_entity = make([dynamic]Entity)
	return storage
}

// Destroy a component storage
component_storage_destroy :: proc(storage: ^Component_Storage($T)) {
	delete(storage.dense)
	delete(storage.entity_to_index)
	delete(storage.index_to_entity)
	free(storage)
}

// Add a component to storage
component_storage_add :: proc(
	storage: ^Component_Storage($T),
	entity: Entity,
	component: T,
) -> ^T {
	if entity in storage.entity_to_index {
		// Entity already has this component, replace it
		idx := storage.entity_to_index[entity]
		storage.dense[idx] = component
		return &storage.dense[idx]
	}

	// Add component to the dense array
	append(&storage.dense, component)
	index := len(storage.dense) - 1

	// Map entity to component and vice versa
	storage.entity_to_index[entity] = index
	append(&storage.index_to_entity, entity)

	return &storage.dense[index]
}

// Get a component from storage
component_storage_get :: proc(storage: ^Component_Storage($T), entity: Entity) -> ^T {
	if idx, ok := storage.entity_to_index[entity]; ok {
		return &storage.dense[idx]
	}
	return nil
}

// Remove a component from storage
component_storage_remove :: proc(storage: ^Component_Storage($T), entity: Entity) {
	if idx, ok := storage.entity_to_index[entity]; ok {
		// Get the last component and entity
		last_idx := len(storage.dense) - 1
		last_entity := storage.index_to_entity[last_idx]

		if idx != last_idx {
			// Move the last component to the removed position
			storage.dense[idx] = storage.dense[last_idx]
			storage.index_to_entity[idx] = last_entity
			storage.entity_to_index[last_entity] = idx
		}

		// Remove the last component
		pop(&storage.dense)
		pop(&storage.index_to_entity)
		delete_key(&storage.entity_to_index, entity)
	}
}

// Check if entity has this component
component_storage_has :: proc(storage: ^Component_Storage($T), entity: Entity) -> bool {
	return entity in storage.entity_to_index
}

// Get all entities with this component
component_storage_entities :: proc(
	storage: ^Component_Storage($T),
	allocator := context.allocator,
) -> []Entity {
	return slice.clone(storage.index_to_entity[:], allocator)
}

// Get component data array for direct iteration
component_storage_data :: proc(storage: ^Component_Storage($T)) -> []T {
	return storage.dense[:]
}

// Get count of components
component_storage_count :: proc(storage: ^Component_Storage($T)) -> int {
	return len(storage.dense)
}

// Clear all components
component_storage_clear :: proc(storage: ^Component_Storage($T)) {
	clear(&storage.dense)
	clear(&storage.entity_to_index)
	clear(&storage.index_to_entity)
}
