package main

import "core:fmt"
import "core:time"
import "core:strings"
import "core:mem"
import "base:runtime"
import "core:path/filepath"
import "core:c"

import rl "vendor:raylib"
import stb "vendor:stb/sprintf"

// Logger holds configuration for the logging system
Logger :: struct {
    ctx: runtime.Context,
    min_level: Log_Level,
    enabled_categories: map[Log_Category]bool,
    use_colors: bool,
    use_multi_line: bool,
    show_source_loc: bool,
}

// Log levels for message priorities
Log_Level :: enum {
    VERBOSE,
    DEBUG,
    INFO,
    WARNING,
    ERROR,
    CRITICAL,
}

// Log categories for different parts of the engine
Log_Category :: enum {
    APP,      // Application-specific logs
    ENGINE,   // Engine core functionality
    RENDERER, // Rendering system
    AUDIO,    // Audio system
    INPUT,    // Input system
    PHYSICS,  // Physics system
    SCRIPT,   // Scripting system
    EDITOR,   // Editor-specific logs
    GAME,     // Game-specific logs
    BUILD,    // Build system logs
    RAYLIB,   // Raylib logs
}

// Global default logger
log_default_logger: Logger

// Initialize the logging system
log_init :: proc() {
    log_default_logger.ctx = runtime.default_context()
    log_default_logger.min_level = .DEBUG
    log_default_logger.use_colors = true
    log_default_logger.use_multi_line = true
    log_default_logger.show_source_loc = true
    
    log_default_logger.enabled_categories = make(map[Log_Category]bool)
    for i in Log_Category {
        log_default_logger.enabled_categories[i] = true
    }

    rl.SetTraceLogCallback(log_rl)
}

// Shutdown logging and free resources
log_shutdown :: proc() {
    delete(log_default_logger.enabled_categories)
}

// Get formatted timestamp string (YYYY-MM-DD HH:MM:SS.mmm)
log_get_timestamp :: proc() -> string {
    now := time.now()
    year, month, day := time.date(now)
    hour, min, sec, nano := time.precise_clock_from_time(now)
    milliseconds := nano / 1_000_000
    
    return fmt.tprintf("%04d-%02d-%02d %02d:%02d:%02d.%03d", 
                      year, int(month), day,
                      hour, min, sec, milliseconds)
}

// Get string representation of category
log_category_to_string :: proc(category: Log_Category) -> string {
    #partial switch category {
    case .APP:      return "APP"
    case .ENGINE:   return "ENGINE"
    case .RENDERER: return "RENDER"
    case .AUDIO:    return "AUDIO"
    case .INPUT:    return "INPUT"
    case .PHYSICS:  return "PHYSICS"
    case .SCRIPT:   return "SCRIPT"
    case .EDITOR:   return "EDITOR"
    case .GAME:     return "GAME"
    case .BUILD:    return "BUILD"
    case .RAYLIB:   return "RAYLIB"
    }
    return "UNKNOWN"
}

// Format a source location into a "filename:line:procedure" string
log_format_source_location :: proc(loc: runtime.Source_Code_Location) -> string {
    filename := filepath.base(loc.file_path)
    return fmt.tprintf("%s:%d:%s", filename, loc.line, loc.procedure)
}

// Get string representation and ANSI color codes for a log level
log_level_to_string_and_color :: proc(level: Log_Level, use_colors: bool) -> (string, string, string) {
    level_str := ""
    level_color := ""
    reset_color := use_colors ? "\x1b[0m" : ""
    
    if use_colors {
        #partial switch level {
        case .VERBOSE:
            level_str = "VERBOSE"
            level_color = "\x1b[90m" // Dark gray
        case .DEBUG:
            level_str = "DEBUG"
            level_color = "\x1b[94m" // Blue
        case .INFO:
            level_str = "INFO"
            level_color = "\x1b[92m" // Green
        case .WARNING:
            level_str = "WARNING"
            level_color = "\x1b[93m" // Yellow
        case .ERROR:
            level_str = "ERROR"
            level_color = "\x1b[91m" // Red
        case .CRITICAL:
            level_str = "CRITICAL"
            level_color = "\x1b[97;41m" // White on red background
        }
    } else {
        #partial switch level {
        case .VERBOSE:  level_str = "VERBOSE"
        case .DEBUG:    level_str = "DEBUG"
        case .INFO:     level_str = "INFO"
        case .WARNING:  level_str = "WARNING"
        case .ERROR:    level_str = "ERROR"
        case .CRITICAL: level_str = "CRITICAL"
        }
    }
    
    return level_str, level_color, reset_color
}

// Format a log message with timestamp, category, level, and source location
log_format_message :: proc(
    category: Log_Category, 
    level: Log_Level, 
    message: string, 
    loc: runtime.Source_Code_Location,
    use_colors := true, 
    use_multi_line := true,
    show_source_loc := true,
) -> string {
    time_str := log_get_timestamp()
    cat_str := log_category_to_string(category)
    level_str, level_color, reset_color := log_level_to_string_and_color(level, use_colors)
    
    loc_str := ""
    if show_source_loc {
        loc_str = fmt.tprintf(" (%s)", log_format_source_location(loc))
    }
    
    if use_multi_line {
        // Multi-line format with header and message on separate lines
        header := fmt.tprintf("[%s] [%s] [%s%s%s]%s", 
            cat_str, time_str, level_color, level_str, reset_color, loc_str)
        indent := "    "
        return fmt.tprintf("%s\n%s%s\n\n", header, indent, message)
    } else {
        // Single-line format
        return fmt.tprintf("[%s] [%s] [%s%s%s]%s %s\n\n", 
            cat_str, time_str, level_color, level_str, reset_color, loc_str, message)
    }
}

