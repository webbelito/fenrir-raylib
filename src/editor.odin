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
	initialized:      bool,
	selected_entity:  Entity,
	scene_tree_open:  bool,
	inspector_open:   bool,
	scene_path:       string,
	show_save_dialog: bool,
	save_dialog_name: [256]u8, // Buffer for scene name input
	show_open_dialog: bool, // Flag to show open scene dialog
	available_scenes: [dynamic]string, // List of available scene files
	current_dir:      string, // Current directory for file browser
	file_list:        [dynamic]string, // List of files in current directory
	selected_file:    string, // Currently selected file
}

editor: Editor_State

// Initialize the editor
editor_init :: proc() -> bool {
	if editor.initialized {
		return true
	}

	editor = Editor_State {
		initialized      = true,
		scene_tree_open  = true,
		inspector_open   = true,
		scene_path       = "",
		available_scenes = make([dynamic]string),
		current_dir      = "assets/scenes",
		file_list        = make([dynamic]string),
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
}

// Render a node in the scene tree
render_node :: proc(node_id: Entity) {
	if node, ok := current_scene.nodes[node_id]; ok {
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

				// Render context menu
				if imgui.BeginPopupContextItem() {
					if imgui.MenuItem("Add Child") {
						if new_node_id := create_node("New Node", node_id); new_node_id != 0 {
							editor.selected_entity = new_node_id
							// Update the node's expanded state
							if node, ok := current_scene.nodes[node_id]; ok {
								node.expanded = true
								current_scene.nodes[node_id] = node
							}
						}
					}
					if node_id != 0 && imgui.MenuItem("Delete Node") {
						delete_node(node_id)
						if editor.selected_entity == node_id {
							editor.selected_entity = 0
						}
					}
					imgui.EndPopup()
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

			// Render context menu for leaf nodes too
			if imgui.BeginPopupContextItem() {
				if imgui.MenuItem("Add Child") {
					if new_node_id := create_node("New Node", node_id); new_node_id != 0 {
						editor.selected_entity = new_node_id
						// Update the node's expanded state
						if node, ok := current_scene.nodes[node_id]; ok {
							node.expanded = true
							current_scene.nodes[node_id] = node
						}
					}
				}
				if node_id != 0 && imgui.MenuItem("Delete Node") {
					delete_node(node_id)
					if editor.selected_entity == node_id {
						editor.selected_entity = 0
					}
				}
				imgui.EndPopup()
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

	if !current_scene.loaded {
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
		if new_node_id := create_node("New Node", parent_id); new_node_id != 0 {
			editor.selected_entity = new_node_id
			// Expand the parent node
			if parent_id != 0 {
				if node, ok := current_scene.nodes[parent_id]; ok {
					node.expanded = true
					current_scene.nodes[parent_id] = node
				}
			} else {
				// Expand root node when adding a child to it
				if root, ok := current_scene.nodes[0]; ok {
					root.expanded = true
					current_scene.nodes[0] = root
				}
			}
		}
	}

	imgui.Separator()

	// Render root node
	if root, ok := current_scene.nodes[0]; ok {
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

// Render the file browser dialog
render_file_browser :: proc() {
	if editor.show_open_dialog {
		// Scan directory if needed
		if len(editor.file_list) == 0 {
			scan_directory(editor.current_dir)
		}

		imgui.SetNextWindowPos(imgui.GetIO().DisplaySize * 0.5, .Always, {0.5, 0.5})
		imgui.SetNextWindowSize({600, 400})
		if imgui.Begin(
			"Open Scene###OpenSceneWindow",
			&editor.show_open_dialog,
			{.AlwaysAutoResize, .NoCollapse},
		) {
			// Current directory
			imgui.Text("Current Directory: %s", editor.current_dir)
			imgui.Separator()

			// Display files
			for file, i in editor.file_list {
				file_cstr := strings.clone_to_cstring(file)
				defer delete(file_cstr)
				label := fmt.tprintf("##FileItem%d", i)
				label_cstr := strings.clone_to_cstring(label)
				defer delete(label_cstr)

				// Make the selectable area wider
				imgui.PushItemWidth(-1)
				if imgui.Selectable(label_cstr, file == editor.selected_file, {.SpanAllColumns}) {
					editor.selected_file = file
				}
				imgui.PopItemWidth()

				imgui.SameLine()
				imgui.Text(file_cstr)
			}

			imgui.Separator()
			// Buttons
			if imgui.Button("Open###OpenSceneOpenButton") {
				if editor.selected_file != "" {
					// Ensure we have a proper path with the filename
					path := fmt.tprintf("%s/%s", editor.current_dir, editor.selected_file)
					if !strings.has_suffix(path, ".json") {
						path = fmt.tprintf("%s.json", path)
					}
					log_info(.ENGINE, "Attempting to open scene: %s", path)
					if scene_load(path) {
						editor.scene_path = path
						editor.show_open_dialog = false
						log_info(.ENGINE, "Successfully opened scene: %s", path)
					} else {
						log_error(.ENGINE, "Failed to open scene: %s", path)
					}
				}
			}
			imgui.SameLine()
			if imgui.Button("Cancel###OpenSceneCancelButton") {
				editor.show_open_dialog = false
			}
		}
		imgui.End()
	}
}

// Render the save dialog
render_save_dialog :: proc() {
	if editor.show_save_dialog {
		imgui.SetNextWindowPos(imgui.GetIO().DisplaySize * 0.5, .Always, {0.5, 0.5})
		imgui.SetNextWindowSize({300, 100})
		if imgui.Begin(
			"Save Scene###SaveSceneWindow",
			&editor.show_save_dialog,
			{.AlwaysAutoResize, .NoCollapse},
		) {
			imgui.Text("Enter scene name:")
			imgui.Spacing()

			// Text input for scene name
			if imgui.InputText(
				"Scene Name###SaveSceneNameInput",
				cstring(raw_data(editor.save_dialog_name[:])),
				size_of(editor.save_dialog_name),
				imgui.InputTextFlags{.EnterReturnsTrue},
			) {
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
				if scene_save(save_path) {
					editor.scene_path = save_path
					editor.show_save_dialog = false
				}
			}

			imgui.Spacing()
			if imgui.Button("Save###SaveSceneSaveButton") {
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
				if scene_save(save_path) {
					editor.scene_path = save_path
					editor.show_save_dialog = false
				}
			}

			imgui.SameLine()
			if imgui.Button("Cancel###SaveSceneCancelButton") {
				editor.show_save_dialog = false
			}
		}
		imgui.End()
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
				scan_directory(editor.current_dir) // Refresh the list
				editor.show_open_dialog = true
			}
			if imgui.MenuItem("Save Scene", "Ctrl+S") {
				if editor.scene_path == "" {
					editor.show_save_dialog = true
					// Initialize the name buffer with the current scene name
					copy(editor.save_dialog_name[:], current_scene.name)
				} else {
					scene_save(editor.scene_path)
				}
			}
			if imgui.MenuItem("Save Scene As...", "Ctrl+Shift+S") {
				editor.show_save_dialog = true
				// Initialize the name buffer with the current scene name
				copy(editor.save_dialog_name[:], current_scene.name)
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

	// Render dialogs
	render_file_browser()
	render_save_dialog()

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
