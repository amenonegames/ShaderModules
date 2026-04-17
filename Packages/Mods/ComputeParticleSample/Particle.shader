Shader "Unlit/Particle"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Transparent" "Queue"="Transparent"
//            "RenderPipeline"="UniversalPipeline"
        }

        Pass
        {
            Name "UnlitParticle"
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
//            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Particle
            {
                float3 destination;
                float3 position;
                float4 color;
                float scale;
                float lifetime;
            };

            StructuredBuffer<Particle> _ParticleBuffer;
            StructuredBuffer<uint> _AliveList;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            Varyings vert(Attributes input, uint instanceID : SV_InstanceID)
            {
                UNITY_SETUP_INSTANCE_ID(input);
                int index = _AliveList[instanceID];
                Particle p = _ParticleBuffer[index];

                float3 worldPos = input.positionOS.xyz * p.scale + p.position;

                Varyings output;
                output.positionHCS = TransformWorldToHClip(worldPos);
                output.color = p.color;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,input.uv);
            }
            ENDHLSL
        }
    }
}
