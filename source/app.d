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

class Cursor : Component
{
	private @dependency
	{
		Transform transform;
		Time time;
		CameraSelection cameraSelection;
	}
	
	float mouseSensitivity = 0.005;
	vec3 speedMultiplier = vec3(0, 1, 0);
	
	private
	{
		CameraMovement movement;
	}
	
	void initialize()
	{
		movement = cameraSelection.mainCamera.owner.components.first!CameraMovement;
	}
	
	void frameUpdate()
	{
		import kratos.input;
		
		transform.scale = (transform.worldPosition - movement.transform.worldPosition).magnitude;
		transform.frameUpdate();
		
		auto scaledSpeed = (mouseSensitivity * dot(movement.transform.worldPosition, speedMultiplier));
		
		auto forward = ((movement.transform.worldMatrix * vec4(0, 0, -1, 0)).xyz * vec3(1, 0, 1)).normalized;
		auto right = ((movement.transform.worldMatrix * vec4(1, 0, 0, 0)).xyz * vec3(1, 0, 1)).normalized;
	
		if(mouse.grabbed && !mouse.buttons[1].pressed)
		{
			transform.position =
				transform.position +
				forward * -(mouse.yAxis.value * scaledSpeed) +
				right * (mouse.xAxis.value * scaledSpeed);
		}
		
		if(mouse.buttons[0].justReleased)
		{
			mouse.grabbed = !mouse.grabbed;
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
	float mouseSensitivity = 0.005;
	
	float speedMaxDist = 250;
	float maxSpeed = 1000;
	
	private Cursor cursor;
	
	private Transform.ChangedRegistration cursorTransformChanged;
	
	void initialize()
	{
		cameraSelection.mainCamera.transform.parent = transform;

		foreach(entity; scene.entities)
		{
			auto cursor = entity.components.first!Cursor;
			if(cursor !is null)
			{
				this.cursor = cursor;
				break;
			}
		}
		
		cursorTransformChanged = cursor.transform.onWorldTransformChanged.register(&updateTarget);
	}
	
	private void updateTarget(Transform transform)
	{
		
	}

	void frameUpdate()
	{
		import kratos.input;
		
		auto targetVector = cursor.transform.worldPosition - transform.worldPosition;
		auto dist = targetVector.magnitude;
		
		auto currSpeed = smoothStep(0, speedMaxDist, dist) * maxSpeed;
		auto movementThisFrame = targetVector.normalized * currSpeed * time.delta;
		
		transform.position += movementThisFrame;
		
		if(mouse.buttons[1].pressed)
		{
			ypr.x = (ypr.x + -mouse.xAxis.value * mouseSensitivity) % (PI * 2);
			ypr.y = (ypr.y + -mouse.yAxis.value * mouseSensitivity) % (PI * 2);
		}
		
		transform.rotation = quat.eulerRotation(ypr);
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
	registerComponent!Cursor;
	registerComponent!CameraAnchor;
	registerComponent!CameraMovement;
}