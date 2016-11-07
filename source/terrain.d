import kratos.ecs;
import kratos.component.camera;
import kratos.component.meshrenderer;
import kratos.component.transform;
import kratos.resource.loader.imageloader;
import kratos.graphics.texture;
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
		auto distance = (cameraSelection.mainCamera.transform.worldTransformation.position - transform.worldTransformation.position).magnitude;
		auto lod = (distance / 1024).max(0).log2.max(0).to!uint;
		
		if(currentLevel != lod)
		{
			meshRenderer.mesh.renderState.shader.uniforms[textureUniformName] = TextureManager.create(loadImage(textureName, lod));
			currentLevel = lod;
		}
	}
}