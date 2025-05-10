package main

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:strings"

// Render the editor menu bar
editor_menu_render :: proc() {
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
			imgui.Separator()
			if imgui.MenuItem("Delete Selected", "Delete", false, editor.selected_entity != 0) {
				if editor.selected_entity != 0 {
					scene_manager_delete_node(editor.selected_entity)
				}
			}
			imgui.EndMenu()
		}

		// Entity menu
		if imgui.BeginMenu("Entity") {
			if imgui.MenuItem("Add Empty", "Ctrl+Shift+N") {
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
			imgui.Separator()
			if imgui.MenuItem("Duplicate Selected", "Ctrl+D", false, editor.selected_entity != 0) {
				if editor.selected_entity != 0 {
					cmd := command_create_node_duplicate(editor.selected_entity)
					command_manager_execute(&cmd)
					if cmd.data != nil {
						if data := cast(^Command_Node_Duplicate)cmd.data; data != nil {
							editor.selected_entity = data.new_id
						}
					}
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
}
