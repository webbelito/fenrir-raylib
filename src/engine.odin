#+feature dynamic-literals

package main

import "base:runtime"

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
	initialized: bool,
	running:     bool,
	camera:      raylib.Camera3D,
	time:        Time_State,
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
engine_init :: proc() {
	if engine.initialized {
		log_warning(.ENGINE, "Engine already initialized")
		return
	}

	log_info(.ENGINE, "Initializing engine")

	// Initialize asset manager
	asset_manager_init()

	// Initialize window
	raylib.InitWindow(1280, 720, "Fenrir Engine")
	raylib.SetTargetFPS(60)

	// Initialize camera
	engine.camera = raylib.Camera3D {
		position   = {0, 5, -10},
		target     = {0, 0, 0},
		up         = {0, 1, 0},
		fovy       = 45,
		projection = .PERSPECTIVE,
	}

	// Initialize time
	time_init()

	engine.initialized = true
	engine.running = true

	log_info(.ENGINE, "Engine initialized successfully")
}

// Shutdown the engine
engine_shutdown :: proc() {
	if !engine.initialized {
		log_warning(.ENGINE, "Engine not initialized")
		return
	}

	log_info(.ENGINE, "Shutting down engine")

	// Shutdown asset manager
	asset_manager_shutdown()

	// Close window
	raylib.CloseWindow()

	engine.initialized = false
	engine.running = false

	log_info(.ENGINE, "Engine shut down successfully")
}

// Update the engine
engine_update :: proc() {
	if !engine.initialized || !engine.running {
		return
	}

	// Update time
	time_update()

	// Update camera
	if raylib.IsKeyDown(.W) {
		engine.camera.position.z += 0.1
	}
	if raylib.IsKeyDown(.S) {
		engine.camera.position.z -= 0.1
	}
	if raylib.IsKeyDown(.A) {
		engine.camera.position.x -= 0.1
	}
	if raylib.IsKeyDown(.D) {
		engine.camera.position.x += 0.1
	}
	if raylib.IsKeyDown(.SPACE) {
		engine.camera.position.y += 0.1
	}
	if raylib.IsKeyDown(.LEFT_CONTROL) {
		engine.camera.position.y -= 0.1
	}
}

// Render the engine
engine_render :: proc() {
	if !engine.initialized || !engine.running {
		return
	}

	raylib.ClearBackground(raylib.BLACK)

	// Get the main camera
	main_camera := scene_get_main_camera()
	if main_camera == 0 {
		log_warning(.ENGINE, "No main camera found")
		return
	}

	// Get camera component
	camera := ecs_get_camera(main_camera)
	if camera == nil {
		log_warning(.ENGINE, "Main camera has no camera component")
		return
	}

	// Get camera transform
	camera_transform := ecs_get_transform(main_camera)
	if camera_transform == nil {
		log_warning(.ENGINE, "Main camera has no transform component")
		return
	}

	// Update engine camera with scene camera
	engine.camera.position = camera_transform.position
	engine.camera.target = camera_transform.position + raylib.Vector3{0, 0, 1} // Look forward
	engine.camera.up = {0, 1, 0}
	engine.camera.fovy = camera.fov
	engine.camera.projection = .PERSPECTIVE

	raylib.BeginMode3D(engine.camera)

	// Draw grid
	raylib.DrawGrid(20, 1.0)

	// Draw coordinate axes
	raylib.DrawLine3D({0, 0, 0}, {10, 0, 0}, raylib.RED) // X axis
	raylib.DrawLine3D({0, 0, 0}, {0, 10, 0}, raylib.GREEN) // Y axis
	raylib.DrawLine3D({0, 0, 0}, {0, 0, 10}, raylib.BLUE) // Z axis

	// Render scene entities
	if scene_is_loaded() {
		entities := scene_get_entities()
		defer delete(entities)

		for entity in entities {
			// Get renderer component
			renderer := ecs_get_renderer(entity)
			if renderer == nil || !renderer.enabled || !renderer.visible {
				continue
			}

			// Get transform component
			transform := ecs_get_transform(entity)
			if transform == nil || !transform.enabled {
				continue
			}

			// Load model if needed
			model := get_model(renderer.mesh)
			if model == nil {
				continue
			}

			// Render model
			render_model(model, transform.position, transform.rotation, transform.scale)
		}
	}

	raylib.EndMode3D()

	// Draw FPS
	raylib.DrawFPS(10, 10)
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
