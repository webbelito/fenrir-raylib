package main

import "core:fmt"
import "core:log"
import raylib "vendor:raylib"

// Command to modify a transform component
Command_Transform :: struct {
	entity:        Entity,
	old_transform: Transform,
	new_transform: Transform,
}

// Create a new transform command
create_transform_command :: proc(
	entity: Entity,
	old_transform: Transform,
	new_transform: Transform,
) -> ^Command_Transform {
	command := new(Command_Transform)
	command^ = Command_Transform {
		entity        = entity,
		old_transform = old_transform,
		new_transform = new_transform,
	}
	return command
}

// Execute the transform command
execute_transform_command :: proc(command: ^Command_Transform) {
	if command == nil do return

	if transform := ecs_get_component(command.entity, Transform); transform != nil {
		transform^ = command.new_transform
		transform.dirty = true
	}
}

// Undo the transform command
undo_transform_command :: proc(command: ^Command_Transform) {
	if command == nil do return

	if transform := ecs_get_component(command.entity, Transform); transform != nil {
		transform^ = command.old_transform
		transform.dirty = true
	}
}

// Free the transform command
free_transform_command :: proc(command: ^Command_Transform) {
	if command == nil do return
	free(command)
}
