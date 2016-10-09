#version 330

uniform sampler2D texture;
uniform vec3 color;

in vec3 viewNormal;
in vec2 texCoord;

layout(location = 0) out vec4 albedo; // rgb = albedo, a = diffuse level
layout(location = 1) out vec4 normal; // rgb = viewspace normal xyz, a = emission level
layout(location = 2) out vec2 surfaceParameters; // r = specular power / 128, g = specular level

void main()
{
	vec3 albedoSample = texture2D(texture, texCoord).rgb;
	// Dirty little trick to make the specular highlight a bit more interesting without full blown mapping
	float specularLevel = dot(albedoSample, vec3(1)) * 0.125 + 0.125;
	
	albedo = vec4(albedoSample * color, 1);
	normal = vec4(viewNormal * 0.5 + 0.5, 0);
	surfaceParameters = vec2(specularLevel + 0.25, specularLevel);
}