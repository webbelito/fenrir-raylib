package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import raylib "vendor:raylib"

// Editor state
Editor_State :: struct {
	initialized:         bool,
	selected_entity:     Entity,
	inspector_open:      bool,
	inspector_width:     f32,
	scene_tree_width:    f32,
	menu_height:         f32,
	scene_path:          string,
	show_save_dialog:    bool,
	save_dialog_name:    [256]u8, // Buffer for scene name input
	show_open_dialog:    bool, // Flag to show open scene dialog
	available_scenes:    [dynamic]string, // List of available scene files
	current_dir:         string, // Current directory for file browser
	file_list:           [dynamic]string, // List of files in current directory
	selected_file:       string, // Currently selected file
	renaming_node:       Entity,
	rename_buffer:       [256]u8, // Fixed-size buffer for renaming
	show_unsaved_dialog: bool,
	pending_action:      string,
}

// Global editor state
editor: Editor_State

// Initialize the editor state (called once)
editor_init_state :: proc() {
	editor = Editor_State {
		initialized         = false,
		selected_entity     = 0,
		inspector_open      = true,
		inspector_width     = 300.0,
		scene_tree_width    = 300.0,
		menu_height         = 30.0,
		scene_path          = "",
		show_save_dialog    = false,
		show_open_dialog    = false,
		show_unsaved_dialog = false,
		pending_action      = "",
	}
}

// Initialize the editor
editor_init :: proc() -> bool {
	if editor.initialized {
		return true
	}

	// Initialize editor state
	editor_init_state()

	// Set initialized flag
	editor.initialized = true

	log_info(.ENGINE, "Editor initialized")
	return true
}

// Shutdown the editor
editor_shutdown :: proc() {
	if !editor.initialized {
		return
	}

	editor.initialized = false
	log_info(.ENGINE, "Editor shut down")
}

// Update the editor
editor_update :: proc() {
	if !editor.initialized || engine.playing {
		return
	}

	// Update editor systems
	editor_inspector_update()
}

// Draw the 3D scene in the background
draw_3d_scene :: proc(x, y, width, height: i32) {
	// Set up the viewport
	raylib.BeginMode3D(engine.editor_camera)
	defer raylib.EndMode3D()

	// Draw a grid
	raylib.DrawGrid(10, 1.0)

	// Draw all entities with renderers
	for entity in scene_manager.current_scene.entities {
		if renderer := ecs_get_component(entity, Renderer); renderer != nil {
			if transform := ecs_get_component(entity, Transform); transform != nil {
				// Draw based on model type
				switch renderer.model_type {
				case .CUBE:
					raylib.DrawCube(transform.position, 1.0, 1.0, 1.0, raylib.WHITE)
				case .SPHERE:
					raylib.DrawSphere(transform.position, 0.5, raylib.WHITE)
				case .PLANE:
					raylib.DrawPlane(transform.position, {1.0, 1.0}, raylib.WHITE)
				case .AMBULANCE, .CUSTOM:
					if model, ok := asset_manager.models[renderer.mesh_path]; ok {
						raylib.DrawModel(model.model, transform.position, 1.0, raylib.WHITE)
					}
				}
			}
		}
	}
}

