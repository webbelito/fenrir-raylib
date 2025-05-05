package main

import "core:log"
import "core:os"
import "core:strings"
import raylib "vendor:raylib"

main :: proc() {
	// Initialize logging
	log_init()
	defer log_shutdown()

	// Initialize engine
	engine_init()
	defer engine_shutdown()

	// Initialize scene system
	scene_init()
	defer scene_shutdown()

	// Initialize editor (only in debug mode)
	when ODIN_DEBUG {
		editor_init()
	}

	// Create a new scene
	scene_new("Main Scene")

	// Main loop
	for engine_should_run() {
		engine_update()

		// Update editor (only in debug mode)
		when ODIN_DEBUG {
			editor_update()
		}

		// Begin drawing
		raylib.BeginDrawing()

		// Render engine
		engine_render()

		// Render editor (only in debug mode)
		when ODIN_DEBUG {
			editor_render()
		}

		// End drawing
		raylib.EndDrawing()
	}
}
