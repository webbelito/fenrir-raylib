package main

import raylib "vendor:raylib"

// Light types
Light_Type :: enum {
	DIRECTIONAL,
	POINT,
	SPOT,
}

// Light component for scene lighting
Light :: struct {
	light_type: Light_Type, // Type of light
	color:      raylib.Vector3, // Light color (RGB, each channel 0-1)
	intensity:  f32, // Light intensity multiplier
	range:      f32, // Range of point/spot lights
	spot_angle: f32, // Spot light cone angle (degrees)
}

// Create a default directional light
light_create_directional :: proc(
	color: raylib.Vector3 = {1, 1, 1},
	intensity: f32 = 1.0,
) -> Light {
	return Light {
		light_type = .DIRECTIONAL,
		color = color,
		intensity = intensity,
		range = 0,
		spot_angle = 0,
	}
}

// Create a point light
light_create_point :: proc(
	color: raylib.Vector3 = {1, 1, 1},
	intensity: f32 = 1.0,
	range: f32 = 10.0,
) -> Light {
	return Light {
		light_type = .POINT,
		color = color,
		intensity = intensity,
		range = range,
		spot_angle = 0,
	}
}

// Create a spot light
light_create_spot :: proc(
	color: raylib.Vector3 = {1, 1, 1},
	intensity: f32 = 1.0,
	range: f32 = 10.0,
	spot_angle: f32 = 45.0,
) -> Light {
	return Light {
		light_type = .SPOT,
		color = color,
		intensity = intensity,
		range = range,
		spot_angle = spot_angle,
	}
}

// Set light color
light_set_color :: proc(light: ^Light, color: raylib.Vector3) {
	light.color = color
}

// Set light intensity
light_set_intensity :: proc(light: ^Light, intensity: f32) {
	light.intensity = intensity
}

// Set light range
light_set_range :: proc(light: ^Light, range: f32) {
	// Only applicable to point and spot lights
	if light.light_type != .DIRECTIONAL {
		light.range = range
	}
}

// Set spot light angle
light_set_spot_angle :: proc(light: ^Light, angle: f32) {
	// Only applicable to spot lights
	if light.light_type == .SPOT {
		light.spot_angle = angle
	}
}
