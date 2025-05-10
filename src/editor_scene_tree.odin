package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:strings"

// Scene tree state
Scene_Tree_State :: struct {
	initialized:   bool,
	renaming_node: Entity,
	rename_buffer: [256]u8, // Fixed-size buffer for renaming
}

scene_tree: Scene_Tree_State

// Initialize the scene tree
editor_scene_tree_init :: proc() -> bool {
	if scene_tree.initialized {
		return true
	}

	scene_tree = Scene_Tree_State {
		initialized   = true,
		renaming_node = 0, // Ensure no node is being renamed at startup
	}

	// Initialize rename buffer with zeros
	for i in 0 ..< len(scene_tree.rename_buffer) {
		scene_tree.rename_buffer[i] = 0
	}

	// Ensure root node is properly initialized
	if root, ok := scene_manager.current_scene.nodes[0]; ok {
		root.expanded = true
		scene_manager.current_scene.nodes[0] = root
	}

	log_info(.ENGINE, "Scene tree initialized")
	return true
}

// Shutdown the scene tree
editor_scene_tree_shutdown :: proc() {
	if !scene_tree.initialized {
		return
	}

	scene_tree.initialized = false
	log_info(.ENGINE, "Scene tree shut down")
}

// Update the scene tree
editor_scene_tree_update :: proc() {
	if !editor.scene_tree_open {
		return
	}

	// Handle any scene tree updates here
	// For example, handle drag and drop, selection changes, etc.
}

// Render the scene tree
editor_scene_tree_render :: proc() {
	if !editor.scene_tree_open {
		return
	}

	// Add Unity-style "+" button with dropdown
	if imgui.Button("+") {
		imgui.OpenPopup("AddEntityPopup")
	}

	if imgui.BeginPopup("AddEntityPopup") {
		if imgui.MenuItem("Empty") {
			cmd := command_create_node_add("Empty", editor.selected_entity)
			command_manager_execute(&cmd)
			if cmd.data != nil {
				if data := cast(^Command_Node_Add)cmd.data; data != nil {
					editor.selected_entity = data.entity_id
				}
			}
		}
		if imgui.BeginMenu("3D Object") {
			if imgui.MenuItem("Cube") {
				cmd := command_create_node_add("Cube", editor.selected_entity)
				command_manager_execute(&cmd)
				if cmd.data != nil {
					if data := cast(^Command_Node_Add)cmd.data; data != nil {
						transform := ecs_add_transform(data.entity_id)
						renderer := ecs_add_renderer(data.entity_id)
						if transform != nil && renderer != nil {
							renderer.model_type = .CUBE
							renderer.mesh_path = "cube"
							renderer.material_path = "default"
						}
						editor.selected_entity = data.entity_id
					}
				}
			}
			if imgui.MenuItem("Ambulance") {
				cmd := command_create_node_add("Ambulance", editor.selected_entity)
				command_manager_execute(&cmd)
				if cmd.data != nil {
					if data := cast(^Command_Node_Add)cmd.data; data != nil {
						transform := ecs_add_transform(data.entity_id)
						renderer := ecs_add_renderer(data.entity_id)
						if transform != nil && renderer != nil {
							renderer.model_type = .AMBULANCE
							renderer.mesh_path = "assets/meshes/ambulance.glb"
							renderer.material_path = "assets/meshes/Textures/colormap.png"
						}
						editor.selected_entity = data.entity_id
					}
				}
			}
			imgui.EndMenu()
		}
		if imgui.BeginMenu("Light") {
			if imgui.MenuItem("Directional Light") {
				cmd := command_create_node_add("Directional Light", editor.selected_entity)
				command_manager_execute(&cmd)
				if cmd.data != nil {
					if data := cast(^Command_Node_Add)cmd.data; data != nil {
						transform := ecs_add_transform(data.entity_id)
						light := ecs_add_light(data.entity_id, .DIRECTIONAL)
						if transform != nil && light != nil {
							editor.selected_entity = data.entity_id
						}
					}
				}
			}
			if imgui.MenuItem("Point Light") {
				cmd := command_create_node_add("Point Light", editor.selected_entity)
				command_manager_execute(&cmd)
				if cmd.data != nil {
					if data := cast(^Command_Node_Add)cmd.data; data != nil {
						transform := ecs_add_transform(data.entity_id)
						light := ecs_add_light(data.entity_id, .POINT)
						if transform != nil && light != nil {
							editor.selected_entity = data.entity_id
						}
					}
				}
			}
			if imgui.MenuItem("Spot Light") {
				cmd := command_create_node_add("Spot Light", editor.selected_entity)
				command_manager_execute(&cmd)
				if cmd.data != nil {
					if data := cast(^Command_Node_Add)cmd.data; data != nil {
						transform := ecs_add_transform(data.entity_id)
						light := ecs_add_light(data.entity_id, .SPOT)
						if transform != nil && light != nil {
							editor.selected_entity = data.entity_id
						}
					}
				}
			}
			imgui.EndMenu()
		}
		if imgui.MenuItem("Camera") {
			cmd := command_create_node_add("Camera", editor.selected_entity)
			command_manager_execute(&cmd)
			if cmd.data != nil {
				if data := cast(^Command_Node_Add)cmd.data; data != nil {
					transform := ecs_add_transform(data.entity_id)
					camera := ecs_add_camera(data.entity_id, 45.0, 0.1, 1000.0, true)
					if transform != nil && camera != nil {
						editor.selected_entity = data.entity_id
					}
				}
			}
		}
		imgui.EndPopup()
	}

	imgui.SameLine()
	imgui.Text("Scene")

	imgui.Separator()

	// Render the root node and its children
	scene_tree_render_node(0)
}

