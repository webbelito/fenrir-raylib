package main

import "core:fmt"
import "core:log"
import "core:strings"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:encoding/json"

// Scene structure
Scene :: struct {
    name: string,
    path: string,
    
    // List of entities in the scene
    entities: [dynamic]Entity,
    
    // Is the scene loaded or not
    loaded: bool,
    
    // Is this scene dirty (has unsaved changes)
    dirty: bool,
}

// Current scene being edited/played
current_scene: Scene

// List of available scenes
available_scenes: [dynamic]string

// Initialize the scene system
scene_init :: proc() {
    log_info(.ENGINE, "Initializing scene system")
    
    // Initialize the current scene
    current_scene.name = "Untitled"
    current_scene.path = ""
    current_scene.entities = make([dynamic]Entity)
    current_scene.loaded = false
    current_scene.dirty = false
    
    // Initialize the available scenes list
    available_scenes = make([dynamic]string)
    
    // Scan for available scenes
    scene_scan_available_scenes()
}

// Shutdown the scene system
scene_shutdown :: proc() {
    log_info(.ENGINE, "Shutting down scene system")
    
    // Unload the current scene if loaded
    if current_scene.loaded {
        scene_unload()
    }
    
    // Free resources
    delete(current_scene.entities)
    delete(available_scenes)
}

// Scan for available scenes in the assets/scenes directory
scene_scan_available_scenes :: proc() {
    scenes_dir := "assets/scenes"
    
    // Clear the available scenes list
    clear(&available_scenes)
    
    // Check if the directory exists
    if !os.exists(scenes_dir) {
        log_warning(.ENGINE, "Scenes directory '%s' does not exist", scenes_dir)
        return
    }
    
    // Open the directory
    dir, err := os.open(scenes_dir)
    if err != os.ERROR_NONE {
        log_error(.ENGINE, "Failed to open scenes directory: %v", err)
        return
    }
    defer os.close(dir)
    
    // Read directory entries
    entries, read_err := os.read_dir(dir, 0)
    if read_err != os.ERROR_NONE {
        log_error(.ENGINE, "Failed to read scenes directory: %v", read_err)
        return
    }
    defer os.file_info_slice_delete(entries)
    
    // Filter for .json files
    for entry in entries {
        if !entry.is_dir && strings.has_suffix(entry.name, ".json") {
            // Add to available scenes list
            scene_name := strings.clone(entry.name)
            append(&available_scenes, scene_name)
            log_debug(.ENGINE, "Found scene: %s", scene_name)
        }
    }
    
    log_info(.ENGINE, "Found %d scene(s)", len(available_scenes))
}

// Create a new scene
scene_new :: proc(name: string) -> bool {
    if current_scene.loaded && current_scene.dirty {
        log_warning(.ENGINE, "Current scene has unsaved changes")
        return false
    }
    
    // Unload current scene if loaded
    if current_scene.loaded {
        scene_unload()
    }
    
    // Initialize new scene
    current_scene.name = strings.clone(name)
    current_scene.path = ""
    current_scene.loaded = true
    current_scene.dirty = true
    
    // Create default entities
    root := ecs_create_entity()
    ecs_add_transform(root, {0, 0, 0}, {0, 0, 0}, {1, 1, 1})
    append(&current_scene.entities, root)
    
    // Create camera
    camera := ecs_create_entity()
    ecs_add_transform(camera, {0, 2, -5}, {0, 0, 0}, {1, 1, 1})
    ecs_add_camera(camera, 60.0, 0.1, 1000.0, true)
    append(&current_scene.entities, camera)
    
    log_info(.ENGINE, "Created new scene: %s", name)
    return true
}

// Load a scene from disk
scene_load :: proc(path: string) -> bool {
    if current_scene.loaded && current_scene.dirty {
        log_warning(.ENGINE, "Current scene has unsaved changes")
        return false
    }
    
    // Unload current scene if loaded
    if current_scene.loaded {
        scene_unload()
    }
    
    log_info(.ENGINE, "Loading scene from: %s", path)
    
    // Check if file exists
    if !os.exists(path) {
        log_error(.ENGINE, "Scene file does not exist: %s", path)
        return false
    }
    
    // TODO: Implement actual scene loading from JSON
    // For now, we'll just create a simple scene
    
    scene_name := filepath.base(path)
    scene_name = strings.trim_suffix(scene_name, ".json")
    
    current_scene.name = strings.clone(scene_name)
    current_scene.path = strings.clone(path)
    current_scene.loaded = true
    current_scene.dirty = false
    
    // Create default entities
    root := ecs_create_entity()
    ecs_add_transform(root, {0, 0, 0}, {0, 0, 0}, {1, 1, 1})
    append(&current_scene.entities, root)
    
    // Create camera
    camera := ecs_create_entity()
    ecs_add_transform(camera, {0, 1, -10}, {0, 0, 0}, {1, 1, 1})
    ecs_add_camera(camera, 45.0, 0.1, 1000.0, true)
    append(&current_scene.entities, camera)
    
    // Create light
    light := ecs_create_entity()
    ecs_add_transform(light, {5, 5, 5}, {-45, 45, 0}, {1, 1, 1})
    ecs_add_light(light, .DIRECTIONAL, {1, 1, 1}, 1.0, 0.0)
    append(&current_scene.entities, light)
    
    log_info(.ENGINE, "Scene loaded successfully: %s", scene_name)
    return true
}

