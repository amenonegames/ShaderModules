using System;
using UnityEngine;

namespace Sandbox
{
    /// <summary>
    /// 画像をdevCount数で分割し、各分割領域に対して平均alpha値を算出。結果をrawDataとして取得するデモ
    /// </summary>
    public class ComputeShaderGetTextureAlphaSample :MonoBehaviour
    {
        private static readonly int Result = Shader.PropertyToID("Result");
        private static readonly int Texture1 = Shader.PropertyToID("Texture");
        private static readonly int Length = Shader.PropertyToID("Length");
        private static readonly int Width = Shader.PropertyToID("pixelPerDivW");
        private static readonly int Height = Shader.PropertyToID("pixelPerDivH");
        [SerializeField] private ComputeShader shader;
        [SerializeField] private Texture texture;
        private readonly int _divCount = 10;

        private void Start()
        {
            int pixelPerDivW = texture.width / _divCount; // 分割区画ごとのピクセル数を算出
            pixelPerDivW = pixelPerDivW - (1 - pixelPerDivW % 2); // 奇数に切り下げ
            int pixelPerDivH = texture.height / _divCount;
            pixelPerDivH = pixelPerDivH -  (1 - pixelPerDivH % 2); // 奇数に切り下げ

            int num = _divCount * _divCount;
            ComputeBuffer buffer = new ComputeBuffer(num, sizeof(float));

            int kernelID = shader.FindKernel("ComputeAlpha");

            shader.SetBuffer(kernelID , Result , buffer);
            shader.SetTexture(kernelID,Texture1,texture);
           shader.SetInt(Length,_divCount);
           shader.SetInt(Width,pixelPerDivW);
           shader.SetInt(Height,pixelPerDivH);

           float[] rawData = new float[num];

            shader.Dispatch(kernelID, _divCount, _divCount, 1);
            buffer.GetData(rawData);
            buffer.Release();
        }
    }
}