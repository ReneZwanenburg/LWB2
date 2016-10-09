#version 330

uniform sampler2D texture;
uniform vec3 color;

in vec2 texCoord;

layout(location = 0) out vec4 albedo; // rgb = albedo, a = diffuse level
layout(location = 1) out vec4 normal; // rgb = viewspace normal xyz, a = emission level
layout(location = 2) out vec2 surfaceParameters; // r = specular power / 128, g = specular level

void main()
{
	float alpha = texture2D(texture, texCoord).a;
	
	if(alpha < 0.5) discard;
	
	albedo = vec4(color, 0);
	normal = vec4(0, 0, 0, 1);
	surfaceParameters = vec2(0, 0);
}