module sensor;

import kratos.component.transform;
import kratos.component.camera;
import kratos.component.time;
import kratos.ui.panel;
import kratos.ecs;
import kratos.util;
import rdconvert;

import kgl3n;

alias SensorId = string;

final class Sensor : Component
{
	SensorId id;

	private @dependency
	{
		SensorDataSource dataSource;
		Transform transform;
		CameraSelection cameraSelection;
		Time time;
	}

	private SensorData currentData;

	private Entity uiRootEntity;
	private TextPanel header;
	private TextPanel[SensorData.init.data.length] sensorReadings;
	private float[sensorReadings.length] timeSinceUpdate = 0;

	this(SensorId id)
	{
		this.id = id;
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
			readingFontSize = 0.05f,
			readingSize = vec2(headerSize.x / numReadings, headerSize.y),
			readingSpacing = 0.025f,
			readingBaseOffset = vec2(-readingSize.x * (numReadings - 1) / 2.0, headerOffset.y - headerFontSize - readingSpacing);

		uiRootEntity = scene.createEntity();
		uiRootEntity.components.add!Panel(panelSize, panelOffset, panelRenderState);
		header = uiRootEntity.components.add!TextPanel(headerSize, headerOffset, headerFontSize, fontFile, headerRenderState);
		header.text = id;

		foreach(i; 0..numReadings)
		{
			sensorReadings[i] = uiRootEntity.components.add!TextPanel(readingSize, readingBaseOffset + i * vec2(readingSize.x, 0), readingFontSize, fontFile, headerRenderState);
		}
		//TODO: Create gui
	}

	void frameUpdate()
	{
		auto camera = cameraSelection.mainCamera;
		
		auto uiTransform = uiRootEntity.components.first!Transform;
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
			SensorData("Test Sensor 1", vec2d(51.897877, 4.418613999999934)),
			SensorData("Test Sensor 2", vec2d(51.91, 4.45)),
			SensorData("Test Sensor 3", vec2d(51.85, 4.46)),
			SensorData("Test Sensor 4", vec2d(51.95, 4.455))
		];
	}

	void frameUpdate()
	{
		//TODO: Get input range of new messages
		//SensorData[] received;

		if((updateIn -= time.delta) <= 0)
		{
			updateIn = 10;

			import std.random : uniform;
			foreach(ref data; testSensorData)
			{
				foreach(ref val; data.data)
				{
					val = uniform(0, 5);
				}
			}
		}

		foreach(data; testSensorData)
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