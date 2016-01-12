import kratos.ecs;
import kratos.component.transform;
import kratos.component.meshrenderer;
import kratos.component.camera;
import kratos.graphics.texture;
import kratos.resource.loader.textureloader;
import kratos.component.time;
import kgl3n;

class TerrainTile : Component
{
	string textureName;

	private
	{
		@dependency
		{
			Transform transform;
			MeshRenderer meshRenderer;
			CameraSelection cameraSelection;
		}

		enum textureUniformName = "texture";
		Texture unloadedReplacement;
		float loadDistance = 1024 * 4;
		float unloadDistance = 1024 * 5;
		bool loaded;
	}

	void initialize()
	{
		unloadedReplacement = meshRenderer.mesh.renderState.shader.uniforms.getTexture(textureUniformName);
	}

	void frameUpdate()
	{
		auto distance = (cameraSelection.mainCamera.transform.position.xz - transform.position.xz).magnitude;

		if(!loaded && distance <= loadDistance)
		{
			meshRenderer.mesh.renderState.shader.uniforms[textureUniformName] = loadTexture(textureName);
			loaded = true;
		}
		else if(loaded && distance > unloadDistance)
		{
			meshRenderer.mesh.renderState.shader.uniforms[textureUniformName] = unloadedReplacement;
			loaded = false;
		}
	}
}

class CameraMovement : Component
{
	@optional:
	float mouseSensitivity = .002f;
	float baseSpeed = 1;
	float minSpeed = 0.5f;
	float maxSpeed = 1000;
	vec3 speedMultiplier = vec3(0, 0.5, 0);
	vec3 ypr;
	
	private @dependency(Dependency.Direction.Write) Transform transform;
	private @dependency Time time;

	void frameUpdate()
	{
		import kratos.input;
	
		if(mouse.grabbed)
		{
			ypr.x += -mouse.xAxis.value * mouseSensitivity;
			ypr.y += -mouse.yAxis.value * mouseSensitivity;
			ypr.y = ypr.y.clamp(-PI / 2.5, PI / 2.5);

			transform.rotation = quat.eulerRotation(ypr);
		}
		
		auto effectiveSpeed = (baseSpeed * dot(transform.position, speedMultiplier)).clamp(minSpeed, maxSpeed) * time.delta;
		
		auto forward = ((transform.rotation * vec3(0, 0, -1)) * vec3(1, 0, 1)).normalized * effectiveSpeed;
		auto right = (transform.rotation * vec3(1, 0, 0)) * effectiveSpeed;
		auto up = vec3(0, 1, 0) * effectiveSpeed;

		if(keyboard["W"].pressed)
		{
			transform.position = transform.position + forward;
		}
		if(keyboard["S"].pressed)
		{
			transform.position = transform.position - forward;
		}
		if(keyboard["A"].pressed)
		{
			transform.position = transform.position - right;
		}
		if(keyboard["D"].pressed)
		{
			transform.position = transform.position + right;
		}
		if(keyboard["Q"].pressed)
		{
			transform.position = transform.position + up;
		}
		if(keyboard["Z"].pressed)
		{
			transform.position = transform.position - up;
		}
		
		if(mouse.buttons[0].justReleased)
		{
			mouse.grabbed = !mouse.grabbed;
		}
	}
}

static this()
{
	registerComponent!TerrainTile;
	registerComponent!CameraMovement;
}