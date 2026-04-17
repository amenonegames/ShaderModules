using System;
using UnityEngine;


namespace Sandbox
{
    /// <summary>
    /// 画像をdevCount数で分割し、各分割領域に対して平均alpha値を算出。結果をrawDataとして取得するデモ
    /// </summary>
    public class ComputeTextSample :MonoBehaviour
    {
        [SerializeField] private ComputeShader shader;
        [SerializeField] private Texture texture;
        [SerializeField] private Mesh _particleMesh;
        [SerializeField] private MeshFilter _targetMeshFilter;
        [SerializeField] private Material _particleMat;
        private RenderParams _renderParams;
        private GraphicsBuffer _argBuffer;
        [SerializeField] private int _meshCount = 10;

        public struct Text
        {
            public Vector3 position;
            public Vector4 color;
            public float scale;
            public float lifetime;
        }
        private void Start()
        {
            int computeTextID = shader.FindKernel("ComputeText");

            shader.Dispatch(computeTextID, 1, 1, 1);
            _renderParams = new RenderParams(_particleMat)
            {
                worldBounds = new Bounds(Vector3.zero, Vector3.one * 32f), // 描画の最大範囲。この範囲がカメラに収まっていないと描画されない。
            };
            var args = new uint[5]
            {
                _particleMesh.GetIndexCount(0),
                (uint)_meshCount,
                _particleMesh.GetIndexStart(0),
                _particleMesh.GetBaseVertex(0),
                0,
            };
            _argBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments | GraphicsBuffer.Target.Structured,
                args.Length,
                sizeof(uint));
            Graphics.RenderMeshIndirect(_renderParams, _particleMesh, _argBuffer);
        }

        private void OnDestroy()
        {

        }
    }
}