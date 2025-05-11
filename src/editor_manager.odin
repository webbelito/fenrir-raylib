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
	scene_tree_open:     bool,
	inspector_open:      bool,
	viewport_open:       bool,
	scene_tree_width:    f32,
	inspector_width:     f32,
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

editor: Editor_State

// Initialize the editor
editor_init :: proc() -> bool {
	if editor.initialized {
		return true
	}

	// Initialize editor state
	editor = Editor_State {
		initialized      = true,
		scene_tree_open  = true,
		inspector_open   = true,
		viewport_open    = true,
		scene_tree_width = 200.0,
		inspector_width  = 200.0,
		menu_height      = 30.0,
		selected_entity  = 0,
	}

	// Initialize editor components
	if !editor_scene_tree_init() {
		return false
	}
	if !editor_inspector_init() {
		return false
	}
	if !editor_viewport_init() {
		return false
	}

	log_info(.ENGINE, "Editor initialized")
	return true
}

// Shutdown the editor
editor_shutdown :: proc() {
	if !editor.initialized {
		return
	}

	editor_scene_tree_shutdown()
	editor_inspector_shutdown()
	editor_viewport_shutdown()

	editor.initialized = false
	log_info(.ENGINE, "Editor shut down")
}

// Update the editor
editor_update :: proc() {
	if !editor.initialized {
		return
	}

	editor_scene_tree_update()
	editor_inspector_update()
	// editor_viewport_update() // This was removed as viewport texture rendering is handled by engine_render
}

// Render the editor
editor_render :: proc() {
	if !editor.initialized {
		return
	}

	// Render the main menu bar first
	editor_menu_render()

	// Render the editor layout (panels: scene tree, inspector)
	editor_layout_render()

	// Render the viewport ImGui window (acts as an overlay for the 3D scene)
	if editor.viewport_open {
		editor_viewport_render_ui()
	}

	// Render any active dialogs (should be last to appear on top)
	editor_manager_render_dialogs()
}

// Handle editor input
editor_manager_handle_input :: proc() {
	// Handle keyboard shortcuts
	if imgui.IsKeyDown(.LeftCtrl) || imgui.IsKeyDown(.RightCtrl) {
		// Save (Ctrl+S)
		if imgui.IsKeyPressed(.S) {
			if editor.scene_path == "" {
				// Clear the save dialog buffer
				for i in 0 ..< len(editor.save_dialog_name) {
					editor.save_dialog_name[i] = 0
				}
				// Copy the current scene name
				copy(editor.save_dialog_name[:], scene_manager.current_scene.name)
				editor.show_save_dialog = true
			} else {
				scene_manager_save(editor.scene_path)
			}
		}
		// Open (Ctrl+O)
		if imgui.IsKeyPressed(.O) {
			if !check_unsaved_changes("open") {
				scene_manager_scan_available_scenes()
				editor.show_open_dialog = true
			}
		}
		// New (Ctrl+N)
		if imgui.IsKeyPressed(.N) {
			if !check_unsaved_changes("new") {
				scene_manager_new("Untitled")
				editor.scene_path = ""
			}
		}
		// Undo (Ctrl+Z)
		if imgui.IsKeyPressed(.Z) {
			command_manager_undo()
		}
		// Redo (Ctrl+Y)
		if imgui.IsKeyPressed(.Y) {
			command_manager_redo()
		}
		// Duplicate (Ctrl+D)
		if imgui.IsKeyPressed(.D) && editor.selected_entity != 0 {
			cmd := command_create_node_duplicate(editor.selected_entity)
			command_manager_execute(&cmd)
		}
	}

	// Scene tree shortcuts
	if editor.selected_entity != 0 {
		// Delete selected entity (Delete)
		if imgui.IsKeyPressed(.Delete) {
			if editor.selected_entity != 0 { 	// Don't allow deleting root node
				cmd := command_create_node_delete(editor.selected_entity)
				command_manager_execute(&cmd)
			}
		}
		// Duplicate selected entity (Ctrl+D)
		if (imgui.IsKeyDown(.LeftCtrl) || imgui.IsKeyDown(.RightCtrl)) && imgui.IsKeyPressed(.D) {
			if new_node_id := scene_manager_duplicate_node(editor.selected_entity);
			   new_node_id != 0 {
				editor.selected_entity = new_node_id
			}
		}
		// Rename selected entity (F2)
		if imgui.IsKeyPressed(.F2) {
			editor.renaming_node = editor.selected_entity
			// Clear the buffer
			for i in 0 ..< len(editor.rename_buffer) {
				editor.rename_buffer[i] = 0
			}
			// Copy the current name
			if node, ok := scene_manager.current_scene.nodes[editor.selected_entity]; ok {
				copy(editor.rename_buffer[:], node.name)
			}
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
			for file in scene_manager.available_scenes {
				if imgui.Selectable(strings.clone_to_cstring(file), editor.selected_file == file) {
					editor.selected_file = file
				}
			}
			imgui.EndChild()
		}

		// Render buttons
		if imgui.Button("Open") {
			if len(editor.selected_file) > 0 {
				path := fmt.tprintf("%s/%s", editor.current_dir, editor.selected_file)
				if scene_manager_load(path) {
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
