Shader "amenone_module/sample"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white"
        [Header(Transpose)]
        [MaterialToggle] _use_polar("Polar (R=radius G=angle)", float) = 0
        [MaterialToggle] _use_rotate("Rotate (RG=uv)", float) = 0
        [MaterialToggle] _use_spiral("Spiral", float) = 0
        
        [Header(Basic Noise)]
        [MaterialToggle] _use_random("Random", float) = 0
        [MaterialToggle] _use_noise("Noise", float) = 0
        [MaterialToggle] _use_fbm("FBM", float) = 0
        [MaterialToggle] _use_simplex_noise("Simplex Noise", float) = 0
        [MaterialToggle] _use_turbulence("Turbulence", float) = 0
        [MaterialToggle] _use_ridge("Ridge", float) = 0

        [Header(Voronoi)]
        [MaterialToggle] _use_voronoi("Voronoi (distance)", float) = 0
        [MaterialToggle] _use_voronoi_id("Voronoi (id)", float) = 0
        [MaterialToggle] _use_voronoi_normalized("Voronoi Normalized", float) = 0
        [MaterialToggle] _use_cellular("Cellular", float) = 0
        [MaterialToggle] _use_voronoi_blur("Voronoi Blur", float) = 0

        [Header(FBM Voronoi)]
        [MaterialToggle] _use_fbm_voronoi("FBM Voronoi", float) = 0
        [MaterialToggle] _use_fbm_cellular("FBM Cellular", float) = 0
        [MaterialToggle] _use_fbm_voronoi_normalized("FBM Voronoi Normalized", float) = 0
        [MaterialToggle] _use_fbm_voronoi_blur("FBM Voronoi Blur", float) = 0

        [Header(Curl)]
        [MaterialToggle] _use_curl_noise("Curl Noise", float) = 0
        [MaterialToggle] _use_curl_noise_fbm("Curl Noise FBM", float) = 0


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
            #include "Packages/com.amenone.shadermodules/Shaders/noise.cginc"
            #include "Packages/com.amenone.shadermodules/Shaders/transpose.cginc"

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
                float _use_random;
                float _use_noise;
                float _use_fbm;
                float _use_simplex_noise;
                float _use_turbulence;
                float _use_ridge;
                float _use_voronoi;
                float _use_voronoi_id;
                float _use_voronoi_normalized;
                float _use_cellular;
                float _use_voronoi_blur;
                float _use_fbm_voronoi;
                float _use_fbm_cellular;
                float _use_fbm_voronoi_normalized;
                float _use_fbm_voronoi_blur;
                float _use_curl_noise;
                float _use_curl_noise_fbm;
                float _use_polar;
                float _use_rotate;
                float _use_spiral;
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
                float2 cellOffset = float2(1, _Time.y);
                float cell_size = 0.1;

                half4 color = half4(0, 0, 0, 1);
                if (_use_polar)           uv = uv_to_polar(uv);
                if (_use_rotate)          uv = rotate(uv,_Time.x);
                if (_use_spiral)          uv = spiral(uv, 1.);
                if (_use_random)          color.rgb += random(uv);
                if (_use_noise)           color.rgb += noise(uv * 8.);
                if (_use_fbm)             color.rgb += fbm(uv*4., 0.5, 8);
                if (_use_simplex_noise)   color.rgb += simplex_noise(uv*2.);
                if (_use_turbulence)      color.rgb += turbulence(uv, 0.5, 8);
                if (_use_ridge)           color.rgb += ridge(uv, 0.5, 4, 0.8,3.);

                if (_use_voronoi)             color.rgb += voronoi(uv, cell_size, cellOffset).x;
                if (_use_voronoi_id)          color.rgb += voronoi(uv, cell_size, cellOffset).y;
                if (_use_voronoi_normalized)  color.rgb += voronoi_normalized(uv, cell_size, cellOffset).x;
                if (_use_cellular)            color.rgb += cellular(uv, cell_size, cellOffset).x;
                if (_use_voronoi_blur)        color.rgb += voronoi_blur(uv, cell_size, 0.6, cellOffset).x;

                if (_use_fbm_voronoi)             color.rgb += fbm_voronoi(uv, 0.4, 8, cell_size, cellOffset).x;
                if (_use_fbm_cellular)            color.rgb += fbm_cellular(uv, 0.4, 8, cell_size, cellOffset).x;
                if (_use_fbm_voronoi_normalized)  color.rgb += fbm_voronoi_normalized(uv, 0.4, 8, cell_size, cellOffset).x;
                if (_use_fbm_voronoi_blur)        color.rgb += fbm_voronoi_blur(uv, 0.4, 8, cell_size, cellOffset, 0.2).x;

                if (_use_curl_noise)      color.rgb += curl_noise(float3(uv, _Time.x * 0.1), 0.08);
                if (_use_curl_noise_fbm)  color.rgb += curl_noise_fbm(float3(uv, _Time.x), 1.0, 8);



                return color;
            }
            ENDHLSL
        }
    }
}
