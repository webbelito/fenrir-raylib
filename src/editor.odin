#+feature dynamic-literals
package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strconv"
import "core:strings"
import raylib "vendor:raylib"

// Editor state
Editor_State :: struct {
	initialized:     bool,
	selected_entity: Entity,
	scene_tree_open: bool,
	inspector_open:  bool,
	scene_path:      string,
}

editor: Editor_State

// Initialize the editor
editor_init :: proc() -> bool {
	if editor.initialized {
		return true
	}

	editor = Editor_State {
		initialized     = true,
		scene_tree_open = true,
		inspector_open  = true,
		scene_path      = "",
	}

	log_info(.ENGINE, "Editor initialized")
	return true
}

// Update the editor (only in debug mode)
editor_update :: proc() {
	when ODIN_DEBUG {
		if !editor.initialized {
			return
		}
	}
}

// Render the scene tree panel
render_scene_tree :: proc() {
	// Get all entities with transforms
	for entity, transform in entity_manager.transforms {
		// Create selectable item
		name := fmt.tprintf("Entity %d", entity)
		if imgui.Selectable(strings.clone_to_cstring(name), entity == editor.selected_entity) {
			editor.selected_entity = entity
		}
	}
}

// Render the inspector panel
render_inspector :: proc() {
	if editor.selected_entity != 0 {
		// Display entity ID
		imgui.Text("Entity ID: %d", editor.selected_entity)

		// Display transform component if it exists
		if transform := ecs_get_transform(editor.selected_entity); transform != nil {
			transform_render_inspector(transform)
		}

		// Display renderer component if it exists
		if renderer := ecs_get_renderer(editor.selected_entity); renderer != nil {
			renderer_render_inspector(renderer)
		}

		// Display camera component if it exists
		if camera := ecs_get_camera(editor.selected_entity); camera != nil {
			camera_render_inspector(camera)
		}

		// Display light component if it exists
		if light := ecs_get_light(editor.selected_entity); light != nil {
			light_render_inspector(light)
		}

		// Display script component if it exists
		if script := ecs_get_script(editor.selected_entity); script != nil {
			script_render_inspector(script)
		}
	}
}

