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
            "RenderType"="Opaque"
//            "RenderPipeline"="UniversalPipeline"
        }

        Pass
        {
            Name "UnlitParticle"
//            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Particle
            {
                float3 basePosition;
                float3 position;
                float4 color;
                float scale;
            };

            StructuredBuffer<Particle> _ParticleBuffer;
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

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

                Particle p = _ParticleBuffer[instanceID];

                float3 worldPos = input.positionOS.xyz * p.scale + p.position;

                Varyings output;
                output.positionHCS = TransformWorldToHClip(worldPos);
                output.color = p.color;
                output.uv = input.uv;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return input.color;
            }
            ENDHLSL
        }
    }
}
