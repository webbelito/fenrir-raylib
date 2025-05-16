package main

import imgui "../vendor/odin-imgui"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:strings"
import raylib "vendor:raylib"

// Component inspector functions
transform_render_inspector :: proc(transform: ^Transform) {
	if transform == nil do return
	if imgui.CollapsingHeader("Transform") {
		pos := [3]f32{transform.position.x, transform.position.y, transform.position.z}
		rot := [3]f32{transform.rotation.x, transform.rotation.y, transform.rotation.z}
		scale := [3]f32{transform.scale.x, transform.scale.y, transform.scale.z}
		if imgui.DragFloat3("Position", &pos, 0.1) {
			transform.position = {pos[0], pos[1], pos[2]}
			transform.dirty = true
		}
		if imgui.DragFloat3("Rotation", &rot, 1.0) {
			transform.rotation = {rot[0], rot[1], rot[2]}
			transform.dirty = true
		}
		if imgui.DragFloat3("Scale", &scale, 0.1) {
			transform.scale = {scale[0], scale[1], scale[2]}
			transform.dirty = true
		}
	}
}

renderer_render_inspector :: proc(renderer: ^Renderer) {
	if renderer == nil do return
	if imgui.CollapsingHeader("Renderer") {
		imgui.Checkbox("Visible", &renderer.visible)
		if imgui.BeginCombo("Model Type", renderer.model_type == .CUBE ? "Cube" : "Custom") {
			if imgui.Selectable("Cube", renderer.model_type == .CUBE) {
				renderer.model_type = .CUBE
				renderer.mesh_path = "cube"
				renderer.material_path = "default"
			}
			if imgui.Selectable("Custom", renderer.model_type == .CUSTOM) {
				renderer.model_type = .CUSTOM
			}
			imgui.EndCombo()
		}
		if renderer.model_type == .CUSTOM {
			mesh_buf: [256]u8
			material_buf: [256]u8
			copy(mesh_buf[:], renderer.mesh_path)
			copy(material_buf[:], renderer.material_path)
			if imgui.InputText("Mesh Path", cstring(raw_data(mesh_buf[:])), len(mesh_buf)) {
				renderer.mesh_path = string(mesh_buf[:])
			}
			if imgui.InputText(
				"Material Path",
				cstring(raw_data(material_buf[:])),
				len(material_buf),
			) {
				renderer.material_path = string(material_buf[:])
			}
		}
	}
}

camera_render_inspector :: proc(camera: ^Camera) {
	if camera == nil do return
	if imgui.CollapsingHeader("Camera") {
		imgui.DragFloat("FOV", &camera.fov, 1.0, 1.0, 179.0)
		imgui.DragFloat("Near", &camera.near, 0.1, 0.1, 100.0)
		imgui.DragFloat("Far", &camera.far, 1.0, 1.0, 10000.0)
		imgui.Checkbox("Is Main Camera", &camera.is_main)
	}
}

light_render_inspector :: proc(light: ^Light) {
	if light == nil do return
	if imgui.CollapsingHeader("Light") {
		if imgui.BeginCombo(
			"Light Type",
			light.light_type == .DIRECTIONAL ? "Directional" : "Point",
		) {
			if imgui.Selectable("Directional", light.light_type == .DIRECTIONAL) {
				light.light_type = .DIRECTIONAL
			}
			if imgui.Selectable("Point", light.light_type == .POINT) {
				light.light_type = .POINT
			}
			imgui.EndCombo()
		}
		color := [3]f32{light.color.x, light.color.y, light.color.z}
		if imgui.ColorEdit3("Color", &color) {
			light.color = {color[0], color[1], color[2]}
		}
		imgui.DragFloat("Intensity", &light.intensity, 0.1, 0.0, 10.0)
		if light.light_type == .POINT {
			imgui.DragFloat("Range", &light.range, 0.1, 0.0, 100.0)
		}
	}
}

script_render_inspector :: proc(script: ^Script) {
	if script == nil do return
	if imgui.CollapsingHeader("Script") {
		script_buf: [256]u8
		copy(script_buf[:], script.script_name)
		if imgui.InputText("Script Name", cstring(raw_data(script_buf[:])), len(script_buf)) {
			script.script_name = string(script_buf[:])
		}
	}
}
