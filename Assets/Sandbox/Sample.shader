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
            #include "Packages/com.amenone.shadermodules/transpose.cginc"

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
                float2 uv = IN.uv;
                uv = uv_to_polar(uv);
                
                half4 color = half4(0,0,0,0);
                // color = random(uv);
                // color = fbm(uv,0.5,8);
                // color = simplex_noise(uv,0.1);
                // color = turbulence(uv,0.5,8,0.8);
                // color = ridge(uv,0.5,4,1.5);
                // color = voronoi (uv,.1);
                // color = voronoi_normalized (uv,.1);
                // color = cellular(uv,.1,float2(1,_Time.y));
                // color = fbm_cellular(uv,0.4,8,.1,float2(1,_Time.y));
                color = fbm_voronoi_normalized(uv,0.4,8,.1,float2(1,_Time.y));
                
                // sample combine animation
                // half sinedTime = _Time.y + pow(sin(_Time.w),3);
                // half f = fbm(uv + sinedTime,0.5,8);
                // color = turbulence(float2(uv.x ,uv.y + f),0.5,8,0.8);
                
                return color;
            }
            ENDHLSL
        }
    }
}