// Render the editor UI
editor_render :: proc() {
	if !editor.initialized {
		return
	}

	// Main menu bar
	if imgui.BeginMainMenuBar() {
		// File menu
		if imgui.BeginMenu("File") {
			if imgui.MenuItem("New Scene", "Ctrl+N") {
				// Create new scene
				scene_new("New Scene")
				editor.scene_path = ""
			}
			if imgui.MenuItem("Open Scene", "Ctrl+O") {
				// TODO: Open file dialog
				path := "assets/scenes/test.json"
				log_info(.ENGINE, "Attempting to open scene: %s", path)
				if scene_load(path) {
					editor.scene_path = path
					log_info(.ENGINE, "Successfully opened scene: %s", path)
				} else {
					log_error(.ENGINE, "Failed to open scene: %s", path)
				}
			}
			if imgui.MenuItem("Save Scene", "Ctrl+S") {
				if editor.scene_path == "" {
					// TODO: Save file dialog
					editor.scene_path = "assets/scenes/test.json"
				}
				scene_save(editor.scene_path)
			}
			if imgui.MenuItem("Save Scene As...", "Ctrl+Shift+S") {
				// TODO: Save file dialog
				path := "assets/scenes/test.json"
				if scene_save(path) {
					editor.scene_path = path
				}
			}
			imgui.Separator()
			if imgui.MenuItem("Exit", "Alt+F4") {
				// TODO: Handle exit
			}
			imgui.EndMenu()
		}

		// Edit menu
		if imgui.BeginMenu("Edit") {
			if imgui.MenuItem("Undo", "Ctrl+Z") {
				// TODO: Implement undo
			}
			if imgui.MenuItem("Redo", "Ctrl+Y") {
				// TODO: Implement redo
			}
			imgui.EndMenu()
		}

		// Entity menu
		if imgui.BeginMenu("Entity") {
			if imgui.MenuItem("Add Empty", "Ctrl+Shift+N") {
				entity := create_entity(0, 0, 0)
				append(&current_scene.entities, entity)
				editor.selected_entity = entity
			}
			if imgui.BeginMenu("3D Object") {
				if imgui.MenuItem("Cube") {
					entity := create_entity(0, 0, 0)
					transform := ecs_add_transform(entity)
					renderer := ecs_add_renderer(entity)
					if renderer != nil {
						renderer.mesh = "cube"
						renderer.material = "default"
					}
					append(&current_scene.entities, entity)
					editor.selected_entity = entity
				}
				if imgui.MenuItem("Sphere") {
					entity := create_entity(0, 0, 0)
					transform := ecs_add_transform(entity)
					renderer := ecs_add_renderer(entity)
					if renderer != nil {
						renderer.mesh = "sphere"
						renderer.material = "default"
					}
					append(&current_scene.entities, entity)
					editor.selected_entity = entity
				}
				imgui.EndMenu()
			}
			if imgui.BeginMenu("Light") {
				if imgui.MenuItem("Directional Light") {
					entity := create_entity(0, 0, 0)
					transform := ecs_add_transform(entity)
					light := ecs_add_light(entity, .DIRECTIONAL)
					append(&current_scene.entities, entity)
					editor.selected_entity = entity
				}
				if imgui.MenuItem("Point Light") {
					entity := create_entity(0, 0, 0)
					transform := ecs_add_transform(entity)
					light := ecs_add_light(entity, .POINT)
					append(&current_scene.entities, entity)
					editor.selected_entity = entity
				}
				if imgui.MenuItem("Spot Light") {
					entity := create_entity(0, 0, 0)
					transform := ecs_add_transform(entity)
					light := ecs_add_light(entity, .SPOT)
					append(&current_scene.entities, entity)
					editor.selected_entity = entity
				}
				imgui.EndMenu()
			}
			if imgui.MenuItem("Camera") {
				entity := create_entity(0, 0, 0)
				transform := ecs_add_transform(entity)
				camera := ecs_add_camera(entity)
				append(&current_scene.entities, entity)
				editor.selected_entity = entity
			}
			imgui.Separator()
			if imgui.MenuItem("Delete Selected", "Delete") {
				if editor.selected_entity != 0 {
					// TODO: Implement entity deletion
				}
			}
			imgui.EndMenu()
		}

		// Window menu
		if imgui.BeginMenu("Window") {
			if imgui.MenuItem("Scene Tree", nil, editor.scene_tree_open) {
				editor.scene_tree_open = !editor.scene_tree_open
			}
			if imgui.MenuItem("Inspector", nil, editor.inspector_open) {
				editor.inspector_open = !editor.inspector_open
			}
			imgui.EndMenu()
		}
		imgui.EndMainMenuBar()
	}

	// Get the main window size
	window_size := imgui.GetIO().DisplaySize
	panel_width := window_size.x * 0.2 // 20% of screen width
	menu_bar_height := imgui.GetFrameHeight() // Get the height of the menu bar

	// Render scene tree panel (fixed on left)
	if editor.scene_tree_open {
		imgui.SetNextWindowPos({0, menu_bar_height})
		imgui.SetNextWindowSize({panel_width, window_size.y - menu_bar_height})
		window_flags := imgui.WindowFlags{.NoCollapse, .NoResize, .NoMove}
		if imgui.Begin("Scene Tree", &editor.scene_tree_open, window_flags) {
			render_scene_tree()
		}
		imgui.End()
	}

	// Render inspector panel (fixed on right)
	if editor.inspector_open {
		imgui.SetNextWindowPos({window_size.x - panel_width, menu_bar_height})
		imgui.SetNextWindowSize({panel_width, window_size.y - menu_bar_height})
		window_flags := imgui.WindowFlags{.NoCollapse, .NoResize, .NoMove}
		if imgui.Begin("Inspector", &editor.inspector_open, window_flags) {
			render_inspector()
		}
		imgui.End()
	}
}

// Shutdown the editor (only in debug mode)
editor_shutdown :: proc() {
	when ODIN_DEBUG {
		if !editor.initialized {
			return
		}

		log_info(.ENGINE, "Shutting down editor")

		editor.initialized = false
	}
}

// Toggle editor visibility
editor_toggle :: proc() {
	if !editor.initialized {
		return
	}

	editor.scene_tree_open = !editor.scene_tree_open
	editor.inspector_open = !editor.inspector_open
}

// Check if editor is active
editor_is_active :: proc() -> bool {
	when ODIN_DEBUG {
		return editor.initialized
	} else {
		return false
	}
}
