import terrain;
import camera;
import sensor;

import kratos.ecs;


static this()
{
	registerComponent!TerrainTile;
	registerComponent!CameraAnchor;
	registerComponent!CameraMovement;
	registerComponent!SensorClickedListener;
}