// Render the editor
editor_render :: proc() {
	if !editor.initialized || engine.playing {
		return
	}

	// Draw the 3D scene in full screen first
	draw_3d_scene(0, 0, raylib.GetScreenWidth(), raylib.GetScreenHeight())

	// Create the menu bar
	if imgui.BeginMainMenuBar() {
		if imgui.BeginMenu("File") {
			if imgui.MenuItem("New Scene") {
				if !check_unsaved_changes("new") {
					scene_manager_new("Untitled")
				}
			}
			if imgui.MenuItem("Open Scene") {
				if !check_unsaved_changes("open") {
					editor.show_open_dialog = true
				}
			}
			if imgui.MenuItem("Save Scene") {
				if scene_manager_is_dirty() {
					editor.show_save_dialog = true
				}
			}
			imgui.Separator()
			if imgui.MenuItem("Exit") {
				if !check_unsaved_changes("exit") {
					engine.running = false
				}
			}
			imgui.EndMenu()
		}
		if imgui.BeginMenu("Edit") {
			if imgui.MenuItem("Undo") {
				command_manager_undo()
			}
			if imgui.MenuItem("Redo") {
				command_manager_redo()
			}
			imgui.EndMenu()
		}
		if imgui.BeginMenu("View") {
			if imgui.MenuItem("Toggle Inspector") {
				editor.inspector_open = !editor.inspector_open
			}
			imgui.EndMenu()
		}
		imgui.EndMainMenuBar()
	}

	// Create a window for the world panel (left panel)
	imgui.SetNextWindowPos(imgui.Vec2{0, imgui.GetFrameHeight()})
	imgui.SetNextWindowSize(
		imgui.Vec2 {
			editor.scene_tree_width,
			f32(raylib.GetScreenHeight()) - imgui.GetFrameHeight(),
		},
	)

	window_flags := imgui.WindowFlags {
		.NoCollapse,
		.NoResize,
		.NoMove,
		.NoBringToFrontOnFocus,
		.NoNavFocus,
	}

	if imgui.Begin("World", nil, window_flags) {
		// Add Create Entity button at the top of the World panel
		if imgui.Button("Create Entity") {
			// Create a new entity with a default name
			entity := scene_manager_create_entity("New Entity")
			// Select the newly created entity
			editor.selected_entity = entity
			// Mark the scene as dirty
			scene_manager.current_scene.dirty = true
		}

		imgui.Separator()

		// Render world entities
		for entity in scene_manager.current_scene.entities {
			if transform := ecs_get_component(entity, Transform); transform != nil {
				// Create a selectable tree node for each entity
				entity_name := ecs_get_entity_name(entity)
				if imgui.Selectable(
					strings.clone_to_cstring(entity_name),
					editor.selected_entity == entity,
				) {
					editor.selected_entity = entity
				}
			}
		}
	}
	imgui.End()

	// Create a window for the inspector (right panel)
	imgui.SetNextWindowPos(
		imgui.Vec2{f32(raylib.GetScreenWidth()) - editor.inspector_width, imgui.GetFrameHeight()},
	)
	imgui.SetNextWindowSize(
		imgui.Vec2{editor.inspector_width, f32(raylib.GetScreenHeight()) - imgui.GetFrameHeight()},
	)

	if imgui.Begin("Inspector", nil, window_flags) {
		editor_inspector_render()
	}
	imgui.End()

	// Render dialogs
	render_save_dialog()
	render_open_dialog()
	render_unsaved_dialog()
}

// Handle editor input
editor_manager_handle_input :: proc() {
	// Handle keyboard shortcuts
	if imgui.IsKeyDown(.LeftCtrl) || imgui.IsKeyDown(.RightCtrl) {
		// Save (Ctrl+S)
		if imgui.IsKeyPressed(.S) {
			if scene_manager.current_scene.dirty {
				editor.show_save_dialog = true
			}
		}
		// Open (Ctrl+O)
		if imgui.IsKeyPressed(.O) {
			editor.show_open_dialog = true
		}
	}
}

// Render editor dialogs
editor_manager_render_dialogs :: proc() {
	render_save_dialog()
	render_unsaved_dialog()
	render_open_dialog()
}

// Scan directory for files
scan_directory :: proc(dir_path: string) {
	clear(&editor.file_list)

	// Ensure the directory exists
	if !os.exists(dir_path) {
		log_info(.ENGINE, "Directory does not exist, creating: %s", dir_path)
		os.make_directory(dir_path)
		return
	}

	// Read directory contents
	if dir, err := os.open(dir_path); err == os.ERROR_NONE {
		defer os.close(dir)

		// Read all entries at once
		entries, read_err := os.read_dir(dir, 0)
		if read_err == os.ERROR_NONE {
			defer os.file_info_slice_delete(entries)

			// Add all files, ensuring they have .json extension
			for entry in entries {
				if !entry.is_dir {
					name := entry.name
					if !strings.has_suffix(name, ".json") {
						name = fmt.tprintf("%s.json", name)
					}
					append(&editor.file_list, strings.clone(name))
				}
			}
			log_info(.ENGINE, "Found %d scene files", len(editor.file_list))
		} else {
			log_error(.ENGINE, "Failed to read directory: %s", dir_path)
		}
	} else {
		log_error(.ENGINE, "Failed to open directory: %s", dir_path)
	}
}

