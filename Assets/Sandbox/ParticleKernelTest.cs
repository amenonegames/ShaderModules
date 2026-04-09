using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;
using Random = UnityEngine.Random;

namespace Sandbox
{
    public class ParticleKernelTest : MonoBehaviour
    {
        private static readonly int ParticleBuffer = Shader.PropertyToID("_ParticleBuffer");
        private static readonly int DeltaTime = Shader.PropertyToID("_DeltaTime");
        private static readonly int ParticleCount = Shader.PropertyToID("_ParticleCount");
        private static readonly int AliveList = Shader.PropertyToID("_AliveList");
        private static readonly int AliveCount = Shader.PropertyToID("_AliveCount");
        private static readonly int ArgBuffer = Shader.PropertyToID("_argBuffer");

        [SerializeField] private int _count = 10000;
        [SerializeField] private ComputeShader _computeShader;
        [SerializeField] private Mesh _particleMesh;
        [SerializeField] private MeshFilter _targetMeshFilter;
        [SerializeField] private Material _particleMat;
        [SerializeField] private Color _color = Color.blue;

        private GraphicsBuffer _particleBuffer;
        private GraphicsBuffer _argBuffer;
        private GraphicsBuffer _aliveListBuffer;
        private GraphicsBuffer _aliveCountBuffer;
        private int _kernelId;
        private int _copyAliveCountId;
        private RenderParams _renderParams;

        public struct Particle
        {
            public Vector3 basePosition;
            public Vector3 position;
            public Vector4 color;
            public float scale;
            public float lifetime;
        }

        private void Start()
        {
            _kernelId = _computeShader.FindKernel("ParticleMain");
            var initializeId = _computeShader.FindKernel("Initialize");
            _copyAliveCountId  = _computeShader.FindKernel("CopyAliveCount");

            _computeShader.SetInt(ParticleCount, _count);

            var vertices = new List<Vector3>();
            _targetMeshFilter.mesh.GetVertices(vertices);

            var particles = new Particle[_count];
            for (int i = 0; i < _count; i++)
            {
                particles[i] = new Particle
                {
                    basePosition = vertices[i % vertices.Count],
                    position = vertices[i % vertices.Count] + Random.insideUnitSphere * 10f,
                    color = _color,
                    scale = Random.Range(0.01f, 0.02f),
                };
            }

            _particleBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, _count, Marshal.SizeOf<Particle>());
            _particleBuffer.SetData(particles);
            _computeShader.SetBuffer(_kernelId, ParticleBuffer, _particleBuffer);
            _computeShader.SetBuffer(initializeId, ParticleBuffer, _particleBuffer);
            _particleMat.SetBuffer(ParticleBuffer, _particleBuffer);

            _aliveListBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, _count, sizeof(uint));
            _computeShader.SetBuffer(_kernelId, AliveList, _aliveListBuffer);
            _computeShader.SetBuffer(initializeId, AliveList, _aliveListBuffer);
            _particleMat.SetBuffer(AliveList, _aliveListBuffer);

            _aliveCountBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, 1,
                sizeof(uint));
            _computeShader.SetBuffer(_kernelId, AliveCount, _aliveCountBuffer);
            _computeShader.SetBuffer(_copyAliveCountId, AliveCount, _aliveCountBuffer);

            var args = new uint[5]
            {
                _particleMesh.GetIndexCount(0),
                (uint)_count,
                _particleMesh.GetIndexStart(0),
                _particleMesh.GetBaseVertex(0),
                0,
            };
            _argBuffer = new GraphicsBuffer(GraphicsBuffer.Target.IndirectArguments | GraphicsBuffer.Target.Structured,
                args.Length,
                    sizeof(uint));
            _argBuffer.SetData(args);
            _computeShader.SetBuffer(_copyAliveCountId, ArgBuffer, _argBuffer);

            _renderParams = new RenderParams(_particleMat)
            {
                worldBounds = new Bounds(Vector3.zero, Vector3.one * 32f),
                matProps = new MaterialPropertyBlock(),
            };
            _computeShader.Dispatch(initializeId,Mathf.CeilToInt(_count / 64f), 1, 1);
        }

        private void Update()
        {
            _computeShader.SetFloat(DeltaTime, Time.deltaTime);
            _computeShader.Dispatch(_kernelId, Mathf.CeilToInt(_count / 64f), 1, 1);
            _computeShader.Dispatch(_copyAliveCountId,1,1,1);
            Graphics.RenderMeshIndirect(_renderParams, _particleMesh, _argBuffer);
        }

        private void OnDestroy()
        {
            _particleBuffer?.Dispose();
            _argBuffer?.Dispose();
            _aliveListBuffer?.Dispose();
            _aliveCountBuffer?.Dispose();
        }
    }
}