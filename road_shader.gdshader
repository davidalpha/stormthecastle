shader_type spatial;

// Height range of the mesh (adjust to match your geometry)
uniform float height_min : hint_range(-10.0, 10.0) = 0.0;
uniform float height_max : hint_range(-10.0, 10.0) = 1.0;

// Threshold for relative height (0.0 = bottom, 1.0 = top)
// Values above this are considered "sides", below are "surface"
uniform float height_threshold : hint_range(0.0, 1.0) = 0.5;

// Colors for testing
uniform vec3 surface_color : source_color = vec3(0.0, 0.0, 1.0); // Blue for road surface (lower)
uniform vec3 side_color : source_color = vec3(1.0, 0.0, 0.0);    // Red for sides (higher)

// Pass vertex height from vertex to fragment shader
varying float vertex_height;

void vertex() {
	// Get the local Y position of the vertex
	vertex_height = VERTEX.y;
}

void fragment() {
	// Calculate relative height (0.0 to 1.0)
	float relative_height = clamp((vertex_height - height_min) / (height_max - height_min), 0.0, 1.0);

	// Color based on height
	if (relative_height > height_threshold) {
		ALBEDO = side_color;  // Higher parts = sides (red)
	} else {
		ALBEDO = surface_color;  // Lower parts = surface (blue)
	}
}
