package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import raylib "vendor:raylib"

// Asset types
Asset_Type :: enum {
	MODEL,
	TEXTURE,
	SHADER,
	MATERIAL,
}

// Asset handle
Asset_Handle :: struct {
	type: Asset_Type,
	id:   u64,
}

// Asset cache entry
Asset_Cache_Entry :: struct {
	handle:    Asset_Handle,
	path:      string,
	ref_count: int,
	last_used: f64,
}

// Asset manager state
Asset_System :: struct {
	// Asset caches
	model_cache:    map[string]^raylib.Model,
	texture_cache:  map[string]raylib.Texture2D,
	shader_cache:   map[string]raylib.Shader,
	material_cache: map[string]raylib.Material,

	// Asset handles
	next_handle_id: u64,
	handles:        map[Asset_Handle]rawptr,

	// Cache entries
	cache_entries:  [dynamic]Asset_Cache_Entry,
}

// Global asset manager instance
asset_system: Asset_System

// Initialize the asset manager
asset_manager_init :: proc() {
	log_info(.ENGINE, "Initializing asset manager")

	// Initialize caches
	asset_system.model_cache = make(map[string]^raylib.Model)
	asset_system.texture_cache = make(map[string]raylib.Texture2D)
	asset_system.shader_cache = make(map[string]raylib.Shader)
	asset_system.material_cache = make(map[string]raylib.Material)

	// Initialize handles
	asset_system.next_handle_id = 1
	asset_system.handles = make(map[Asset_Handle]rawptr)

	// Initialize cache entries
	asset_system.cache_entries = make([dynamic]Asset_Cache_Entry)
}

// Shutdown the asset manager
asset_manager_shutdown :: proc() {
	log_info(.ENGINE, "Shutting down asset manager")

	// Unload all assets
	for path, model in asset_system.model_cache {
		raylib.UnloadModel(model^)
		free(model)
	}
	delete(asset_system.model_cache)

	for path, texture in asset_system.texture_cache {
		raylib.UnloadTexture(texture)
	}
	delete(asset_system.texture_cache)

	for path, shader in asset_system.shader_cache {
		raylib.UnloadShader(shader)
	}
	delete(asset_system.shader_cache)

	delete(asset_system.material_cache)
	delete(asset_system.handles)
	delete(asset_system.cache_entries)
}

// Load a model from file
load_model :: proc(path: string) -> ^raylib.Model {
	// Check cache first
	if model, exists := asset_system.model_cache[path]; exists {
		log_info(.ENGINE, "Model loaded from cache: %s", path)
		return model
	}

	// Load model
	model := new(raylib.Model)
	model^ = raylib.LoadModel(strings.clone_to_cstring(path))
	if model.meshCount == 0 {
		log_error(.ENGINE, "Failed to load model: %s", path)
		free(model)
		return nil
	}

	// Add to cache
	asset_system.model_cache[path] = model

	// Log model info
	log_info(.ENGINE, "Model loaded: %s", path)
	log_info(.ENGINE, "  - Meshes: %d", model.meshCount)
	log_info(.ENGINE, "  - Materials: %d", model.materialCount)
	log_info(.ENGINE, "  - Bones: %d", model.boneCount)

	return model
}

// Load a texture from file
load_texture :: proc(path: string) -> raylib.Texture2D {
	// Check cache first
	if texture, exists := asset_system.texture_cache[path]; exists {
		log_info(.ENGINE, "Texture loaded from cache: %s", path)
		return texture
	}

	// Load texture
	texture := raylib.LoadTexture(strings.clone_to_cstring(path))
	if texture.id == 0 {
		log_error(.ENGINE, "Failed to load texture: %s", path)
		return texture
	}

	// Add to cache
	asset_system.texture_cache[path] = texture

	log_info(.ENGINE, "Texture loaded: %s", path)
	log_info(.ENGINE, "  - Width: %d", texture.width)
	log_info(.ENGINE, "  - Height: %d", texture.height)
	log_info(.ENGINE, "  - Format: %d", texture.format)

	return texture
}

// Load a shader from files
load_shader :: proc(vs_path, fs_path: string) -> raylib.Shader {
	// Check cache first
	cache_key := fmt.tprintf("%s|%s", vs_path, fs_path)
	if shader, exists := asset_system.shader_cache[cache_key]; exists {
		log_info(.ENGINE, "Shader loaded from cache: %s", cache_key)
		return shader
	}

	// Load shader
	shader := raylib.LoadShader(
		strings.clone_to_cstring(vs_path),
		strings.clone_to_cstring(fs_path),
	)
	if shader.id == 0 {
		log_error(.ENGINE, "Failed to load shader: %s", cache_key)
		return shader
	}

	// Add to cache
	asset_system.shader_cache[cache_key] = shader

	log_info(.ENGINE, "Shader loaded: %s", cache_key)
	return shader
}

// Create a material
create_material :: proc(shader: raylib.Shader, texture: raylib.Texture2D) -> raylib.Material {
	material := raylib.LoadMaterialDefault()
	material.shader = shader
	material.maps[0].texture = texture
	material.maps[0].color = raylib.WHITE
	material.maps[0].value = 1.0
	return material
}

// Unload a model
unload_model :: proc(path: string) {
	if model, exists := asset_system.model_cache[path]; exists {
		raylib.UnloadModel(model^)
		free(model)
		delete_key(&asset_system.model_cache, path)
		log_info(.ENGINE, "Model unloaded: %s", path)
	}
}

// Unload a texture
unload_texture :: proc(path: string) {
	if texture, exists := asset_system.texture_cache[path]; exists {
		raylib.UnloadTexture(texture)
		delete_key(&asset_system.texture_cache, path)
		log_info(.ENGINE, "Texture unloaded: %s", path)
	}
}

// Unload a shader
unload_shader :: proc(vs_path, fs_path: string) {
	cache_key := fmt.tprintf("%s|%s", vs_path, fs_path)
	if shader, exists := asset_system.shader_cache[cache_key]; exists {
		raylib.UnloadShader(shader)
		delete_key(&asset_system.shader_cache, cache_key)
		log_info(.ENGINE, "Shader unloaded: %s", cache_key)
	}
}

// Get a model from cache
get_model :: proc(path: string) -> ^raylib.Model {
	if model, exists := asset_system.model_cache[path]; exists {
		return model
	}
	return nil
}

// Get a texture from cache
get_texture :: proc(path: string) -> raylib.Texture2D {
	if texture, exists := asset_system.texture_cache[path]; exists {
		return texture
	}
	return raylib.Texture2D{}
}

// Get a shader from cache
get_shader :: proc(vs_path, fs_path: string) -> raylib.Shader {
	cache_key := fmt.tprintf("%s|%s", vs_path, fs_path)
	if shader, exists := asset_system.shader_cache[cache_key]; exists {
		return shader
	}
	return raylib.Shader{}
}
