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
	initialized:         bool,
	selected_entity:     Entity,
	scene_tree_open:     bool,
	inspector_open:      bool,
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

	// Initialize all buffers with zeros
	for i in 0 ..< len(editor.save_dialog_name) {
		editor.save_dialog_name[i] = 0
	}

	editor = Editor_State {
		initialized         = true,
		scene_tree_open     = true,
		inspector_open      = true,
		scene_path          = "",
		show_save_dialog    = false,
		show_open_dialog    = false,
		available_scenes    = make([dynamic]string),
		current_dir         = "assets/scenes",
		file_list           = make([dynamic]string),
		selected_file       = "",
		renaming_node       = 0,
		show_unsaved_dialog = false,
		pending_action      = "",
	}

	log_info(.ENGINE, "Editor initialized")
	return true
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

			// Filter for .json files
			for entry in entries {
				if !entry.is_dir && filepath.ext(entry.name) == ".json" {
					name := strings.clone(entry.name)
					append_elem(&editor.file_list, name)
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

// Update the editor (only in debug mode)
editor_update :: proc() {
	when ODIN_DEBUG {
		if !editor.initialized {
			return
		}
	}

	// Handle editor input
	editor_handle_input()

	// Render dialogs
	render_save_dialog()
	render_unsaved_dialog()

	// Render open dialog
	if editor.show_open_dialog {
		// Center the window
		viewport := imgui.GetMainViewport()
		center := viewport.WorkPos + viewport.WorkSize * 0.5
		size := imgui.Vec2{400, 300}
		pos := center - size * 0.5

		imgui.SetNextWindowPos(pos, .None)
		imgui.SetNextWindowSize(size, .None)

		if imgui.Begin("Open Scene", &editor.show_open_dialog, {.NoCollapse}) {
			// Render file list
			for file in editor.file_list {
				if imgui.Selectable(strings.clone_to_cstring(file), editor.selected_file == file) {
					editor.selected_file = file
				}
			}

			// Render buttons
			if imgui.Button("Open") {
				if len(editor.selected_file) > 0 {
					// Ensure we have a proper path with the filename
					path := fmt.tprintf("%s/%s", editor.current_dir, editor.selected_file)
					if !strings.has_suffix(path, ".json") {
						path = fmt.tprintf("%s.json", path)
					}
					log_info(.ENGINE, "Attempting to open scene: %s", path)
					if scene_manager_load(path) {
						editor.scene_path = path
						editor.show_open_dialog = false
						log_info(.ENGINE, "Successfully opened scene: %s", path)
					} else {
						log_error(.ENGINE, "Failed to open scene: %s", path)
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
}

// Render a node in the scene tree
render_node :: proc(node_id: Entity) {
	if node, ok := scene_manager.current_scene.nodes[node_id]; ok {
		// Create a unique label for the node
		label := fmt.caprintf("%s###node_%d", node.name, node_id)
		defer delete(label)

		// Create a tree node
		flags := imgui.TreeNodeFlags{.OpenOnArrow}
		if editor.selected_entity == node_id {
			flags |= {.Selected}
		}
		if node.expanded {
			flags |= {.DefaultOpen}
		}

		// If node has children, make it expandable
		if len(node.children) > 0 {
			if imgui.TreeNodeEx(label, flags) {
				// Handle node selection
				if imgui.IsItemClicked() {
					editor.selected_entity = node_id
				}

				// Handle double-click for renaming
				if imgui.IsItemHovered() && imgui.IsMouseDoubleClicked(.Left) {
					editor.renaming_node = node_id
					// Clear the buffer
					for i in 0 ..< len(editor.rename_buffer) {
						editor.rename_buffer[i] = 0
					}
					// Copy the current name
					copy(editor.rename_buffer[:], node.name)
				}

				// Render context menu
				if imgui.BeginPopupContextItem() {
					if imgui.MenuItem("Rename") {
						editor.renaming_node = node_id
						// Clear the buffer
						for i in 0 ..< len(editor.rename_buffer) {
							editor.rename_buffer[i] = 0
						}
						// Copy the current name
						copy(editor.rename_buffer[:], node.name)
					}
					if imgui.MenuItem("Add Child") {
						cmd := command_create_node_add("New Node", node_id)
						command_manager_execute(&cmd)
						if add_data := cast(^Command_Node_Add)cmd.data; add_data != nil {
							editor.selected_entity = add_data.entity_id
						}
						// Update the node's expanded state
						if node, ok := scene_manager.current_scene.nodes[node_id]; ok {
							node.expanded = true
							scene_manager.current_scene.nodes[node_id] = node
						}
					}
					if node_id != 0 && imgui.MenuItem("Delete Node") {
						cmd := command_create_node_delete(node_id)
						command_manager_execute(&cmd)
						if editor.selected_entity == node_id {
							editor.selected_entity = 0
						}
					}
					imgui.EndPopup()
				}

				// Render rename input if this node is being renamed
				if editor.renaming_node == node_id {
					imgui.SetKeyboardFocusHere()
					if imgui.InputText(
						"###rename_input",
						cstring(raw_data(editor.rename_buffer[:])),
						len(editor.rename_buffer),
						imgui.InputTextFlags{.EnterReturnsTrue},
					) {
						// Update node name using command
						new_name := string(editor.rename_buffer[:])
						cmd := command_create_node_rename(node_id, new_name)
						command_manager_execute(&cmd)
						editor.renaming_node = 0
					}
					// Cancel renaming on escape
					if imgui.IsKeyPressed(.Escape) {
						editor.renaming_node = 0
					}
				}

				// Render children recursively
				for child_id in node.children {
					render_node(child_id)
				}
				imgui.TreePop()
			}
		} else {
			// Leaf node - just a selectable item
			if imgui.Selectable(label, editor.selected_entity == node_id) {
				editor.selected_entity = node_id
			}

			// Handle double-click for renaming
			if imgui.IsItemHovered() && imgui.IsMouseDoubleClicked(.Left) {
				editor.renaming_node = node_id
				// Clear the buffer
				for i in 0 ..< len(editor.rename_buffer) {
					editor.rename_buffer[i] = 0
				}
				// Copy the current name
				copy(editor.rename_buffer[:], node.name)
			}

			// Render context menu for leaf nodes too
			if imgui.BeginPopupContextItem() {
				if imgui.MenuItem("Rename") {
					editor.renaming_node = node_id
					// Clear the buffer
					for i in 0 ..< len(editor.rename_buffer) {
						editor.rename_buffer[i] = 0
					}
					// Copy the current name
					copy(editor.rename_buffer[:], node.name)
				}
				if imgui.MenuItem("Add Child") {
					cmd := command_create_node_add("New Node", node_id)
					command_manager_execute(&cmd)
					if add_data := cast(^Command_Node_Add)cmd.data; add_data != nil {
						editor.selected_entity = add_data.entity_id
					}
					// Update the node's expanded state
					if node, ok := scene_manager.current_scene.nodes[node_id]; ok {
						node.expanded = true
						scene_manager.current_scene.nodes[node_id] = node
					}
				}
				if node_id != 0 && imgui.MenuItem("Delete Node") {
					cmd := command_create_node_delete(node_id)
					command_manager_execute(&cmd)
					if editor.selected_entity == node_id {
						editor.selected_entity = 0
					}
				}
				imgui.EndPopup()
			}

			// Render rename input if this node is being renamed
			if editor.renaming_node == node_id {
				imgui.SetKeyboardFocusHere()
				if imgui.InputText(
					"###rename_input",
					cstring(raw_data(editor.rename_buffer[:])),
					len(editor.rename_buffer),
					imgui.InputTextFlags{.EnterReturnsTrue},
				) {
					// Update node name using command
					new_name := string(editor.rename_buffer[:])
					cmd := command_create_node_rename(node_id, new_name)
					command_manager_execute(&cmd)
					editor.renaming_node = 0
				}
				// Cancel renaming on escape
				if imgui.IsKeyPressed(.Escape) {
					editor.renaming_node = 0
				}
			}
		}
	}
}

// Render the scene tree
render_scene_tree :: proc() {
	if !imgui.Begin("Scene Tree") {
		imgui.End()
		return
	}

	if !scene_manager_is_loaded() {
		imgui.Text("No scene loaded")
		imgui.End()
		return
	}

	// Add Node button
	if imgui.Button("Add Node") {
		parent_id := editor.selected_entity
		if parent_id == 0 {
			// If no node is selected, create under root
			parent_id = 0
		}
		cmd := command_create_node_add("New Node", parent_id)
		command_manager_execute(&cmd)
		if add_data := cast(^Command_Node_Add)cmd.data; add_data != nil {
			editor.selected_entity = add_data.entity_id
		}
		// Expand the parent node
		if parent_id != 0 {
			if node, ok := scene_manager.current_scene.nodes[parent_id]; ok {
				node.expanded = true
				scene_manager.current_scene.nodes[parent_id] = node
			}
		} else {
			// Expand root node when adding a child to it
			if root, ok := scene_manager.current_scene.nodes[0]; ok {
				root.expanded = true
				scene_manager.current_scene.nodes[0] = root
			}
		}
	}

	imgui.Separator()

	// Render root node
	if root, ok := scene_manager.current_scene.nodes[0]; ok {
		// Create a unique label for the root node
		label := fmt.caprintf("%s###node_%d", root.name, root.id)
		defer delete(label)

		// Create a tree node for root
		flags := imgui.TreeNodeFlags{.OpenOnArrow}
		if editor.selected_entity == root.id {
			flags |= {.Selected}
		}
		if root.expanded {
			flags |= {.DefaultOpen}
		}

		if imgui.TreeNodeEx(label, flags) {
			// Handle root node selection
			if imgui.IsItemClicked() {
				editor.selected_entity = root.id
			}

			// Render root's children
			for child_id in root.children {
				render_node(child_id)
			}
			imgui.TreePop()
		}
	}

	imgui.End()
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

// Helper function to save the current scene
save_current_scene :: proc() {
	// Convert the name buffer to a string
	scene_name := string(editor.save_dialog_name[:])
	// Trim any null terminators
	for i := 0; i < len(scene_name); i += 1 {
		if scene_name[i] == 0 {
			scene_name = scene_name[:i]
			break
		}
	}

	// Create the save path
	save_path := fmt.tprintf("assets/scenes/%s.json", scene_name)
	if scene_manager_save(save_path) {
		editor.scene_path = save_path
		editor.show_save_dialog = false
	}
}

// Render the save dialog
render_save_dialog :: proc() {
	if editor.show_save_dialog {
		// Center the window
		viewport := imgui.GetMainViewport()
		center := viewport.WorkPos + viewport.WorkSize * 0.5
		size := imgui.Vec2{400, 150}
		pos := center - size * 0.5

		imgui.SetNextWindowPos(pos, .None)
		imgui.SetNextWindowSize(size, .None)

		if imgui.Begin("Save Scene", &editor.show_save_dialog, {.NoCollapse}) {
			imgui.Text("Enter scene name:")
			imgui.Spacing()

			// Text input for scene name
			if imgui.InputText(
				"Scene Name",
				cstring(raw_data(editor.save_dialog_name[:])),
				len(editor.save_dialog_name),
				imgui.InputTextFlags{.EnterReturnsTrue},
			) {
				save_current_scene()
			}

			imgui.Spacing()
			if imgui.Button("Save") {
				save_current_scene()
			}

			imgui.SameLine()
			if imgui.Button("Cancel") {
				editor.show_save_dialog = false
				// Clear the buffer when canceling
				for i in 0 ..< len(editor.save_dialog_name) {
					editor.save_dialog_name[i] = 0
				}
			}
		}
		imgui.End()
	}
}

// Render the unsaved changes dialog
render_unsaved_dialog :: proc() {
	if editor.show_unsaved_dialog {
		// Center the window
		viewport := imgui.GetMainViewport()
		center := viewport.WorkPos + viewport.WorkSize * 0.5
		size := imgui.Vec2{400, 150}
		pos := center - size * 0.5

		imgui.SetNextWindowPos(pos, .None)
		imgui.SetNextWindowSize(size, .None)

		if imgui.Begin("Unsaved Changes", &editor.show_unsaved_dialog, {.NoCollapse}) {
			imgui.Text("Do you want to save your changes?")
			imgui.Spacing()

			if imgui.Button("Save") {
				if editor.scene_path == "" {
					editor.show_save_dialog = true
				} else {
					scene_manager_save(editor.scene_path)
				}
				editor.show_unsaved_dialog = false
				// Perform the pending action after saving
				perform_pending_action()
			}

			imgui.SameLine()
			if imgui.Button("Don't Save") {
				editor.show_unsaved_dialog = false
				// Perform the pending action without saving
				perform_pending_action()
			}

			imgui.SameLine()
			if imgui.Button("Cancel") {
				editor.show_unsaved_dialog = false
				editor.pending_action = ""
			}
		}
		imgui.End()
	}
}

// Perform the pending action after handling unsaved changes
perform_pending_action :: proc() {
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

// Check for unsaved changes and show dialog if needed
check_unsaved_changes :: proc(action: string) -> bool {
	if scene_manager_is_dirty() {
		editor.show_unsaved_dialog = true
		editor.pending_action = action
		return true
	}
	return false
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
			if imgui.MenuItem("New Scene") {
				if !check_unsaved_changes("new") {
					scene_manager_new("Untitled")
					editor.scene_path = ""
				}
			}
			if imgui.MenuItem("Open Scene") {
				if !check_unsaved_changes("open") {
					scan_directory(editor.current_dir)
					editor.show_open_dialog = true
				}
			}
			if imgui.MenuItem("Save Scene") {
				if editor.scene_path == "" {
					editor.show_save_dialog = true
					// Initialize the name buffer with zeros
					for i in 0 ..< len(editor.save_dialog_name) {
						editor.save_dialog_name[i] = 0
					}
					// Copy current scene name if it exists
					if scene_manager.current_scene.name != "" {
						copy(editor.save_dialog_name[:], scene_manager.current_scene.name)
					}
				} else {
					scene_manager_save(editor.scene_path)
				}
			}
			if imgui.MenuItem("Save Scene As...") {
				editor.show_save_dialog = true
				// Initialize the name buffer with zeros
				for i in 0 ..< len(editor.save_dialog_name) {
					editor.save_dialog_name[i] = 0
				}
				// Copy current scene name if it exists
				if scene_manager.current_scene.name != "" {
					copy(editor.save_dialog_name[:], scene_manager.current_scene.name)
				}
			}
			imgui.Separator()
			if imgui.MenuItem("Exit", "Alt+F4") {
				if !check_unsaved_changes("exit") {
					// TODO: Handle exit
				}
			}
			imgui.EndMenu()
		}

		// Edit menu
		if imgui.BeginMenu("Edit") {
			if imgui.MenuItem("Undo", "Ctrl+Z", false, command_manager_can_undo()) {
				command_manager_undo()
			}
			if imgui.MenuItem("Redo", "Ctrl+Y", false, command_manager_can_redo()) {
				command_manager_redo()
			}
			imgui.EndMenu()
		}

		// Entity menu
		if imgui.BeginMenu("Entity") {
			if imgui.MenuItem("Add Empty", "Ctrl+Shift+N") {
				entity := ecs_create_entity()
				scene_manager_add_entity(entity)
				editor.selected_entity = entity
			}
			if imgui.BeginMenu("3D Object") {
				if imgui.MenuItem("Cube") {
					entity := ecs_create_entity()
					transform := ecs_add_transform(entity)
					renderer := ecs_add_renderer(entity)
					if transform != nil && renderer != nil {
						renderer.mesh = "cube"
						renderer.material = "default"
					}
					scene_manager_add_entity(entity)
					editor.selected_entity = entity
				}
				if imgui.MenuItem("Sphere") {
					entity := ecs_create_entity()
					transform := ecs_add_transform(entity)
					renderer := ecs_add_renderer(entity)
					if transform != nil && renderer != nil {
						renderer.mesh = "sphere"
						renderer.material = "default"
					}
					scene_manager_add_entity(entity)
					editor.selected_entity = entity
				}
				imgui.EndMenu()
			}
			if imgui.BeginMenu("Light") {
				if imgui.MenuItem("Directional Light") {
					entity := ecs_create_entity()
					transform := ecs_add_transform(entity)
					light := ecs_add_light(entity, .DIRECTIONAL)
					if transform != nil && light != nil {
						scene_manager_add_entity(entity)
						editor.selected_entity = entity
					}
				}
				if imgui.MenuItem("Point Light") {
					entity := ecs_create_entity()
					transform := ecs_add_transform(entity)
					light := ecs_add_light(entity, .POINT)
					if transform != nil && light != nil {
						scene_manager_add_entity(entity)
						editor.selected_entity = entity
					}
				}
				if imgui.MenuItem("Spot Light") {
					entity := ecs_create_entity()
					transform := ecs_add_transform(entity)
					light := ecs_add_light(entity, .SPOT)
					if transform != nil && light != nil {
						scene_manager_add_entity(entity)
						editor.selected_entity = entity
					}
				}
				imgui.EndMenu()
			}
			if imgui.MenuItem("Camera") {
				entity := ecs_create_entity()
				transform := ecs_add_transform(entity)
				camera := ecs_add_camera(entity, 45.0, 0.1, 1000.0, true) // Set as main camera
				if transform != nil && camera != nil {
					scene_manager_add_entity(entity)
					editor.selected_entity = entity
				}
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

// Handle editor input
editor_handle_input :: proc() {
	// Handle keyboard shortcuts
	if imgui.IsKeyDown(.LeftCtrl) || imgui.IsKeyDown(.RightCtrl) {
		// Save (Ctrl+S)
		if imgui.IsKeyPressed(.S) {
			if editor.scene_path == "" {
				editor.show_save_dialog = true
			} else {
				scene_manager_save(editor.scene_path)
			}
		}
		// Open (Ctrl+O)
		if imgui.IsKeyPressed(.O) {
			if !check_unsaved_changes("open") {
				scan_directory(editor.current_dir)
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
