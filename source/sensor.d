module sensor;

import kratos.component.transform;
import kratos.component.meshrenderer;
import kratos.component.camera;
import kratos.component.time;
import kratos.component.spatialpartitioning;
import kratos.graphics.shadervariable : UniformRef;
import kratos.ui.panel;
import kratos.ecs;
import kratos.util;
import kratos.resource.loader.jsonloader;
import rdconvert;

import kgl3n;

import std.stdio;

alias SensorId = string;

alias SensorPartitioning = SpatialPartitioning!Sensor;

final class Sensor : Component
{
	@optional
	{
		float showAnimationTime = 0.4;
		float hideAnimationTime = 0.25;
		
		vec3 readingColor = vec3();
		vec3 readingUpdatedColor = vec3(0, 1, 0);
	}

	private @dependency
	{
		SensorDataSource dataSource;
		Transform transform;
		CameraSelection cameraSelection;
		Time time;
	}
	
	private SensorId id;
	private SensorData currentData;

	private Entity uiRootEntity;
	private Transform uiTransform;
	private TextPanel header;
	private TextPanel[SensorData.init.data.length] sensorReadings;
	private float[sensorReadings.length] timeSinceUpdate = 0;

	private immutable string[] readingNames = ["Reading 1", "Reading 2", "Reading 3", "Reading 4"];

	private SensorLocationIndicator locationIndicator;

	private Timer makeVisibleTimer;
	private Timer hideTimer;
	private bool _visible;

	this(SensorId id)
	{
		this.id = id;
		currentData.data[] = float.nan;
		scene.components.firstOrAdd!SensorPartitioning().register(this);
	}

	~this()
	{
		scene.components.firstOrAdd!SensorPartitioning().deregister(this);
	}

	void initialize()
	{
		enum
			fontFile = "Fonts/OpenSans-Regular.ttf";

		enum 
			panelSize = vec2(0.5, 0.2),
			panelOffset = vec2(0, 0.2),
			panelRenderState = "RenderStates/SensorPanelBackground.renderstate";

		enum
			headerFontSize = 0.05f,
			headerSize = vec2(panelSize.x - 0.05, headerFontSize),
			headerOffset = vec2(0, panelSize.y / 2 - headerFontSize / 2) + panelOffset,
			headerRenderState = "RenderStates/SensorPanelHeader.renderstate";

		enum
			numReadings = sensorReadings.length,
			readingHeaderFontSize = 0.025f,
			readingHeaderSize = vec2(headerSize.x / numReadings, readingHeaderFontSize),
			readingHeaderSpacing = 0.025f,
			readingHeaderBaseOffset = vec2(-readingHeaderSize.x * (numReadings - 1) / 2.0, headerOffset.y - headerFontSize - readingHeaderSpacing),

			readingFontSize = 0.05f,
			readingSize = vec2(headerSize.x / numReadings, readingFontSize),
			readingSpacing = 0.025f,
			readingBaseOffset = vec2(readingHeaderBaseOffset.x, readingHeaderBaseOffset.y - readingHeaderFontSize - readingSpacing);

		uiRootEntity = scene.createEntity();
		uiRootEntity.components.add!Panel(panelSize, panelOffset, panelRenderState);
		uiTransform = uiRootEntity.components.first!Transform;

		uiTransform.rotation = quat.eulerRotation(vec3(PI * 0.5, 0, 0));

		header = uiRootEntity.components.add!TextPanel(headerSize, headerOffset, headerFontSize, fontFile, headerRenderState);
		header.text = id;

		foreach(i; 0..numReadings)
		{
			auto readingHeader = uiRootEntity.components.add!TextPanel(readingHeaderSize, readingHeaderBaseOffset + i * vec2(readingHeaderSize.x, 0), readingHeaderFontSize, fontFile, headerRenderState);
			readingHeader.text = readingNames[i];

			sensorReadings[i] = uiRootEntity.components.add!TextPanel(readingSize, readingBaseOffset + i * vec2(readingSize.x, 0), readingFontSize, fontFile, headerRenderState);
		}

		auto indicatorEntity = scene.createEntity();
		indicatorEntity.components.merge(loadJson("Components/SensorLocationIndicator.component"));
		locationIndicator = indicatorEntity.components.first!SensorLocationIndicator;
		locationIndicator.transform.parent = transform;

		makeVisibleTimer = owner.components.add!Timer(0.4);
		makeVisibleTimer.onUpdate += &makeVisibleCallback;
		hideTimer = owner.components.add!Timer(0.25);
		hideTimer.onUpdate += &hideCallback;
	}

	private void makeVisibleCallback()
	{
		auto yaw = (cos(makeVisibleTimer.phase * PI * 2) * (1-makeVisibleTimer.phase ^^ 0.75)) * PI * 0.5;
		uiTransform.rotation = quat.eulerRotation(vec3(yaw, 0, 0));
	}

	private void hideCallback()
	{
		auto yaw = sin(hideTimer.phase * PI * 0.5) * PI * 0.5;
		uiTransform.rotation = quat.eulerRotation(vec3(yaw, 0, 0));
	}

