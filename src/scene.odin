package main

import "core:fmt"
import "core:log"
import "core:math"
import raylib "vendor:raylib"

// Initialize the scene system
scene_init :: proc() {
	scene_manager_init()
}

// Shutdown the scene system
scene_shutdown :: proc() {
	scene_manager_shutdown()
}

// Create a new scene
scene_new :: proc(name: string) -> bool {
	return scene_manager_new(name)
}

// Create a new node in the scene
scene_create_node :: proc(name: string, parent_id: Entity = 0) -> Entity {
	return scene_manager_create_node(name, parent_id)
}

// Delete a node and all its children
scene_delete_node :: proc(node_id: Entity) {
	scene_manager_delete_node(node_id)
}

// Load a scene from disk
scene_load :: proc(path: string) -> bool {
	return scene_manager_load(path)
}

// Save the current scene to disk
scene_save :: proc(path: string = "") -> bool {
	return scene_manager_save(path)
}

// Unload the current scene
scene_unload :: proc() {
	scene_manager_unload()
}

// Add an entity to the current scene
scene_add_entity :: proc(entity: Entity) {
	scene_manager_add_entity(entity)
}

// Remove an entity from the current scene
scene_remove_entity :: proc(entity: Entity) {
	scene_manager_remove_entity(entity)
}

// Get all entities in the current scene
scene_get_entities :: proc(allocator := context.allocator) -> []Entity {
	return scene_manager_get_entities(allocator)
}

// Get the main camera entity (or nil if none exists)
scene_get_main_camera :: proc() -> Entity {
	return scene_manager_get_main_camera()
}

// Check if a scene is currently loaded
scene_is_loaded :: proc() -> bool {
	return scene_manager_is_loaded()
}

// Mark the current scene as dirty (has unsaved changes)
scene_mark_dirty :: proc() {
	scene_manager_mark_dirty()
}

// Check if the current scene has unsaved changes
scene_is_dirty :: proc() -> bool {
	return scene_manager_is_dirty()
}

// Create an ambulance entity with the provided mesh and texture
scene_create_ambulance_entity :: proc() -> Entity {
	return scene_manager_create_ambulance_entity()
}

// Get the camera for rendering
scene_get_camera :: proc() -> raylib.Camera3D {
	return scene_manager_get_camera()
}

// Update the scene
scene_update :: proc() {
	scene_manager_update()
}

// Render the scene
scene_render :: proc() {
	scene_manager_render()
}
