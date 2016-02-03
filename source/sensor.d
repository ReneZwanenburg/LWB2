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

import mqttd;
import std.container.array;
import std.array : array;
import std.algorithm.iteration : splitter;
import core.sync.mutex;
import kvibe.data.json;

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
		Transform transform;
		CameraSelection cameraSelection;
		Time time;
	}
	
	private SensorId id;
	private SensorData currentData;

	private Entity uiRootEntity;
	private Transform uiTransform;
	private TextPanel header;
	private enum numSensorReadings = 4;
	private TextPanel[numSensorReadings] sensorReadings;
	private float[numSensorReadings] timeSinceUpdate = 0;

	private string[] readingNames;

	private SensorLocationIndicator locationIndicator;

	private Timer makeVisibleTimer;
	private Timer hideTimer;
	private bool _visible;

	this(SensorId id, string[] readingNames)
	{
		this.id = id;
		this.readingNames = readingNames;
		currentData.data.length = readingNames.length;
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
					sensorReadings[i].text = value;
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

final class SensorTestDataSource : SceneComponent
{
	private Sensor[SensorId] sensors;
	private SensorData[] testSensorData;

	private float updateIn = 0;

	private @dependency Time time;
	
	private bool enabled = false;

	void initialize()
	{
		testSensorData =
		[
			SensorData("Test Sensor 1", vec2d(51.917301, 4.484350)),
			SensorData("Test Sensor 2", vec2d(51.924411, 4.477744)),
			SensorData("Test Sensor 3", vec2d(51.922973, 4.496150))
		];
		
		foreach(ref sensor; testSensorData)
		{
			sensor.data.length = 4;
		}
	}

	void frameUpdate()
	{
		import kratos.input;
		if(keyboard["F1"].justPressed) enabled = !enabled;
		
		if(enabled && (updateIn -= time.delta) <= 0)
		{
			import std.random : uniform;

			updateIn = uniform(0.5, 2.0);

			auto data = testSensorData[uniform(0, testSensorData.length)];

			foreach(ref val; data.data)
			{
				import std.conv : text;
				val = uniform(0, 5).text;
			}

			sensors.getOrAdd(data.id, createNewSensor(data.id)).receive(data);
		}
	}

	private Sensor createNewSensor(SensorId id)
	{
		auto entity = scene.createEntity("Sensor " ~ id);
		return entity.components.add!Sensor(id, ["Temp", "Humidity", "Air pressure", "Power"]);
	}
}

final class SensorMqttDataSource : SceneComponent
{
	private Subscriber subscriber;
	private MqttConfiguration config;
	
	private Array!SensorData messageQueue;
	private Mutex queueMutex;
	
	private Sensor[SensorId] sensors;
	
	string configurationFile = "MqttConfig.json";
	
	this()
	{
		queueMutex = new Mutex();
	}
	
	void initialize()
	{
		config = deserializeJson!MqttConfiguration(loadJson(configurationFile));
		
		import core.thread;
		
		auto thread = new Thread(()
		{
			subscriber = new Subscriber(config, &handlePacket);
			subscriber.connect();
			
			import vibe.core.core : runEventLoop;
			runEventLoop();
		});
		
		thread.isDaemon = true;
		thread.start();
	}
	
	~this()
	{
		subscriber.disconnect();
	}
	
	void frameUpdate()
	{
		synchronized(queueMutex)
		{
			foreach(data; messageQueue[])
			{
				auto sensor = sensors.getOrAdd(data.id, createNewSensor(data.id));
				sensor.receive(data);
			}
			
			messageQueue.clear();
		}
	}

	private Sensor createNewSensor(SensorId id)
	{
		auto entity = scene.createEntity("Sensor " ~ id);
		return entity.components.add!Sensor(id, config.sensorNames);
	}
	
	// Called from event loop thread
	private void handlePacket(Publish packet)
	{
		auto payloadStr = cast(string)packet.payload;
		auto message = parseJson(payloadStr);
		SensorData data;
		
		data.id = message["devEUI"].get!string;
		data.latLong = vec2d(message["lrrLAT"].get!double, message["lrrLON"].get!double);
		data.data = message["payloadHex"].get!string.splitter(config.messageSplitter).array;
		
		if(data.data.length > config.sensorNames.length)
		{
			data.data.length = config.sensorNames.length;
		}
		
		synchronized(queueMutex)
		{
			messageQueue.insertBack(data);
		}
	}
}

private class Subscriber : MqttClient
{
	alias PublishHander = void delegate(Publish);

	private MqttConfiguration config;
	private PublishHander handler;

	this(MqttConfiguration config, PublishHander publishHandler)
	{
		this.config = config;
		this.handler = publishHandler;
	
		Settings settings;
		settings.host = config.host;
		settings.port = config.port;
		settings.clientId = "Sensor Data Viewer";
		settings.userName = config.userName;
		settings.password = config.password;
	
		super(settings);
	}
	
	override void onPublish(Publish packet)
	{
		super.onPublish(packet);
		try
		{
			handler(packet);
		}
		catch(Exception e)
		{
			// Probably malformed packet. Just swallow for now.
		}
	}

    override void onConnAck(ConnAck packet)
	{
        super.onConnAck(packet);
        this.subscribe([config.topic]);
    }
}

struct MqttConfiguration
{
	string host;
	ushort port;
	string userName;
	string password;
	string topic;
	
	string messageSplitter;
	string[] sensorNames;
}

struct SensorData
{
	SensorId id;
	vec2d latLong;
	string[] data;
}

private static vec2d rdToWorld(vec2d rd)
{
	enum worldOffset = vec2d(56000, 447000);
	return (rd - worldOffset) * vec2d(1, -1);
}

static this()
{
	registerComponent!SensorTestDataSource;
	registerComponent!SensorMqttDataSource;
}