// Save the current scene to disk
scene_save :: proc(path: string = "") -> bool {
    if !current_scene.loaded {
        log_error(.ENGINE, "No scene is currently loaded")
        return false
    }
    
    save_path := path
    if save_path == "" {
        // If no path provided, use the current scene path
        save_path = current_scene.path
        
        // If no path set, create one in assets/scenes
        if save_path == "" {
            save_path = fmt.tprintf("assets/scenes/%s.json", current_scene.name)
        }
    }
    
    log_info(.ENGINE, "Saving scene to: %s", save_path)
    
    // TODO: Implement actual scene saving to JSON
    // For now, we'll just create a dummy scene file
    
    // Check if scenes directory exists - we don't create it (it should be created by build script)
    scenes_dir := filepath.dir(save_path)
    if !os.exists(scenes_dir) {
        log_error(.ENGINE, "Scenes directory '%s' does not exist", scenes_dir)
        return false
    }
    
    // Create a dummy scene file
    scene_json := fmt.tprintf(`{
        "name": "%s",
        "entities": %d,
        "version": "0.1"
    }`, current_scene.name, len(current_scene.entities))
    
    // Write the file
    write_err := os.write_entire_file(save_path, transmute([]byte)scene_json)
    if write_err {
        log_error(.ENGINE, "Failed to save scene")
        return false
    }
    
    // Update scene info
    current_scene.path = strings.clone(save_path)
    current_scene.dirty = false
    
    // Update available scenes
    scene_scan_available_scenes()
    
    log_info(.ENGINE, "Scene saved successfully: %s", save_path)
    return true
}

// Unload the current scene
scene_unload :: proc() {
    if !current_scene.loaded {
        return
    }
    
    log_info(.ENGINE, "Unloading scene: %s", current_scene.name)
    
    // Destroy all entities
    for entity in current_scene.entities {
        ecs_destroy_entity(entity)
    }
    
    // Clear the entities list
    clear(&current_scene.entities)
    
    // Free scene name and path
    delete(current_scene.name)
    delete(current_scene.path)
    
    // Reset scene state
    current_scene.name = "Untitled"
    current_scene.path = ""
    current_scene.loaded = false
    current_scene.dirty = false
}

// Add an entity to the current scene
scene_add_entity :: proc(entity: Entity) {
    if !current_scene.loaded {
        log_warning(.ENGINE, "No scene is currently loaded")
        return
    }
    
    append(&current_scene.entities, entity)
    current_scene.dirty = true
}

// Remove an entity from the current scene
scene_remove_entity :: proc(entity: Entity) {
    if !current_scene.loaded {
        log_warning(.ENGINE, "No scene is currently loaded")
        return
    }
    
    // Find and remove the entity
    for i := 0; i < len(current_scene.entities); i += 1 {
        if current_scene.entities[i] == entity {
            unordered_remove(&current_scene.entities, i)
            current_scene.dirty = true
            return
        }
    }
    
    log_warning(.ENGINE, "Entity %d not found in scene", entity)
}

// Get all entities in the current scene
scene_get_entities :: proc(allocator := context.allocator) -> []Entity {
    if !current_scene.loaded {
        return {}
    }
    
    return slice.clone(current_scene.entities[:])
}

// Get the main camera entity (or nil if none exists)
scene_get_main_camera :: proc() -> Entity {
    if !current_scene.loaded {
        return 0
    }
    
    // Find entities with camera components
    camera_entities := ecs_get_entities_with_component(.CAMERA)
    defer delete(camera_entities)
    
    for entity in camera_entities {
        camera := ecs_get_camera(entity)
        if camera != nil && camera.is_main {
            return entity
        }
    }
    
    return 0 // No main camera found
}

// Check if a scene is currently loaded
scene_is_loaded :: proc() -> bool {
    return current_scene.loaded
}

// Mark the current scene as dirty (has unsaved changes)
scene_mark_dirty :: proc() {
    if current_scene.loaded {
        current_scene.dirty = true
    }
}

// Check if the current scene has unsaved changes
scene_is_dirty :: proc() -> bool {
    return current_scene.loaded && current_scene.dirty
} 