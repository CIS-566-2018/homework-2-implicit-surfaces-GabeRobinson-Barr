#version 300 es

precision highp float;

in vec4 fs_Pos; // Pixel location on the square

out vec4 out_Col;

float sdSphere(vec3 p, float r) {
	return length(p) - r;
}

float udBox(vec3 p, vec3 b) {
	return length(max(abs(p) - b, 0.0));
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

void main() {
	// TODO: make a Raymarcher!
	out_Col = vec4(0.0, 0.0, 0.0, 1.0);

	vec3 raydir = normalize(vec3(fs_Pos.x, fs_Pos.y, 1) * 1000.f); // Get the ray direction through this Pixel
	vec3 position = vec3(0,0,0); // camera origin

	vec3 spherePos = vec3(0, 0, 20); // For now skip transformations and center a sphere at 0, 0, 20

	position -= spherePos;

	float t = 0.f;
	int steps = 0;
	while(t < 1000.f && steps < 20) { // Cap ray distance at 1000 and steps taken at 20
		float dist = sdSphere(position, 5.f); //sphere radius 5
		if (dist < 0.01f) {
			out_Col = vec4(normalize(position - spherePos), 1.0);
			break;
		}
		t += dist; // If we didnt hit it yet add dist to the distance gone
		position += raydir * dist; // Add the disance along our ray to get our new position
	}


	//out_Col = vec4(raydir, 1.0);
}
