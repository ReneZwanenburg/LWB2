import kratos.ecs;
import kratos.component.camera;
import kratos.component.meshrenderer;
import kratos.component.transform;
import kratos.resource.loader.textureloader;
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