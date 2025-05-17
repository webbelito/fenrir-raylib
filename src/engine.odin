#+feature dynamic-literals

package main

import "base:runtime"

import imgui_rl "../vendor/imgui_impl_raylib"
import imgui "../vendor/odin-imgui"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import raylib "vendor:raylib"


// Engine Configuration
Engine_Config :: struct {
	app_name:            string,
	window_width:        i32,
	window_height:       i32,
	target_fps:          i32,
	vsync:               bool,
	fullscreen:          bool,
	disable_escape_quit: bool,
	default_context:     runtime.Context,
}

// Engine state
Engine_State :: struct {
	initialized:               bool,
	running:                   bool,
	playing:                   bool, // true = play mode, false = editor mode
	time:                      Time_State,
	config:                    Engine_Config,
	editor_camera:             raylib.Camera3D,
	game_camera:               raylib.Camera3D,
	needs_initial_dock_layout: bool,
	editor_visible:            bool, // Controls if editor UI is visible
}

// Global engine state
engine: Engine_State

// Mesh structure
Mesh :: struct {
	vertices:  [dynamic]raylib.Vector3,
	texcoords: [dynamic]raylib.Vector2,
	normals:   [dynamic]raylib.Vector3,
	indices:   [dynamic]i32,
}

// Material structure
Material :: struct {
	texture: raylib.Texture2D,
	shader:  raylib.Shader,
}

// Model structure
Model :: struct {
	model:   raylib.Model,
	texture: raylib.Texture2D,
}

// Asset manager
Asset_Manager :: struct {
	models:   map[string]Model,
	textures: map[string]raylib.Texture2D,
}

asset_manager: Asset_Manager

// Model loading configuration
Model_Config :: struct {
	texture_paths: [dynamic]string, // Ordered list of texture paths to try
	default_color: raylib.Color, // Default material color
	default_value: f32, // Default material value
}

// Default model configuration
DEFAULT_MODEL_CONFIG := Model_Config {
	texture_paths = {
		"assets/meshes/Textures/colormap.png", // GLB's expected path
		"assets/textures/colormap.png", // Fallback path
	},
	default_color = raylib.WHITE,
	default_value = 1.0,
}

// Create a default material with the given texture
create_default_material :: proc(
	texture: raylib.Texture2D,
	config: ^Model_Config,
) -> ^raylib.Material {
	material := new(raylib.Material)
	material^ = raylib.Material{}
	material.maps[0].texture = texture
	material.maps[0].color = config.default_color
	material.maps[0].value = config.default_value
	return material
}

// Try to load a texture from multiple possible paths
load_texture_from_paths :: proc(paths: []string) -> raylib.Texture2D {
	for path in paths {
		texture := load_texture(path)
		if texture.id != 0 {
			log_info(.ENGINE, "Loaded texture from: %s", path)
			return texture
		}
		log_warning(.ENGINE, "Failed to load texture from: %s", path)
	}
	return {}
}

// Setup materials for a model
setup_model_materials :: proc(model: ^Model, config: ^Model_Config) {
	if model.model.materialCount == 0 {
		log_warning(.ENGINE, "Model has no materials, creating default material")
		texture := load_texture_from_paths(config.texture_paths[:])
		if texture.id == 0 {
			log_error(.ENGINE, "Failed to load default texture")
			return
		}
		model.model.materials = create_default_material(texture, config)
		model.model.materialCount = 1
		return
	}

	// Setup existing materials
	for i in 0 ..< model.model.materialCount {
		material := &model.model.materials[i]

		if material.maps[0].texture.id == 0 {
			texture := load_texture_from_paths(config.texture_paths[:])
			if texture.id != 0 {
				material.maps[0].texture = texture
				material.maps[0].color = config.default_color
				material.maps[0].value = config.default_value
				log_info(.ENGINE, "Applied texture to material %d", i)
			} else {
				log_error(.ENGINE, "Failed to load texture for material %d", i)
			}
		} else {
			log_info(.ENGINE, "Material %d already has a texture", i)
		}
	}
}

// Initialize the engine
engine_init :: proc(config: Engine_Config) -> bool {
	if engine.initialized {
		log_warning(.ENGINE, "Engine already initialized")
		return true
	}

	log_info(.ENGINE, "Initializing engine...")

	// Save the config
	engine.config = config

	// Initialize cameras
	engine.editor_camera = raylib.Camera3D {
		position   = {10.0, 10.0, 10.0},
		target     = {0.0, 0.0, 0.0},
		up         = {0.0, 1.0, 0.0},
		fovy       = 45.0,
		projection = .PERSPECTIVE,
	}

	engine.game_camera = engine.editor_camera

	// Initialize the ECS registry
	ecs_init()

	// Initialize the ECS world
	world_init()

	// Initialize the command manager
	command_manager_init()

	// Initialize the asset manager
	asset_manager_init()

	// Initialize the scene manager
	scene_manager_init()

	// Initialize the editor
	editor_init()

	// Initialize ImGui
	if !imgui_init() {
		log_error(.ENGINE, "Failed to initialize ImGui")
		return false
	}

	engine.initialized = true
	engine.running = true
	engine.playing = false
	engine.editor_visible = true

	log_info(.ENGINE, "Engine initialized successfully")
	return true
}

// Shutdown the engine
engine_shutdown :: proc() {
	if !engine.initialized {
		log_warning(.ENGINE, "Engine not initialized")
		return
	}

	log_info(.ENGINE, "Shutting down engine")

	// Shutdown ImGui
	imgui_shutdown()

	// Shutdown ECS world
	world_destroy()

	// Shutdown command manager
	command_manager_shutdown()

	// Shutdown asset manager
	asset_manager_shutdown()

	// Shutdown scene manager
	scene_manager_shutdown()

	// Shutdown ECS registry
	ecs_destroy()

	engine.initialized = false
	engine.running = false
	engine.playing = false

	log_info(.ENGINE, "Engine shutdown complete")
}

