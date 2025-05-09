package main

import "core:log"
import "core:mem"
import raylib "vendor:raylib"

Transform_Command_Data :: struct {
	entity_id:     Entity,
	old_transform: Transform_Component,
	new_transform: Transform_Component,
}

transform_command_vtable := Command_VTable {
	execute = transform_command_execute,
	undo    = transform_command_undo,
	redo    = transform_command_redo,
	destroy = transform_command_destroy,
}

// Create a new transform command
transform_command_create :: proc(
	entity_id: Entity,
	old_transform: Transform_Component,
	new_transform: Transform_Component,
) -> Command {
	data := new(Transform_Command_Data)
	data^ = Transform_Command_Data {
		entity_id     = entity_id,
		old_transform = old_transform,
		new_transform = new_transform,
	}

	return Command{vtable = &transform_command_vtable, data = data}
}

// Execute the transform command
transform_command_execute :: proc(cmd: ^Command) {
	data := cast(^Transform_Command_Data)cmd.data
	if transform := ecs_get_transform(data.entity_id); transform != nil {
		transform^ = data.new_transform
	}
}

// Undo the transform command
transform_command_undo :: proc(cmd: ^Command) {
	data := cast(^Transform_Command_Data)cmd.data
	if transform := ecs_get_transform(data.entity_id); transform != nil {
		transform^ = data.old_transform
		log_info(.ENGINE, "Undo Transform")
	}
}

// Redo the transform command
transform_command_redo :: proc(cmd: ^Command) {
	data := cast(^Transform_Command_Data)cmd.data
	if transform := ecs_get_transform(data.entity_id); transform != nil {
		transform^ = data.new_transform
		log_info(.ENGINE, "Redo Transform")
	}
}

// Destroy the transform command
transform_command_destroy :: proc(cmd: ^Command) {
	data := cast(^Transform_Command_Data)cmd.data
	free(data)
}
