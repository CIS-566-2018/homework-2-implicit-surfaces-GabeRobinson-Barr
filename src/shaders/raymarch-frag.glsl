#version 300 es

precision highp float;

float pi = 3.14159;

uniform mat4 u_View;

uniform vec3 u_Eye;

uniform vec3 u_Inputs;

uniform float u_Time;

in vec4 fs_Pos; // Pixel location on the square

out vec4 out_Col;

vec2 rot(vec2 v, float y) { // rotate
	return cos(y) * v + sin(y) * vec2(-v.y, v.x);
}

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float lengthN(vec3 p, float n) { // modified length as described by IQ
	return pow(pow(p.x, n) + pow(p.y, n) + pow(p.z, n), 1.0 / n);
}

float uSDF(float d1, float d2) { // union
	return min(d1,d2);
}

float subSDF(float d1, float d2) { // subtract
	return max(-d1, d2);
}

float interSDF(float d1, float d2) { // intersect
	return max(d1,d2);
}

float sdSphere(vec3 p, float r) {
	return length(p) - r;
}

float sdEllipsoid(vec3 p, vec3 r) {
	return (length(p / r) - 1.0) * min(min(r.x, r.y), r.z);
}

float sdCapCylinder(vec3 p, vec2 h) {
	vec2 d = abs(vec2(length(p.xz), p.y)) - h;
	return min(max(d.x,d.y), 0.0) + length(max(d,0.0));
}

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
	vec3 pa = p - a, ba = b - a;
	float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

float udBox(vec3 p, vec3 b) {
	return length(max(abs(p) - b, 0.0));
}

float udRoundBox(vec3 p, vec3 b, float r) {
	return length(max(abs(p) - b, 0.0)) - r;
}

float sdTorus(vec3 p, vec2 t) {
	vec2 q = vec2(length(p.xz) - t.x, p.y);
	return length(q) - t.y;
}

float sdTorus82(vec3 p, vec2 t) {
	vec3 q = vec3(length(p.xz) - t.x, p.y, 0.0);
	return lengthN(q, 8.0) - t.y;
}

float tapSDF(vec3 p) {
	
	float a = sdCapCylinder(p, vec2(1.25, 2));

	float x = sdEllipsoid(p - vec3(0,2,0), vec3(1.25, 0.5, 1.25));
	float y = sdCapCylinder(p - vec3(0,2.5,0), vec2(1.25, 0.5));
	float b = interSDF(x, y);

	b = smin(a,b, 0.25);

	p -= vec3(0,1,0);

	//p.xy = rot(p.xy, pi/2.f);
	float c = udRoundBox(p, vec3(0.75, 0.375, 3.25), 0.25);

	p.xz = rot(p.xz, pi/2.f);
	float d = udRoundBox(p, vec3(0.75, 0.375, 3.25), 0.25);

	return smin(smin(c, d, 2.f), b, 0.5f);

}

float sinkSDF(vec3 p) {
	// Two sink handles
	float tap1 = tapSDF(p + vec3(10, 0, 0));
	vec3 q = p - vec3(10,0,0);
	float t = abs(fract(u_Time * 0.0002) - 0.5);
	t = clamp(pow(4.0 * t * (1.0 - t), 2.f), 0.0, 0.9) / 0.9;
	q.xz = rot(q.xz, 2.f * pi * t);
	float tap2 = tapSDF(q);
	
	float fBase = sdCapCylinder(p - vec3(0,4,0), vec2(1.5, 8));
	q = p - vec3(0, 12, -8);
	q.xy = rot(q.xy, pi/2.0);
	float fTop = interSDF(sdTorus(q, vec2(8, 1.5)), udBox(p - vec3(0,16.75,-8), vec3(1.5, 4.75, 9.5)));
	q = p - vec3(0,8,-16);
	float fFront = sdCapCylinder(q, vec2(1.5, 4));
	q += vec3(0, 4, 0);
	float fCap = sdTorus82(q, vec2(2.0, 0.5));
	float faucet = min(fBase, min(fTop, smin(fFront, fCap, 2.0)));

	float base = udRoundBox(p + vec3(0,34,0), vec3(12, 30, 2), 2.0);

	return min(base, min(faucet, min(tap1,tap2)));
}
 
float rampSDF(vec3 p) {
	vec3 q = p + vec3(0,25,54);
	q.xy = rot(q.xy, pi/2.0);

	float baseRamp = sdTorus(q, vec2(40, 3));
	float innerRamp = sdTorus(q, vec2(39, 3));
	q = p + vec3(0,64.5,148);
	q.yz = rot(q.yz, pi/2.0);

	float baseRoll = sdCapCylinder(q, vec2(3,100));
	float innerRoll = sdCapCylinder(q - vec3(0,0,1), vec2(3,100.1));

	return min(interSDF(subSDF(innerRamp, baseRamp), udBox(p + vec3(0,46.5,27), vec3(3, 21.5, 21.5))), subSDF(innerRoll, baseRoll));
}