// Update the engine
engine_update :: proc() {
	if !engine.initialized {
		return
	}

	// Update time first
	time_update()

	// Begin ImGui frame
	imgui_begin_frame()

	// Handle F1 key to toggle play/editor mode
	if raylib.IsKeyPressed(.F1) {
		engine.playing = !engine.playing
		engine.editor_visible = !engine.playing

		if engine.playing {
			// Entering play mode
			log_info(.ENGINE, "Entering play mode")
			// Store editor camera state
			engine.game_camera = engine.editor_camera
		} else {
			// Entering editor mode
			log_info(.ENGINE, "Entering editor mode")
			// Restore editor camera state
			engine.editor_camera = engine.game_camera
		}
	}

	// Handle camera movement based on mode
	if !imgui.IsAnyItemActive() {
		if !engine.playing {
			// Editor camera controls
			if raylib.IsKeyDown(.W) {
				engine.editor_camera.position += raylib.Vector3{0, 0, -0.1}
				engine.editor_camera.target += raylib.Vector3{0, 0, -0.1}
			}
			if raylib.IsKeyDown(.S) {
				engine.editor_camera.position += raylib.Vector3{0, 0, 0.1}
				engine.editor_camera.target += raylib.Vector3{0, 0, 0.1}
			}
			if raylib.IsKeyDown(.A) {
				engine.editor_camera.position += raylib.Vector3{-0.1, 0, 0}
				engine.editor_camera.target += raylib.Vector3{-0.1, 0, 0}
			}
			if raylib.IsKeyDown(.D) {
				engine.editor_camera.position += raylib.Vector3{0.1, 0, 0}
				engine.editor_camera.target += raylib.Vector3{0.1, 0, 0}
			}
			if raylib.IsKeyDown(.Q) {
				engine.editor_camera.position += raylib.Vector3{0, 0.1, 0}
				engine.editor_camera.target += raylib.Vector3{0, 0.1, 0}
			}
			if raylib.IsKeyDown(.E) {
				engine.editor_camera.position += raylib.Vector3{0, -0.1, 0}
				engine.editor_camera.target += raylib.Vector3{0, -0.1, 0}
			}
		} else {
			// Game camera controls
			if raylib.IsKeyDown(.W) {
				engine.game_camera.position += raylib.Vector3{0, 0, -0.1}
				engine.game_camera.target += raylib.Vector3{0, 0, -0.1}
			}
			if raylib.IsKeyDown(.S) {
				engine.game_camera.position += raylib.Vector3{0, 0, 0.1}
				engine.game_camera.target += raylib.Vector3{0, 0, 0.1}
			}
			if raylib.IsKeyDown(.A) {
				engine.game_camera.position += raylib.Vector3{-0.1, 0, 0}
				engine.game_camera.target += raylib.Vector3{-0.1, 0, 0}
			}
			if raylib.IsKeyDown(.D) {
				engine.game_camera.position += raylib.Vector3{0.1, 0, 0}
				engine.game_camera.target += raylib.Vector3{0.1, 0, 0}
			}
			if raylib.IsKeyDown(.Q) {
				engine.game_camera.position += raylib.Vector3{0, 0.1, 0}
				engine.game_camera.target += raylib.Vector3{0, 0.1, 0}
			}
			if raylib.IsKeyDown(.E) {
				engine.game_camera.position += raylib.Vector3{0, -0.1, 0}
				engine.game_camera.target += raylib.Vector3{0, -0.1, 0}
			}
		}
	}

	// Update game systems
	if engine.playing {
		// Update the ECS world
		dt := raylib.GetFrameTime()
		world_update(dt)
	}

	// Update editor systems
	if !engine.playing && engine.editor_visible {
		// Update editor systems
		editor_update()
	}
}

// Render the engine
engine_render :: proc() {
	if !engine.initialized {
		return
	}

	// Begin rendering
	raylib.BeginDrawing()
	raylib.ClearBackground(raylib.RAYWHITE)

	// Begin 3D mode
	raylib.BeginMode3D(engine.playing ? engine.game_camera : engine.editor_camera)

	// Draw a grid in both modes
	raylib.DrawGrid(10, 1.0)

	// Let the render system handle rendering
	render_system_render(
		&global_world.registry,
		engine.playing ? engine.game_camera : engine.editor_camera,
	)

	// End 3D mode
	raylib.EndMode3D()

	// Render editor UI if in editor mode
	if !engine.playing && engine.editor_visible {
		editor_render()
	}

	// End ImGui frame
	imgui_end_frame()

	// End rendering
	raylib.EndDrawing()
}

// Check if the engine should continue running
engine_should_run :: proc() -> bool {
	return engine.running && !raylib.WindowShouldClose()
}

// Render a model
render_model :: proc(
	model: ^raylib.Model,
	position: raylib.Vector3,
	rotation: raylib.Vector3,
	scale: raylib.Vector3,
) {
	if model == nil {
		return
	}

	// Set up model matrix
	model_matrix :=
		raylib.MatrixRotateXYZ(rotation) *
		raylib.MatrixScale(scale.x, scale.y, scale.z) *
		raylib.MatrixTranslate(position.x, position.y, position.z)

	// Apply model matrix to the model
	model.transform = model_matrix

	// Draw model
	raylib.DrawModel(model^, position, 1.0, raylib.WHITE)
}

// Run the engine main loop
engine_run :: proc() {
	// Main game loop
	for engine_should_run() {
		engine_update()
		engine_render()
	}
}
