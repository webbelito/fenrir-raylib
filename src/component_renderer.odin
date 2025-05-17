package main

import "core:strings"
import raylib "vendor:raylib"

// Model types
Model_Type :: enum {
	CUBE,
	SPHERE,
	PLANE,
	AMBULANCE,
	CUSTOM,
}

// Renderer component for visual representation
Renderer :: struct {
	visible:       bool, // Whether the renderer is visible
	model_type:    Model_Type, // Type of model to render
	mesh_path:     string, // Path to mesh resource
	material_path: string, // Path to material resource
	color:         raylib.Color, // Color tint
}

// Create a default renderer
renderer_create :: proc() -> Renderer {
	return Renderer {
		visible = true,
		model_type = .CUBE,
		mesh_path = "",
		material_path = "",
		color = raylib.WHITE,
	}
}

// Create a cube renderer
renderer_create_cube :: proc(color: raylib.Color = raylib.WHITE) -> Renderer {
	return Renderer {
		visible = true,
		model_type = .CUBE,
		mesh_path = "",
		material_path = "",
		color = color,
	}
}

// Create a sphere renderer
renderer_create_sphere :: proc(color: raylib.Color = raylib.WHITE) -> Renderer {
	return Renderer {
		visible = true,
		model_type = .SPHERE,
		mesh_path = "",
		material_path = "",
		color = color,
	}
}

// Create a plane renderer
renderer_create_plane :: proc(color: raylib.Color = raylib.WHITE) -> Renderer {
	return Renderer {
		visible = true,
		model_type = .PLANE,
		mesh_path = "",
		material_path = "",
		color = color,
	}
}

// Create a custom model renderer
renderer_create_custom :: proc(
	mesh_path: string,
	material_path: string,
	color: raylib.Color = raylib.WHITE,
) -> Renderer {
	return Renderer {
		visible = true,
		model_type = .CUSTOM,
		mesh_path = strings.clone(mesh_path),
		material_path = strings.clone(material_path),
		color = color,
	}
}

// Set renderer visibility
renderer_set_visible :: proc(renderer: ^Renderer, visible: bool) {
	renderer.visible = visible
}

// Set renderer color
renderer_set_color :: proc(renderer: ^Renderer, color: raylib.Color) {
	renderer.color = color
}

// Set renderer mesh
renderer_set_mesh :: proc(renderer: ^Renderer, mesh_path: string) {
	if renderer.mesh_path != "" {
		delete(renderer.mesh_path)
	}
	renderer.mesh_path = strings.clone(mesh_path)

	// If changing mesh, ensure we're using CUSTOM model type
	if renderer.model_type != .CUSTOM {
		renderer.model_type = .CUSTOM
	}
}

// Set renderer material
renderer_set_material :: proc(renderer: ^Renderer, material_path: string) {
	if renderer.material_path != "" {
		delete(renderer.material_path)
	}
	renderer.material_path = strings.clone(material_path)
}

// Clean up renderer resources
renderer_destroy :: proc(renderer: ^Renderer) {
	if renderer.mesh_path != "" {
		delete(renderer.mesh_path)
	}
	if renderer.material_path != "" {
		delete(renderer.material_path)
	}
}
