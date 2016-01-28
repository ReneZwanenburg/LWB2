module sensor;

import kratos.component.transform;
import kratos.component.camera;
import kratos.component.time;
import kratos.ui.panel;
import kratos.ecs;
import kratos.util;
import rdconvert;

import kgl3n.vector;

alias SensorId = vec2d; //LatLong as sensor id for now, need some unique identifier..

final class Sensor : Component
{
	SensorId id;

	private @dependency
	{
		SensorDataSource dataSource;
		Transform transform;
		CameraSelection cameraSelection;
	}

	private SensorData currentData;

	private Entity uiRootEntity;
	private TextPanel[SensorData.init.data.length] sensorReadings;

	this(SensorId id)
	{
		this.id = id;
	}

	void initialize()
	{
		uiRootEntity = scene.createEntity();
		sensorReadings[0] = uiRootEntity.components.add!TextPanel(vec2(0.5, 0.5), 0.05, "Fonts/OpenSans-Regular.ttf", "RenderStates/UI/TextPanel.renderstate");
		sensorReadings[0].text = "Test Sensor";
		//TODO: Create gui
	}

	void frameUpdate()
	{
		auto camera = cameraSelection.mainCamera;
		
		auto uiTransform = uiRootEntity.components.first!Transform;
		auto clipCoords = camera.viewProjectionMatrix * vec4(transform.position, 1);
		uiTransform.position = vec3(clipCoords.xy / clipCoords.w, 0);
	}

	void receive(SensorData data)
	{
		import std.stdio;
		writeln("recv");

		if(data !is currentData)
		{
			currentData = data;

			//TODO: Implement rdToWorld
			//auto worldCoords = gpsToRd(data.latLong.x, data.latLong.y).rdToWorld();
			auto worldCoords = data.latLong;

			transform.position = vec3(worldCoords.x, 0, worldCoords.y);

			// TODO: Update
		}
	}
}

final class SensorDataSource : SceneComponent
{
	private Sensor[SensorId] sensors;

	private float updateIn = 0;

	private @dependency Time time;

	void frameUpdate()
	{
		//TODO: Get input range of new messages
		SensorData[] received;

		if((updateIn -= time.delta) <= 0)
		{
			updateIn = 10;
			received ~= SensorData(vec2d(38000, 11000), vec2d(38000, 11000));
		}

		foreach(data; received)
		{
			auto sensor = sensors.getOrAdd(data.id, createNewSensor(data.id));
			sensor.receive(data);
		}
	}

	private Sensor createNewSensor(SensorId id)
	{
		auto entity = scene.createEntity("Sensor " ~ id.toString());
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
	//TODO: look up world offset
	enum worldOffset = vec2d();
	return rd - worldOffset;
}

static this()
{
	registerComponent!SensorDataSource;
}