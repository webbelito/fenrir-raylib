package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:strings"

// Command data for node operations
Command_Node_Add :: struct {
	entity_id: Entity,
	parent_id: Entity,
	name:      string,
}

Command_Node_Delete :: struct {
	entity_id: Entity,
	parent_id: Entity,
	name:      string,
	children:  [dynamic]Entity,
}

Command_Node_Duplicate :: struct {
	original_id: Entity,
	new_id:      Entity,
	parent_id:   Entity,
	name:        string,
}

// Command type identification
Command_Type :: enum {
	Add,
	Delete,
	Duplicate,
}

// Get command type for logging
get_command_type :: proc(cmd: ^Command) -> Command_Type {
	if cmd.vtable == &node_add_vtable {
		return .Add
	} else if cmd.vtable == &node_delete_vtable {
		return .Delete
	} else if cmd.vtable == &node_duplicate_vtable {
		return .Duplicate
	}
	return .Add // Default case
}

// Get command name for logging
get_command_name :: proc(cmd: ^Command) -> string {
	switch get_command_type(cmd) {
	case .Add:
		if data := cast(^Command_Node_Add)cmd.data; data != nil {
			return fmt.tprintf("Add Node '%s'", data.name)
		}
	case .Delete:
		if data := cast(^Command_Node_Delete)cmd.data; data != nil {
			return fmt.tprintf("Delete Node '%s'", data.name)
		}
	case .Duplicate:
		if data := cast(^Command_Node_Duplicate)cmd.data; data != nil {
			return fmt.tprintf("Duplicate Node '%s'", data.name)
		}
	}
	return "Unknown Command"
}

// Command implementations
command_node_add_execute :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Add)cmd.data
	if data == nil do return

	// Create the node
	if new_id := scene_manager_create_node(data.name, data.parent_id); new_id != 0 {
		data.entity_id = new_id
		log_info(.ENGINE, "Added node '%s'", data.name)
	}
}

command_node_add_undo :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Add)cmd.data
	if data == nil do return

	// Get the node before deleting
	if node, ok := scene_manager.current_scene.nodes[data.entity_id]; ok {
		// Don't allow deleting the root node
		if data.entity_id == 0 {
			log_warning(.ENGINE, "Cannot delete root node")
			return
		}

		// Remove from parent's children
		if parent, ok := scene_manager.current_scene.nodes[node.parent_id]; ok {
			for i := 0; i < len(parent.children); i += 1 {
				if parent.children[i] == data.entity_id {
					ordered_remove(&parent.children, i)
					break
				}
			}
			scene_manager.current_scene.nodes[node.parent_id] = parent
		}

		// Remove from scene
		delete_key(&scene_manager.current_scene.nodes, data.entity_id)

		// Remove from entities list
		for i := 0; i < len(scene_manager.current_scene.entities); i += 1 {
			if scene_manager.current_scene.entities[i] == data.entity_id {
				ordered_remove(&scene_manager.current_scene.entities, i)
				break
			}
		}

		// Clean up node resources
		delete(node.name)
		delete(node.children)

		// Destroy the entity and its components
		ecs_destroy_entity(data.entity_id)

		// If the deleted node was selected, select the root node instead
		if editor.selected_entity == data.entity_id {
			editor.selected_entity = 0
		}

		scene_manager.current_scene.dirty = true
	}
}

command_node_add_redo :: proc(cmd: ^Command) {
	command_node_add_execute(cmd)
}

command_node_add_destroy :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Add)cmd.data
	if data == nil do return

	delete(data.name)
	free(data)
}

// Static vtables for each command type
node_add_vtable := Command_VTable {
	execute = command_node_add_execute,
	undo    = command_node_add_undo,
	redo    = command_node_add_redo,
	destroy = command_node_add_destroy,
	copy    = command_node_add_copy,
}

command_node_delete_execute :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Delete)cmd.data
	if data == nil do return

	// Store node info before deleting
	if node, ok := scene_manager.current_scene.nodes[data.entity_id]; ok {
		data.name = strings.clone(node.name)
		data.parent_id = node.parent_id
		data.children = make([dynamic]Entity)
		for child in node.children {
			append(&data.children, child)
		}
		log_info(.ENGINE, "Deleted node '%s'", data.name)
	}

	// Delete the node
	scene_manager_delete_node(data.entity_id)
}

command_node_delete_undo :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Delete)cmd.data
	if data == nil do return

	// Recreate the node
	if new_id := scene_manager_create_node(data.name, data.parent_id); new_id != 0 {
		data.entity_id = new_id

		// Restore children
		for child_id in data.children {
			if child, ok := scene_manager.current_scene.nodes[child_id]; ok {
				// Update child's parent to point to the recreated node
				child.parent_id = new_id
				scene_manager.current_scene.nodes[child_id] = child

				// Add child to the recreated node's children
				if parent, ok := scene_manager.current_scene.nodes[new_id]; ok {
					append(&parent.children, child_id)
					scene_manager.current_scene.nodes[new_id] = parent
				}
			}
		}

		// If the node was selected before deletion, select it again
		if editor.selected_entity == 0 {
			editor.selected_entity = new_id
		}
	}
}