// Handle Raylib logging - redirects raylib's log messages to our system
log_rl :: proc "c" (logLevel: rl.TraceLogLevel, text: cstring, args: ^c.va_list) {
    context = log_default_logger.ctx
	
	// Map raylib log levels to our levels
	level: Log_Level
	switch logLevel {
	case .TRACE, .DEBUG:     level = .DEBUG
	case .ALL, .NONE, .INFO: level = .INFO
	case .WARNING:           level = .WARNING
	case .ERROR:             level = .ERROR
	case .FATAL:             level = .CRITICAL
	}

	if level < log_default_logger.min_level {
		return
	}

	// Allocate buffer for the formatted message
	buf := make([]byte, 1024)
	defer delete(buf)
	
	// Format the message with variable arguments
	n := stb.vsnprintf(raw_data(buf), i32(len(buf)), text, args)
	
	// If buffer wasn't large enough, resize and try again
	if n >= i32(len(buf)) {
		delete(buf)
		buf = make([]byte, int(n) + 1)
		n = stb.vsnprintf(raw_data(buf), i32(len(buf)), text, args)
	}
	
	// Convert to string and log
	if n > 0 {
		message := string(buf[:n])
		log_log(level, .RAYLIB, message)
	}
}

// Set the minimum level for logging - messages below this level will be ignored
log_set_min_level :: proc(level: Log_Level) {
    log_default_logger.min_level = level
}

// Enable or disable colored output
log_set_use_colors :: proc(use_colors: bool) {
    log_default_logger.use_colors = use_colors
}

// Enable or disable multi-line format
log_set_use_multi_line :: proc(use_multi_line: bool) {
    log_default_logger.use_multi_line = use_multi_line
}

// Enable or disable source location information
log_set_show_source_loc :: proc(show_source_loc: bool) {
    log_default_logger.show_source_loc = show_source_loc
}

// Enable or disable a specific category
log_set_category_enabled :: proc(category: Log_Category, enabled: bool) {
    log_default_logger.enabled_categories[category] = enabled
}

// Core logging function
log_log :: proc(level: Log_Level, category: Log_Category, message: string, args: ..any, loc := #caller_location) {
    if int(level) < int(log_default_logger.min_level) {
        return
    }
    
    if category in log_default_logger.enabled_categories && !log_default_logger.enabled_categories[category] {
        return
    }
    
    // Save current context
    prev_context := context
    
    // Switch to logger context
    context = log_default_logger.ctx
    
    formatted_message := fmt.tprintf(message, ..args)
    fmt_message := log_format_message(
        category, 
        level, 
        formatted_message, 
        loc, 
        log_default_logger.use_colors, 
        log_default_logger.use_multi_line,
        log_default_logger.show_source_loc,
    )
    fmt.eprint(fmt_message)
    
    // Restore context
    context = prev_context
}

// Log functions for each level
log_verbose :: proc(category: Log_Category, message: string, args: ..any) {
    log_log(.VERBOSE, category, message, ..args)
}

log_debug :: proc(category: Log_Category, message: string, args: ..any) {
    log_log(.DEBUG, category, message, ..args)
}

log_info :: proc(category: Log_Category, message: string, args: ..any) {
    log_log(.INFO, category, message, ..args)
}

log_warning :: proc(category: Log_Category, message: string, args: ..any) {
    log_log(.WARNING, category, message, ..args)
}

log_error :: proc(category: Log_Category, message: string, args: ..any) {
    log_log(.ERROR, category, message, ..args)
}

log_critical :: proc(category: Log_Category, message: string, args: ..any) {
    log_log(.CRITICAL, category, message, ..args)
}

// Convenience functions with preset categories
log_app :: proc(message: string, args: ..any) {
    log_log(.INFO, .APP, message, ..args)
}

log_core :: proc(message: string, args: ..any) {
    log_log(.INFO, .ENGINE, message, ..args)
}

log_renderer :: proc(message: string, args: ..any) {
    log_log(.INFO, .RENDERER, message, ..args)
}

log_game :: proc(message: string, args: ..any) {
    log_log(.INFO, .GAME, message, ..args)
}

// Shorthand error loggers
log_app_error :: proc(message: string, args: ..any) {
    log_log(.ERROR, .APP, message, ..args)
}

log_core_error :: proc(message: string, args: ..any) {
    log_log(.ERROR, .ENGINE, message, ..args)
}

log_build_error :: proc(message: string, args: ..any) {
    log_log(.ERROR, .BUILD, message, ..args)
}

log_build_warning :: proc(message: string, args: ..any) {
    log_log(.WARNING, .BUILD, message, ..args)
}

// Build logging functions
log_build_info :: proc(message: string, args: ..any) {
    log_log(.INFO, .BUILD, message, ..args)
}

log_build_debug :: proc(message: string, args: ..any) {
    log_log(.DEBUG, .BUILD, message, ..args)
}

log_build_warn :: proc(message: string, args: ..any) {
    log_log(.WARNING, .BUILD, message, ..args)
}