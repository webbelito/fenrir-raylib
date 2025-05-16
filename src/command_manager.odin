package main

import "core:log"
import "core:mem"

// Command interface that all commands must implement
Command :: struct {
	vtable: ^Command_VTable,
	data:   rawptr,
}

Command_VTable :: struct {
	execute: proc(cmd: ^Command),
	undo:    proc(cmd: ^Command),
	redo:    proc(cmd: ^Command),
	destroy: proc(cmd: ^Command),
	copy:    proc(cmd: ^Command) -> Command,
}

// Command manager to handle undo/redo stack
Command_Manager :: struct {
	undo_stack:     [dynamic]Command,
	redo_stack:     [dynamic]Command,
	max_stack_size: int,
}

// Global command manager instance
command_manager: Command_Manager

// Initialize the command manager
command_manager_init :: proc(max_stack_size: int = 100) {
	command_manager = Command_Manager {
		undo_stack     = make([dynamic]Command),
		redo_stack     = make([dynamic]Command),
		max_stack_size = max_stack_size,
	}
	log_info(.ENGINE, "Command manager initialized")
}

// Shutdown the command manager
command_manager_shutdown :: proc() {
	// Clear and destroy all commands in both stacks
	for &cmd in command_manager.undo_stack {
		cmd.vtable.destroy(&cmd)
	}
	for &cmd in command_manager.redo_stack {
		cmd.vtable.destroy(&cmd)
	}
	delete(command_manager.undo_stack)
	delete(command_manager.redo_stack)
	log_info(.ENGINE, "Command manager shut down")
}

// Execute a new command
command_manager_execute :: proc(cmd: ^Command) {
	// Validate command
	if cmd == nil {
		log_error(.ENGINE, "Cannot execute nil command")
		return
	}
	if cmd.vtable == nil {
		log_error(.ENGINE, "Cannot execute command with nil vtable")
		return
	}
	if cmd.data == nil {
		log_error(.ENGINE, "Cannot execute command with nil data")
		return
	}

	// Clear redo stack when new command is executed
	for &cmd in command_manager.redo_stack {
		cmd.vtable.destroy(&cmd)
	}
	clear(&command_manager.redo_stack)

	// Execute the command
	cmd.vtable.execute(cmd)

	// Add to undo stack
	append(&command_manager.undo_stack, cmd^)

	// Maintain max stack size
	if len(command_manager.undo_stack) > command_manager.max_stack_size {
		old_cmd := command_manager.undo_stack[0]
		old_cmd.vtable.destroy(&old_cmd)
		ordered_remove(&command_manager.undo_stack, 0)
	}
}

// Undo the last command
command_manager_undo :: proc() {
	if len(command_manager.undo_stack) == 0 {
		return
	}

	// Get the last command
	cmd := command_manager.undo_stack[len(command_manager.undo_stack) - 1]

	// Validate command
	if cmd.vtable == nil {
		log_error(.ENGINE, "Cannot undo command with nil vtable")
		pop(&command_manager.undo_stack)
		return
	}
	if cmd.data == nil {
		log_error(.ENGINE, "Cannot undo command with nil data")
		pop(&command_manager.undo_stack)
		return
	}

	// Create a new command with copied data
	new_cmd := cmd.vtable.copy(&cmd)

	// Validate copied command
	if new_cmd.vtable == nil || new_cmd.data == nil {
		log_error(.ENGINE, "Failed to copy command for redo stack")
		cmd.vtable.destroy(&cmd)
		pop(&command_manager.undo_stack)
		return
	}

	// Undo the original command
	cmd.vtable.undo(&cmd)

	// Add the copied command to redo stack
	append(&command_manager.redo_stack, new_cmd)

	// Destroy and remove from undo stack
	cmd.vtable.destroy(&cmd)
	pop(&command_manager.undo_stack)

	log_info(.ENGINE, "Undo %s", get_command_name(&new_cmd))
}

// Redo the last undone command
command_manager_redo :: proc() {
	if len(command_manager.redo_stack) == 0 {
		return
	}

	// Get the last undone command
	cmd := command_manager.redo_stack[len(command_manager.redo_stack) - 1]

	// Validate command
	if cmd.vtable == nil {
		log_error(.ENGINE, "Cannot redo command with nil vtable")
		pop(&command_manager.redo_stack)
		return
	}
	if cmd.data == nil {
		log_error(.ENGINE, "Cannot redo command with nil data")
		pop(&command_manager.redo_stack)
		return
	}

	// Create a new command with copied data
	new_cmd := cmd.vtable.copy(&cmd)

	// Validate copied command
	if new_cmd.vtable == nil || new_cmd.data == nil {
		log_error(.ENGINE, "Failed to copy command for undo stack")
		cmd.vtable.destroy(&cmd)
		pop(&command_manager.redo_stack)
		return
	}

	// Redo the original command
	cmd.vtable.redo(&cmd)

	// Add the copied command to undo stack
	append(&command_manager.undo_stack, new_cmd)

	// Destroy and remove from redo stack
	cmd.vtable.destroy(&cmd)
	pop(&command_manager.redo_stack)

	log_info(.ENGINE, "Redo %s", get_command_name(&new_cmd))
}

// Check if undo is available
command_manager_can_undo :: proc() -> bool {
	return len(command_manager.undo_stack) > 0
}

// Check if redo is available
command_manager_can_redo :: proc() -> bool {
	return len(command_manager.redo_stack) > 0
}

// Clear all commands
command_manager_clear :: proc() {
	for &cmd in command_manager.undo_stack {
		cmd.vtable.destroy(&cmd)
	}
	for &cmd in command_manager.redo_stack {
		cmd.vtable.destroy(&cmd)
	}
	clear(&command_manager.undo_stack)
	clear(&command_manager.redo_stack)
}

// Get the name of a command
get_command_name :: proc(cmd: ^Command) -> string {
	if cmd == nil do return "Unknown"

	if cmd.vtable == &entity_add_vtable {
		return "Add Entity"
	} else if cmd.vtable == &entity_delete_vtable {
		return "Delete Entity"
	} else if cmd.vtable == &entity_rename_vtable {
		return "Rename Entity"
	} else if cmd.vtable == &create_entity_vtable {
		return "Create Entity"
	}

	return "Unknown Command"
}