command_node_delete_redo :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Delete)cmd.data
	if data == nil do return

	// Delete the node
	scene_manager_delete_node(data.entity_id)

	// If the deleted node was selected, select the root node instead
	if editor.selected_entity == data.entity_id {
		editor.selected_entity = 0
	}
}

command_node_delete_destroy :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Delete)cmd.data
	if data == nil do return

	delete(data.name)
	delete(data.children)
	free(data)
}

// Static vtables for each command type
node_delete_vtable := Command_VTable {
	execute = command_node_delete_execute,
	undo    = command_node_delete_undo,
	redo    = command_node_delete_redo,
	destroy = command_node_delete_destroy,
	copy    = command_node_delete_copy,
}

command_node_add_copy :: proc(cmd: ^Command) -> Command {
	data := cast(^Command_Node_Add)cmd.data
	if data == nil do return cmd^

	new_data := new(Command_Node_Add)
	new_data^ = Command_Node_Add {
		entity_id = data.entity_id,
		parent_id = data.parent_id,
		name      = strings.clone(data.name),
	}

	return Command{vtable = &node_add_vtable, data = new_data}
}

command_node_delete_copy :: proc(cmd: ^Command) -> Command {
	data := cast(^Command_Node_Delete)cmd.data
	if data == nil do return cmd^

	new_data := new(Command_Node_Delete)
	new_data^ = Command_Node_Delete {
		entity_id = data.entity_id,
		parent_id = data.parent_id,
		name      = strings.clone(data.name),
		children  = make([dynamic]Entity),
	}
	for child in data.children {
		append(&new_data.children, child)
	}

	return Command{vtable = &node_delete_vtable, data = new_data}
}

command_node_duplicate_execute :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Duplicate)cmd.data
	if data == nil do return

	// Duplicate the node
	if new_id := scene_manager_duplicate_node(data.original_id); new_id != 0 {
		data.new_id = new_id
		if node, ok := scene_manager.current_scene.nodes[new_id]; ok {
			data.name = strings.clone(node.name)
			data.parent_id = node.parent_id
			log_info(.ENGINE, "Duplicated node '%s'", data.name)
		}
	}
}

command_node_duplicate_undo :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Duplicate)cmd.data
	if data == nil do return

	// Delete the duplicated node
	scene_manager_delete_node(data.new_id)
	log_info(.ENGINE, "Undid duplicating node '%s'", data.name)
}

command_node_duplicate_redo :: proc(cmd: ^Command) {
	command_node_duplicate_execute(cmd)
}

command_node_duplicate_destroy :: proc(cmd: ^Command) {
	data := cast(^Command_Node_Duplicate)cmd.data
	if data == nil do return

	delete(data.name)
	free(data)
}

// Static vtables for each command type
node_duplicate_vtable := Command_VTable {
	execute = command_node_duplicate_execute,
	undo    = command_node_duplicate_undo,
	redo    = command_node_duplicate_redo,
	destroy = command_node_duplicate_destroy,
	copy    = command_node_duplicate_copy,
}

command_node_duplicate_copy :: proc(cmd: ^Command) -> Command {
	data := cast(^Command_Node_Duplicate)cmd.data
	if data == nil do return cmd^

	new_data := new(Command_Node_Duplicate)
	new_data^ = Command_Node_Duplicate {
		original_id = data.original_id,
		new_id      = data.new_id,
		parent_id   = data.parent_id,
		name        = strings.clone(data.name),
	}

	return Command{vtable = &node_duplicate_vtable, data = new_data}
}

// Command creation functions
command_create_node_add :: proc(name: string, parent_id: Entity) -> Command {
	// Verify parent exists
	if parent_id != 0 {
		if _, ok := scene_manager.current_scene.nodes[parent_id]; !ok {
			log_error(.ENGINE, "Parent node not found: %d", parent_id)
			return Command{}
		}
	}

	data := new(Command_Node_Add)
	data^ = Command_Node_Add {
		entity_id = 0,
		parent_id = parent_id,
		name      = strings.clone(name),
	}

	return Command{vtable = &node_add_vtable, data = data}
}

command_create_node_delete :: proc(entity_id: Entity) -> Command {
	data := new(Command_Node_Delete)
	data^ = Command_Node_Delete {
		entity_id = entity_id,
		parent_id = 0,
		name      = "",
		children  = make([dynamic]Entity),
	}

	return Command{vtable = &node_delete_vtable, data = data}
}

command_create_node_duplicate :: proc(entity_id: Entity) -> Command {
	data := new(Command_Node_Duplicate)
	data^ = Command_Node_Duplicate {
		original_id = entity_id,
		new_id      = 0,
		parent_id   = 0,
		name        = "",
	}

	return Command{vtable = &node_duplicate_vtable, data = data}
}
