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
	float sensitivity = .002f;
	float speed = 1;
	float speedMultiplier = 1.5f;
	private @dependency(Dependency.Direction.Write) Transform transform;
	private @dependency Time time;

	vec3 ypr;

	void frameUpdate()
	{
		import kratos.input;
	
		if(mouse.grabbed)
		{
			ypr.x += -mouse.xAxis.value * sensitivity;
			ypr.y += -mouse.yAxis.value * sensitivity;
			ypr.y = ypr.y.clamp(-PI / 2.5, PI / 2.5);

			transform.rotation = quat.eulerRotation(ypr);
		}
		
		auto forward = ((transform.rotation * vec3(0, 0, -1)) * vec3(1, 0, 1)).normalized * speed * time.delta;
		auto right = (transform.rotation * vec3(1, 0, 0)) * speed * time.delta;
		auto up = vec3(0, 1, 0) * speed * time.delta;

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
		if(keyboard["E"].justPressed)
		{
			speed /= speedMultiplier;
		}
		if(keyboard["R"].justPressed)
		{
			speed *= speedMultiplier;
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