	void frameUpdate()
	{
		auto camera = cameraSelection.mainCamera;

		auto clipCoords = camera.viewProjectionMatrix * vec4(transform.position, 1);
		uiTransform.position = vec3(clipCoords.xy / clipCoords.w, 0);

		foreach(i, panel; sensorReadings)
		{
			auto textColor = lerp(vec3(0, 1, 0), vec3(), smoothStep(0, 2, timeSinceUpdate[i]));
			timeSinceUpdate[i] += time.delta;
			panel.mesh.renderState.shader.uniforms["color"] = textColor;
		}
	}

	void receive(SensorData data)
	{
		locationIndicator.updateTimer.start();

		if(data !is currentData)
		{
			auto worldCoords = gpsToRd(data.latLong.x, data.latLong.y).rdToWorld();
			transform.position = vec3(worldCoords.x, 0, worldCoords.y);

			foreach(i, value; data.data)
			{
				if(value != currentData.data[i])
				{
					import std.conv : text;
					sensorReadings[i].text = value.text;
					timeSinceUpdate[i] = 0;
				}
			}

			currentData = data;
		}
	}

	auto worldSpaceBound()
	{
		return locationIndicator.meshRenderer.worldSpaceBound;
	}

	@property
	{
		bool visible() { return _visible; }

		void visible(bool newVisible)
		{
			if(newVisible != _visible)
			{
				_visible = newVisible;

				if(newVisible)
				{
					makeVisibleTimer.start();
					hideTimer.stop();
				}
				else
				{
					hideTimer.start();
					makeVisibleTimer.stop();
				}
			}
		}
	}
}

final class SensorLocationIndicator : Component
{
	@optional
	{
		float updateAnimationTime = 2;
		vec3 indicatorColor = vec3();
		vec3 updatedIndicatorColor = vec3(0, 1, 0);
	}

	private @dependency
	{
		Transform transform;
		MeshRenderer meshRenderer;
		CameraSelection cameraSelection;
	}
	
	private static struct Uniforms
	{
		UniformRef!vec3 color;
	}

	private Uniforms uniforms;
	private Timer updateTimer;

	void initialize()
	{
		uniforms = meshRenderer.mesh.renderState.shader.uniforms.getRefs!Uniforms;
		updateTimer = owner.components.add!Timer(updateAnimationTime);
		updateTimer.onUpdate += &onUpdated;
	}
	
	void onUpdated()
	{
		uniforms.color = lerp(updatedIndicatorColor, indicatorColor, updateTimer.smoothPhase);
	}

	void frameUpdate()
	{
		transform.scale = (transform.worldPosition - cameraSelection.mainCamera.transform.worldPosition).magnitude;
	}
}

final class SensorClickedListener : SceneComponent
{
	private @dependency
	{
		SensorPartitioning partitioning;
		CameraSelection cameraSelection;
	}

	private
	{
		bool mouseNotMoved;
		vec2 mouseClipCoords;
	}

	void frameUpdate()
	{
		import kratos.input;

		if(mouse.buttons[0].justPressed)
		{
			mouseNotMoved = true;
			mouseClipCoords = mouse.clipPointer.position;
		}

		if(mouse.buttons[0].pressed)
		{
			mouseNotMoved &= mouse.clipPointer.position == mouseClipCoords;
		}

		if(mouse.buttons[0].justReleased && mouseNotMoved)
		{
			auto pickRay = cameraSelection.mainCamera.createPickRay(mouseClipCoords);
			auto selectedSensors = partitioning.intersecting(pickRay);

			foreach(sensor; selectedSensors)
			{
				sensor.visible = !sensor.visible;
			}
		}

		if(keyboard["Space"].justPressed)
		{
			import std.algorithm.searching : any;
			auto makeVisible = !partitioning.all.any!(a => a.visible);
			foreach(sensor; partitioning.all)
			{
				sensor.visible = makeVisible;
			}
		}
	}
}

final class SensorDataSource : SceneComponent
{
	private Sensor[SensorId] sensors;
	private SensorData[] testSensorData;

	private float updateIn = 0;

	private @dependency Time time;

	void initialize()
	{
		testSensorData =
		[
			SensorData("Test Sensor 1", vec2d(51.897877, 4.418614)),
			SensorData("Test Sensor 2", vec2d(51.917301, 4.484350)),
			SensorData("Test Sensor 3", vec2d(51.924411, 4.477744)),
			SensorData("Test Sensor 4", vec2d(51.922973, 4.496150))
		];
	}

	void frameUpdate()
	{
		//TODO: Get input range of new messages
		SensorData[] received;

		if((updateIn -= time.delta) <= 0)
		{
			import std.random : uniform;

			updateIn = uniform(0.5, 2.0);

			auto sensorToUpdate = uniform(0, testSensorData.length);

			foreach(ref val; testSensorData[sensorToUpdate].data)
			{
				val = uniform(0, 5);
			}

			received ~= testSensorData[sensorToUpdate];
		}

		foreach(data; received)
		{
			auto sensor = sensors.getOrAdd(data.id, createNewSensor(data.id));
			sensor.receive(data);
		}
	}

	private Sensor createNewSensor(SensorId id)
	{
		auto entity = scene.createEntity("Sensor " ~ id);
		return entity.components.add!Sensor(id);
	}
}

struct SensorData
{
	SensorId id;
	vec2d latLong;
	float[4] data = 0;
}

private static vec2d rdToWorld(vec2d rd)
{
	enum worldOffset = vec2d(56000, 447000);
	return (rd - worldOffset) * vec2d(1, -1);
}

static this()
{
	registerComponent!SensorDataSource;
}