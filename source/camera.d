import kratos.ecs;
import kratos.component.transform;
import kratos.component.camera;
import kratos.component.time;
import kgl3n;
import kgl3n.math : smoothStep;
import std.math;

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
			ypr.y = clamp(ypr.y, -PI * 0.45, -PI * 0.05);
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
		
		if(mouse.scrollDown.pressed)
		{
			targetTransformation.position.z *= distanceScale;
			interpTimeRemaining = interpTime;
			startTransformation = transform.localTransformation;
		}
		if(mouse.scrollUp.pressed)
		{
			targetTransformation.position.z /= distanceScale;
			interpTimeRemaining = interpTime;
			startTransformation = transform.localTransformation;
		}

		transform.localTransformation = Transformation.interpolate(startTransformation, targetTransformation, smoothStep(interpTime*2, 0, interpTimeRemaining));

		interpTimeRemaining = clamp(interpTimeRemaining - time.delta, 0, interpTime);
	}
}