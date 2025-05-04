package main

import "core:time"

// Time information structure
Time_Info :: struct {
    last_update_time: time.Time,
    delta_time:      f32,  // Delta time in seconds
    total_time:      f64,  // Total time in seconds since engine start
    frame_count:     u64,
}

// Global time information
time_info: Time_Info

// Initialize time system
time_init :: proc() -> bool {
    time_info = Time_Info{
        last_update_time = time.now(),
        delta_time = 0.0,
        total_time = 0.0,
        frame_count = 0,
    }
    return true
}

// Update time information
time_update :: proc() {
    current_time := time.now()
    
    // Calculate delta time in seconds
    duration := time.diff(time_info.last_update_time, current_time)
    time_info.delta_time = f32(time.duration_seconds(duration))
    
    // Update total time
    time_info.total_time += f64(time_info.delta_time)
    
    // Update frame count
    time_info.frame_count += 1
    
    // Store current time for next update
    time_info.last_update_time = current_time
}

// Get current delta time
time_get_delta :: proc() -> f32 {
    return time_info.delta_time
}

// Get total time since engine start
time_get_total :: proc() -> f64 {
    return time_info.total_time
}

// Get current frame count
time_get_frame_count :: proc() -> u64 {
    return time_info.frame_count
} 