// Render a node in the scene tree
scene_tree_render_node :: proc(node_id: Entity) {
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

				// Handle double-click for renaming (skip for root node)
				if node_id != 0 && imgui.IsItemHovered() && imgui.IsMouseDoubleClicked(.Left) {
					scene_tree.renaming_node = node_id
					// Clear the buffer
					for i in 0 ..< len(scene_tree.rename_buffer) {
						scene_tree.rename_buffer[i] = 0
					}
					// Copy the current name
					copy(scene_tree.rename_buffer[:], node.name)
				}

				// Render context menu (skip for root node)
				if node_id != 0 && imgui.BeginPopupContextItem() {
					if imgui.MenuItem("Rename") {
						scene_tree.renaming_node = node_id
						// Clear the buffer
						for i in 0 ..< len(scene_tree.rename_buffer) {
							scene_tree.rename_buffer[i] = 0
						}
						// Copy the current name
						copy(scene_tree.rename_buffer[:], node.name)
					}
					if imgui.MenuItem("Add Child") {
						// Create a new node with a default name
						new_name := "New Node"
						if new_id := scene_manager_create_node(new_name, node_id); new_id != 0 {
							// Create and execute the command
							cmd := command_create_node_add(new_name, node_id)
							command_manager_execute(&cmd)

							// Select the new node
							editor.selected_entity = new_id

							// Update the parent node's expanded state
							if parent, ok := scene_manager.current_scene.nodes[node_id]; ok {
								parent.expanded = true
								scene_manager.current_scene.nodes[node_id] = parent
							}
						}
					}
					if imgui.MenuItem("Delete Node") {
						cmd := command_create_node_delete(node_id)
						command_manager_execute(&cmd)
						if editor.selected_entity == node_id {
							editor.selected_entity = 0
						}
					}
					imgui.EndPopup()
				}

				// Render rename input if this node is being renamed (skip for root node)
				if node_id != 0 && scene_tree.renaming_node == node_id {
					imgui.SetKeyboardFocusHere()
					if imgui.InputText(
						"###rename_input",
						cstring(raw_data(scene_tree.rename_buffer[:])),
						len(scene_tree.rename_buffer),
						imgui.InputTextFlags{.EnterReturnsTrue},
					) {
						// Update node name using command
						new_name := string(scene_tree.rename_buffer[:])
						cmd := command_create_node_rename(node_id, new_name)
						command_manager_execute(&cmd)
						scene_tree.renaming_node = 0
					}
					// Cancel renaming on escape
					if imgui.IsKeyPressed(.Escape) {
						scene_tree.renaming_node = 0
					}
				}

				// Render children
				for child_id in node.children {
					scene_tree_render_node(child_id)
				}

				imgui.TreePop()
			}
		} else {
			// Leaf node
			if imgui.Selectable(label, editor.selected_entity == node_id) {
				editor.selected_entity = node_id
			}

			// Handle double-click for renaming (skip for root node)
			if node_id != 0 && imgui.IsItemHovered() && imgui.IsMouseDoubleClicked(.Left) {
				scene_tree.renaming_node = node_id
				// Clear the buffer
				for i in 0 ..< len(scene_tree.rename_buffer) {
					scene_tree.rename_buffer[i] = 0
				}
				// Copy the current name
				copy(scene_tree.rename_buffer[:], node.name)
			}

			// Render context menu (skip for root node)
			if node_id != 0 && imgui.BeginPopupContextItem() {
				if imgui.MenuItem("Rename") {
					scene_tree.renaming_node = node_id
					// Clear the buffer
					for i in 0 ..< len(scene_tree.rename_buffer) {
						scene_tree.rename_buffer[i] = 0
					}
					// Copy the current name
					copy(scene_tree.rename_buffer[:], node.name)
				}
				if imgui.MenuItem("Add Child") {
					// Create a new node with a default name
					new_name := "New Node"
					if new_id := scene_manager_create_node(new_name, node_id); new_id != 0 {
						// Create and execute the command
						cmd := command_create_node_add(new_name, node_id)
						command_manager_execute(&cmd)

						// Select the new node
						editor.selected_entity = new_id

						// Update the parent node's expanded state
						if parent, ok := scene_manager.current_scene.nodes[node_id]; ok {
							parent.expanded = true
							scene_manager.current_scene.nodes[node_id] = parent
						}
					}
				}
				if imgui.MenuItem("Delete Node") {
					cmd := command_create_node_delete(node_id)
					command_manager_execute(&cmd)
					if editor.selected_entity == node_id {
						editor.selected_entity = 0
					}
				}
				imgui.EndPopup()
			}

			// Render rename input if this node is being renamed (skip for root node)
			if node_id != 0 && scene_tree.renaming_node == node_id {
				imgui.SetKeyboardFocusHere()
				if imgui.InputText(
					"###rename_input",
					cstring(raw_data(scene_tree.rename_buffer[:])),
					len(scene_tree.rename_buffer),
					imgui.InputTextFlags{.EnterReturnsTrue},
				) {
					// Update node name using command
					new_name := string(scene_tree.rename_buffer[:])
					cmd := command_create_node_rename(node_id, new_name)
					command_manager_execute(&cmd)
					scene_tree.renaming_node = 0
				}
				// Cancel renaming on escape
				if imgui.IsKeyPressed(.Escape) {
					scene_tree.renaming_node = 0
				}
			}
		}
	}
}