// Render save dialog
render_save_dialog :: proc() {
	if !editor.show_save_dialog {
		return
	}

	// Center the window
	viewport := imgui.GetMainViewport()
	center := viewport.WorkPos + viewport.WorkSize * 0.5
	size := imgui.Vec2{400, 150}
	pos := center - size * 0.5

	imgui.SetNextWindowPos(pos, .None)
	imgui.SetNextWindowSize(size, .None)

	if imgui.Begin("Save Scene", &editor.show_save_dialog, {.NoCollapse}) {
		imgui.Text("Enter scene name:")
		if imgui.InputText(
			"###save_input",
			cstring(raw_data(editor.save_dialog_name[:])),
			len(editor.save_dialog_name),
			imgui.InputTextFlags{.EnterReturnsTrue},
		) {
			// Save the scene - just pass the name to scene manager
			name := string(editor.save_dialog_name[:])
			// Find the null terminator
			for i in 0 ..< len(name) {
				if name[i] == 0 {
					name = name[:i]
					break
				}
			}
			// Trim any trailing whitespace
			name = strings.trim_space(name)
			if scene_manager_save(name) {
				editor.scene_path = scene_manager.current_scene.path
				editor.show_save_dialog = false
			}
		}

		if imgui.Button("Save") {
			name := string(editor.save_dialog_name[:])
			// Find the null terminator
			for i in 0 ..< len(name) {
				if name[i] == 0 {
					name = name[:i]
					break
				}
			}
			// Trim any trailing whitespace
			name = strings.trim_space(name)
			if scene_manager_save(name) {
				editor.scene_path = scene_manager.current_scene.path
				editor.show_save_dialog = false
			}
		}
		imgui.SameLine()
		if imgui.Button("Cancel") {
			editor.show_save_dialog = false
		}
		imgui.End()
	}
}

// Render unsaved changes dialog
render_unsaved_dialog :: proc() {
	if !editor.show_unsaved_dialog {
		return
	}

	// Center the window
	viewport := imgui.GetMainViewport()
	center := viewport.WorkPos + viewport.WorkSize * 0.5
	size := imgui.Vec2{400, 150}
	pos := center - size * 0.5

	imgui.SetNextWindowPos(pos, .None)
	imgui.SetNextWindowSize(size, .None)

	if imgui.Begin("Unsaved Changes", &editor.show_unsaved_dialog, {.NoCollapse}) {
		imgui.Text("You have unsaved changes. Do you want to save before continuing?")

		if imgui.Button("Save") {
			if len(editor.scene_path) > 0 {
				scene_manager_save(editor.scene_path)
			} else {
				editor.show_save_dialog = true
			}
			editor.show_unsaved_dialog = false

			// Execute pending action
			execute_pending_action()
		}
		imgui.SameLine()
		if imgui.Button("Don't Save") {
			editor.show_unsaved_dialog = false
			// Execute pending action without saving
			execute_pending_action()
		}
		imgui.SameLine()
		if imgui.Button("Cancel") {
			editor.show_unsaved_dialog = false
			editor.pending_action = ""
		}
		imgui.End()
	}
}

// Execute the pending action based on the action type
execute_pending_action :: proc() {
	switch editor.pending_action {
	case "new":
		scene_manager_new("Untitled")
		editor.scene_path = ""
	case "open":
		scan_directory(editor.current_dir)
		editor.show_open_dialog = true
	case "exit":
	// TODO: Handle exit
	}
	editor.pending_action = ""
}

// Render open dialog
render_open_dialog :: proc() {
	if !editor.show_open_dialog {
		return
	}

	// Center the window
	viewport := imgui.GetMainViewport()
	center := viewport.WorkPos + viewport.WorkSize * 0.5
	size := imgui.Vec2{400, 300}
	pos := center - size * 0.5

	imgui.SetNextWindowPos(pos, .None)
	imgui.SetNextWindowSize(size, .None)

	if imgui.Begin("Open Scene", &editor.show_open_dialog, {.NoCollapse}) {
		// Show current directory
		imgui.Text("Current Directory: %s", editor.current_dir)
		imgui.Separator()

		// Render file list
		if imgui.BeginChild("FileList", {-1, -40}, {.Borders}) {
			scene_files := scene_manager_scan_available_scenes()
			defer delete(scene_files)

			for file in scene_files {
				if imgui.Selectable(strings.clone_to_cstring(file), editor.selected_file == file) {
					editor.selected_file = file
				}
			}
			imgui.EndChild()
		}

		// Render buttons
		if imgui.Button("Open") {
			if len(editor.selected_file) > 0 {
				// Just pass the filename to scene_manager_load, which will handle the path
				if scene_manager_load(editor.selected_file) {
					editor.scene_path = scene_manager.current_scene.path
					editor.show_open_dialog = false
				}
			}
		}
		imgui.SameLine()
		if imgui.Button("Cancel") {
			editor.show_open_dialog = false
		}
		imgui.End()
	}
}

// Check for unsaved changes and show dialog if needed
check_unsaved_changes :: proc(action: string) -> bool {
	if scene_manager_is_dirty() {
		editor.show_unsaved_dialog = true
		editor.pending_action = action
		return true
	}
	return false
}
