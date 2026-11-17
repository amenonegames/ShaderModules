Shader "amenone_module/sample"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
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

        [Header(Composite)]
        [MaterialToggle] _use_caustic("Caustic", float) = 0
        [MaterialToggle] _use_domain_warp("Domain Warp", float) = 0

        [Header(Fractal)]
        [MaterialToggle] _use_fractal_kifs("KIFS", float) = 0
        [MaterialToggle] _use_fractal_kaleidoscope_rings("Kaleidoscope Rings", float) = 0
        [MaterialToggle] _use_fractal_koch_snowflake("Koch Snowflake", float) = 0
        [MaterialToggle] _use_fractal_sierpinski_carpet("Sierpinski Carpet", float) = 0
        [MaterialToggle] _use_fractal_box_fold("Box Fold", float) = 0
        [MaterialToggle] _use_fractal_apollonian("Apollonian", float) = 0
        [MaterialToggle] _use_fractal_kali("Kali", float) = 0
        [MaterialToggle] _use_fractal_glow_rings("Glow Rings", float) = 0

        [Header(Fractal Infinite Zoom)]
        [MaterialToggle] _use_zoom_sierpinski_triangle("Sierpinski Triangle Zoom", float) = 0
        [MaterialToggle] _use_zoom_sierpinski_carpet("Sierpinski Carpet Zoom", float) = 0
        [MaterialToggle] _use_zoom_koch_snowflake("Koch Snowflake Zoom", float) = 0

        [Header(Fractal Spiral)]
        [MaterialToggle] _use_log_spiral("Log Spiral", float) = 0
        [MaterialToggle] _use_spiral_kifs("Spiral KIFS", float) = 0

        [Header(Zellige)]
        [MaterialToggle] _use_zellige("Zellige", float) = 0
        _zellige_tile_density("Tile Density", float) = 4
        _zellige_line_width("Line Width", Range(0.005, 0.2)) = 0.05
        [IntRange] _zellige_segment_count("Kaleidoscope Segments", Range(2, 24)) = 8
        _zellige_rotation_speed("Rotation Speed (rad/s)", float) = 0.1
        _zellige_scroll_speed("Scroll Speed (cells/s)", float) = 0.2
        _zellige_contact_angle("Contact Angle (deg)", Range(22.5, 67.5)) = 45
        _zellige_contact_angle_amplitude("Contact Angle Amplitude (deg)", Range(0, 22.5)) = 15
        _zellige_contact_angle_speed("Contact Angle Speed", float) = 0.5

        [Header(Distance Gradient)]
        [MaterialToggle] _show_distance_gradient("Show Distance Gradient", float) = 0

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
            #include "Packages/com.amenone.shadermodules/Shaders/fractal.cginc"
            #include "Packages/com.amenone.shadermodules/Shaders/zellige.cginc"

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
                float _use_caustic;
                float _use_domain_warp;
                float _use_polar;
                float _use_rotate;
                float _use_spiral;
                float _use_fractal_kifs;
                float _use_fractal_kaleidoscope_rings;
                float _use_fractal_koch_snowflake;
                float _use_fractal_sierpinski_carpet;
                float _use_fractal_box_fold;
                float _use_fractal_apollonian;
                float _use_fractal_kali;
                float _use_fractal_glow_rings;
                float _use_zoom_sierpinski_triangle;
                float _use_zoom_sierpinski_carpet;
                float _use_zoom_koch_snowflake;
                float _use_log_spiral;
                float _use_spiral_kifs;
                float _use_zellige;
                float _zellige_tile_density;
                float _zellige_line_width;
                float _zellige_segment_count;
                float _zellige_rotation_speed;
                float _zellige_scroll_speed;
                float _zellige_contact_angle;
                float _zellige_contact_angle_amplitude;
                float _zellige_contact_angle_speed;
                float _show_distance_gradient;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            ZelligeStyle zellige_style_from_material()
            {
                ZelligeStyle style = zellige_default_style();
                style.tileDensity = _zellige_tile_density;
                style.lineWidth = _zellige_line_width;
                style.segmentCount = _zellige_segment_count;
                style.rotationSpeed = _zellige_rotation_speed;
                style.scrollSpeed = _zellige_scroll_speed;
                style.contactAngleDegrees = _zellige_contact_angle;
                style.contactAngleAmplitudeDegrees = _zellige_contact_angle_amplitude;
                style.contactAngleSpeed = _zellige_contact_angle_speed;
                return style;
            }

            float3 gradient_direction_color(float2 gradient)
            {
                float2 direction = gradient * rsqrt(max(dot(gradient, gradient), 1e-12));
                return float3(direction * 0.5 + 0.5, 1.0);
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
                if (_use_domain_warp)     color.rgb += domain_warp(uv * 4., 0.5, 4, 1.0, _Time.y);

                if (_use_caustic)
                {
                    float2 cuv1 = uv + float2(_Time.y * 0.05, _Time.y * 0.03);
                    float2 cuv2 = uv + float2(-_Time.y * 0.04, _Time.y * 0.06);
                    float2 cuv3 = uv + float2(_Time.y * 0.02, -_Time.y * 0.05);;
                    float v1 = voronoi(cuv1, 0.5, float2(0, 0)).x;
                    float v2 = voronoi(cuv2, 0.6, float2(0, 0)).x;
                    float v3 = voronoi(cuv3, 1, float2(0, 0)).x;
                    float3 col1 = float3(v1,v1,v1) * float3(2.3,.8,1.5);
                    float3 col2 = float3(v2,v2,v2) * float3(.9,1.8,1.6);
                    float3 col3 = float3(v3,v3,v3) * float3(1.2,1.,2.8);
                    color.rgb += pow(col1 * col2 * col3, 1.8) +0.15;
                }

                float2 p = uv * 2. - 1.;
                float2 distanceGradient;
                if (_use_fractal_kifs)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_kifs_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_kifs_color(p);
                    }
                }
                if (_use_fractal_kaleidoscope_rings)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_kaleidoscope_rings_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_kaleidoscope_rings_color(p);
                    }
                }
                if (_use_fractal_koch_snowflake)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_koch_snowflake_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_koch_snowflake_color(p);
                    }
                }
                if (_use_fractal_sierpinski_carpet)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_sierpinski_carpet_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_sierpinski_carpet_color(p);
                    }
                }
                if (_use_fractal_box_fold)             color.rgb += fractal_box_fold_color(p);
                if (_use_fractal_apollonian)           color.rgb += fractal_apollonian_color(p);
                if (_use_fractal_kali)                 color.rgb += fractal_kali_color(p);
                if (_use_fractal_glow_rings)           color.rgb += fractal_glow_rings_color(p);

                if (_use_zoom_sierpinski_triangle)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_zoom_sierpinski_triangle_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_zoom_sierpinski_triangle_color(p);
                    }
                }
                if (_use_zoom_sierpinski_carpet)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_zoom_sierpinski_carpet_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_zoom_sierpinski_carpet_color(p);
                    }
                }
                if (_use_zoom_koch_snowflake)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_zoom_koch_snowflake_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_zoom_koch_snowflake_color(p);
                    }
                }

                if (_use_log_spiral)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_log_spiral_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_log_spiral_color(p);
                    }
                }
                if (_use_spiral_kifs)
                {
                    if (_show_distance_gradient)
                    {
                        fractal_spiral_kifs_color(p, distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += fractal_spiral_kifs_color(p);
                    }
                }

                if (_use_zellige)
                {
                    if (_show_distance_gradient)
                    {
                        zellige_color(p, zellige_style_from_material(), distanceGradient);
                        color.rgb += gradient_direction_color(distanceGradient);
                    }
                    else
                    {
                        color.rgb += zellige_color(p, zellige_style_from_material());
                    }
                }



                return color;
            }
            ENDHLSL
        }
    }
}
