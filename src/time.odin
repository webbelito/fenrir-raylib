package main

import "core:log"
import "core:time"
import raylib "vendor:raylib"

// Time state
Time_State :: struct {
	delta_time:      f32, // Time passed since last frame in seconds
	total_time:      f64, // Total elapsed time in seconds
	frame_count:     u64, // Total frames rendered
	fps:             i32, // Current frames per second
	start_time:      time.Time, // Engine start time
	last_frame_time: time.Time, // Last frame time
}

time_state: Time_State

// Initialize time system
time_init :: proc() {
	log_info(.ENGINE, "Initializing time system")

	time_state.delta_time = 1.0 / 60.0 // Set initial delta time
	time_state.total_time = 0.0
	time_state.frame_count = 0
	time_state.fps = 0
	time_state.start_time = time.now()
	time_state.last_frame_time = time_state.start_time
}

// Update time every frame
time_update :: proc() {
	current_time := time.now()
	delta := time.diff(time_state.last_frame_time, current_time)
	time_state.delta_time = f32(time.duration_seconds(delta))
	time_state.last_frame_time = current_time

	time_state.total_time += f64(time_state.delta_time)
	time_state.frame_count += 1
	time_state.fps = raylib.GetFPS()
}

// Get delta time (time between frames) in seconds
get_delta_time :: proc() -> f32 {
	return time_state.delta_time
}

// Get total elapsed time in seconds
get_total_time :: proc() -> f64 {
	return time_state.total_time
}

// Get elapsed time since engine start in seconds
get_elapsed_time :: proc() -> f64 {
	return time.duration_seconds(time.diff(time_state.start_time, time.now()))
}

// Get current FPS
get_fps :: proc() -> i32 {
	return time_state.fps
}

// Get total frames rendered
get_frame_count :: proc() -> u64 {
	return time_state.frame_count
}

// Shutdown time system
time_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down time system")
}
