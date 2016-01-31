import kratos.ecs;
import kratos.component.transform;
import kratos.component.meshrenderer;
import kratos.component.camera;
import kratos.graphics.texture;
import kratos.resource.loader.textureloader;
import kratos.component.time;
import kgl3n;
import kgl3n.math : smoothStep;
import std.algorithm.comparison : max;
import std.math;
import std.conv;

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
		
		uint currentLevel = -1;
	}

	void frameUpdate()
	{
		auto distance = (cameraSelection.mainCamera.transform.worldPosition - transform.worldPosition).magnitude;
		auto lod = (distance / 1024).max(0).log2.max(0).to!uint;
		
		if(currentLevel != lod)
		{
			meshRenderer.mesh.renderState.shader.uniforms[textureUniformName] = loadTexture(textureName, lod);
			currentLevel = lod;
		}
	}
}

class CameraAnchor : Component
{
	@optional:

	private @dependency(Dependency.Direction.Write) Transform transform;
	private @dependency Time time;
	private @dependency CameraSelection cameraSelection;
	
	vec3 ypr = vec3(0, 0, 0);
	float mouseRotateSensitivity = 0.005;
	float mouseMoveSensitivity = 0.005;
	
	float speedMaxDist = 250;
	float maxSpeed = 1000;
	
	void initialize()
	{
		cameraSelection.mainCamera.transform.parent = transform;
	}

	void frameUpdate()
	{
		import kratos.input;

		if(mouse.buttons[1].pressed)
		{
			ypr.x = (ypr.x + -mouse.xAxis.value * mouseRotateSensitivity) % (PI * 2);
			ypr.y = (ypr.y + -mouse.yAxis.value * mouseRotateSensitivity) % (PI * 2);
		}

		transform.rotation = quat.eulerRotation(ypr);

		if(mouse.buttons[0].pressed)
		{
			auto forward = ((transform.rotation * vec3(0, 0, -1)) * vec3(1, 0, 1)).normalized;
			auto right = ((transform.rotation * vec3(1, 0, 0)) * vec3(1, 0, 1)).normalized;
			
			transform.position += 
				(forward * mouse.yAxis.value + right * -mouse.xAxis.value) * 
				cameraSelection.mainCamera.transform.position.z *
				mouseMoveSensitivity;
		}
	}
}

class CameraMovement : Component
{
	@optional:
	float distanceScale = 1.25;

	private Transformation startTransformation;
	private Transformation targetTransformation;
	
	private @dependency(Dependency.Direction.Write) Transform transform;
	private @dependency Time time;

	private float interpTimeRemaining = 0;
	private float interpTime = 0.33;

	void initialize()
	{
		targetTransformation = transform.localTransformation;
	}

	void frameUpdate()
	{
		import kratos.input;
		
		if(mouse.scrollDown.justPressed)
		{
			targetTransformation.position.z *= distanceScale;
			interpTimeRemaining = interpTime;
			startTransformation = transform.localTransformation;
		}
		if(mouse.scrollUp.justPressed)
		{
			targetTransformation.position.z /= distanceScale;
			interpTimeRemaining = interpTime;
			startTransformation = transform.localTransformation;
		}

		transform.localTransformation = Transformation.interpolate(startTransformation, targetTransformation, smoothStep(interpTime*2, 0, interpTimeRemaining));

		interpTimeRemaining = clamp(interpTimeRemaining - time.delta, 0, interpTime);
	}
}

static this()
{
	registerComponent!TerrainTile;
	registerComponent!CameraAnchor;
	registerComponent!CameraMovement;
}