float ballSDF(vec3 p) {
	float sph;
	float t = fract(u_Time * 0.0002);
	if (t <= 0.5) {
		t = pow(4.0 * t * (1.0 - t), 2.0);

		vec3 q = p - vec3(0,4.0 - 3.0 * t,-16);
		sph = sdSphere(q / t, 3.0) * t;
	}
		else {
		t = (t - 0.5) / 2.0;
		t = pow(16.0 * t * (1.0 - t), 2.0);
		
		vec3 q = p - vec3(0,1.0 - 2.9 * t, -16);
		sph = sdSphere(q, 3.0);
	}
	vec3 q = p + vec3(0, 25, 55);
	q.yz = rot(q.yz, -fract(u_Time * 0.0002) * pi / 2.0);
	q = q - vec3(0,0,39);
	float sph2 = sdSphere(q, 3.0);

	q = vec3(p.x, p.y + 64.0, mod(p.z + 85.68 + 61.26 * fract(u_Time * 0.0002), 61.26) - 61.26 * 0.5);
	float rollingBall = 1000.0;
	if (p.z < -52.0 && p.z > -250.0) {
		rollingBall = sdSphere(q,3.0);
	}
	
	//q = p + vec3(0,64,100);
	//q.yz = rot(q.yz, pi/2.0);
	//rollingBall = interSDF(rollingBall, sdCapCylinder(q, vec2(3.0, 110)));

	return min(rollingBall, min(sph, sph2));
}

float portalSDF(vec3 p) {	
	vec3 q = (p + vec3(0, 50, 300));
	float t =    sin((q.z * 0.5) + fract(u_Time * 0.0001) * 2.0 * pi);
	//q = vec3(q.x, q.y, q.z);

	float sph = sdSphere(q, 75.0) + t;
	float box = udBox(q, vec3(80,80,50));


	return interSDF(sph, box);
}

vec2 totalSDF(vec3 p) { // this is where I am setting up the scene

	vec3 q = p - vec3(90,-10,50);
	q.xz = rot(q.xz, pi/2.f);
	q.xy = rot(q.xy, pi/6.f);

	q = mod(q, vec3(100, 0, 0)) - 0.5 * vec3(100, 0, 0);

	float sink = sinkSDF(q / 0.5) * 0.5;
	float ramp = rampSDF(q / 0.5) * 0.5;
	float ball = ballSDF(q / 0.5) * 0.5;
	float portal = portalSDF(q / 0.5) * 0.5;
 	float m = min(ball, min(sink, min(portal, ramp)));
	float colIdx;

	if (m == sink) {
		colIdx = 1.0;
	}
	else if (m == ramp) {
		colIdx = 2.0;
	}
	else if (m == ball) {
		colIdx = 3.0;
	}
	else if (m == portal) {
		colIdx = 4.0;
	}

	return vec2(m, colIdx);
	 //sphere radius 5
}

vec3 colorize(float index) {
	if (index == 1.0) {
		return vec3(0.8, 0.8, 0.8);
	}
	if (index == 2.0) {
		return vec3(0.2, 0.4, 0.6);
	}
	if (index == 3.0) {
		return vec3(0.8, 0.7, 0.8);
	}
	if (index == 4.0) {
		return vec3(0.96, 0.43, 1.0);
	}
	return vec3(1.f, 1.f, 1.f);
}

void main() {
	
	out_Col = vec4(0.0, 0.0, 0.0, 1.0); // This makes sure if we dont hit anything the color is set to black

	vec3 forward = vec3(u_View * vec4(0,0,1,0));
	vec3 right = vec3(u_View * vec4(1,0,0,0));
	vec3 up = vec3(u_View * vec4(0,1,0,0));
	vec3 eye = vec3(u_View * vec4(0,0,0,1));

	vec3 raydir = normalize(u_Inputs.z * forward + fs_Pos.x * u_Inputs.z * u_Inputs.x * tan(u_Inputs.y / 2.f) * right + fs_Pos.y * u_Inputs.z * tan(u_Inputs.y / 2.f) * up);
	vec3 position = eye; // start at camera origin
	

	float t = 0.f;
	int maxSteps = 100;
	vec2 sdf;
	for(int steps = 0; steps < maxSteps; steps++) { // Cap steps taken
		sdf = totalSDF(position);
		if (t >= 1000.f || sdf.x < 0.001) { // Stop conditions
			break;
		}
		t += sdf.x; // If we didnt hit it yet add dist to the distance gone
		position += raydir * sdf.x; // Add the disance along our ray to get our new position
	}
	
	if (t < 1000.f) {
		vec3 baseCol = colorize(sdf.y);
		vec2 e = vec2(0.001, 0.f); // epsilon value

		// Find the normal of the point we hit
		vec3 norm = vec3(totalSDF(position + e.xyy).x - totalSDF(position - e.xyy).x, totalSDF(position + e.yxy).x - totalSDF(position - e.yxy).x, totalSDF(position + e.yyx).x - totalSDF(position - e.yyx).x) / (2.f * e.x);
		norm = normalize(norm);
		vec3 lDir = normalize(vec3(1,-1,1));
		if (sdf.y == 4.0) {
			if (norm.z == 0.0) {
				out_Col = vec4(baseCol * (abs(fract(u_Time * 0.0002) * 2.0 - 1.0)), 1.0);
			}
			else {
				out_Col = vec4(baseCol * fract(0.1 * t), 1.0);
			}
		}
		else {
			out_Col = vec4(baseCol * (dot(lDir, -norm) + 0.4), 1.0);
		}
	}
	else {
		raydir.yz = rot(raydir.yz, pi/6.f);
		if (raydir.y >= 0.1) {
			out_Col = vec4(raydir.x * 0.5 + 0.5, raydir.y * 0.5 + 0.5, raydir.z, 1.0);
		}
		else if (raydir.y >= -0.1) {
			float y = (raydir.y + 0.1) * 4.0;
			out_Col = vec4(y, y, y, 1.0);
		}
		else {
			float s = mod(totalSDF(eye + totalSDF(eye).x * raydir).x, 2.0);
			out_Col = vec4(vec3(0.7, 0.6, 0.07) * s, 1.0);
		}
	}


	//out_Col = vec4(raydir.z, 0,0, 1.0);
}
