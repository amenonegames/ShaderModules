Shader "Custom/Sample"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white"
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.amenone.shadermodules/noise.cginc"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                float4 _BaseMap_ST;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = half4(0,0,0,0);
                // color = random(IN.uv);
                // color = simplex_noise(IN.uv,0.1);
                // color = turbulence(IN.uv,0.5,8,0.8);
                // color = ridge(IN.uv,0.5,4,1.5);
                // color = voronoi (IN.uv,.1);
                // color = voronoi_normalized (IN.uv,.1);
                // color = cellular(IN.uv,.1,float2(1,_Time.y));
                color = fbm_cellular(IN.uv,0.4,8,.01,float2(1,_Time.y));
                return color;
            }
            ENDHLSL
        }
    }
}
