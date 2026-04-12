using System;
using UnityEngine;
using UnityEngine.UI;

namespace Sandbox
{
    /// <summary>
    /// 画像をdevCount数で分割し、各分割領域に対して平均alpha値を算出。結果をrawDataとして取得するデモ
    /// </summary>
    public class ComputeShaderGetTextureAlphaSample :MonoBehaviour
    {
        private static readonly int Texture1 = Shader.PropertyToID("Texture");
        private static readonly int Width = Shader.PropertyToID("pixelPerDivW");
        private static readonly int Height = Shader.PropertyToID("pixelPerDivH");
        private static readonly int ResultTexture = Shader.PropertyToID("ResultTexture");
        private static readonly int DivCount = Shader.PropertyToID("divCount");
        private static readonly int ShrinkBuffer = Shader.PropertyToID("ShrinkBuffer");
        [SerializeField] private ComputeShader shader;
        [SerializeField] private Texture texture;
        private RenderTexture resultTexture;
        private readonly int _divCount = 10;

        [SerializeField] private RawImage rawImage;
        private void Start()
        {
            int pixelPerDivW = texture.width / _divCount; // 分割区画ごとのピクセル数を算出
            pixelPerDivW = pixelPerDivW - (1 - pixelPerDivW % 2); // 奇数に切り下げ
            int pixelPerDivH = texture.height / _divCount;
            pixelPerDivH = pixelPerDivH -  (1 - pixelPerDivH % 2); // 奇数に切り下げ

            resultTexture = RenderTexture.GetTemporary(texture.width, texture.height, 0, RenderTextureFormat.ARGB32);
            resultTexture.filterMode = FilterMode.Point;
            resultTexture.enableRandomWrite = true;
            resultTexture.Create();

            var shrinkBufferTexture = RenderTexture.GetTemporary(_divCount, _divCount, 0, RenderTextureFormat.ARGB32);
            shrinkBufferTexture.filterMode = FilterMode.Point;
            shrinkBufferTexture.enableRandomWrite = true;
            shrinkBufferTexture.Create();

            int computeAlphaID = shader.FindKernel("ComputeAlpha");
            // int expandResult = shader.FindKernel("ExpandTextureResult");
            shader.SetTexture(computeAlphaID,Texture1,texture);
            shader.SetTexture(computeAlphaID,ShrinkBuffer, shrinkBufferTexture);
            // shader.SetTexture(expandResult,ShrinkBuffer, shrinkBufferTexture);

            // shader.SetTexture(expandResult,ResultTexture,resultTexture);
            shader.SetInt(Width,pixelPerDivW);
            shader.SetInt(Height,pixelPerDivH);
            shader.SetInt(DivCount,_divCount);

            shader.Dispatch(computeAlphaID, _divCount, _divCount, 1);
            // shader.Dispatch(expandResult, texture.width,  texture.height, 1);
            Graphics.Blit(shrinkBufferTexture, resultTexture);
            RenderTexture.ReleaseTemporary(shrinkBufferTexture);

            rawImage.texture = resultTexture;
        }

        private void OnDestroy()
        {
            if (resultTexture == null) return;
            RenderTexture.ReleaseTemporary(resultTexture);
        }
    }
}