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

	// Undo the command
	cmd.vtable.undo(&cmd)

	// Move to redo stack
	append(&command_manager.redo_stack, cmd)
	pop(&command_manager.undo_stack)

	log_info(.ENGINE, "Undo\n")
}

// Redo the last undone command
command_manager_redo :: proc() {
	if len(command_manager.redo_stack) == 0 {
		return
	}

	// Get the last undone command
	cmd := command_manager.redo_stack[len(command_manager.redo_stack) - 1]

	// Redo the command
	cmd.vtable.redo(&cmd)

	// Move back to undo stack
	append(&command_manager.undo_stack, cmd)
	pop(&command_manager.redo_stack)

	log_info(.ENGINE, "Redo\n")
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
