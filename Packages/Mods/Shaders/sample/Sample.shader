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

        [Header(Composite)]
        [MaterialToggle] _use_caustic("Caustic", float) = 0
        [MaterialToggle] _use_domain_warp("Domain Warp", float) = 0

        [Header(Fractal)]
        [MaterialToggle] _use_fractal_kifs("KIFS", float) = 0
        [MaterialToggle] _use_fractal_kaleidoscope_rings("Kaleidoscope Rings", float) = 0
        [MaterialToggle] _use_fractal_sierpinski_triangle("Sierpinski Triangle", float) = 0
        [MaterialToggle] _use_fractal_koch_snowflake("Koch Snowflake", float) = 0
        [MaterialToggle] _use_fractal_sierpinski_carpet("Sierpinski Carpet", float) = 0
        [MaterialToggle] _use_fractal_box_fold("Box Fold", float) = 0
        [MaterialToggle] _use_fractal_apollonian("Apollonian", float) = 0
        [MaterialToggle] _use_fractal_kali("Kali", float) = 0
        [MaterialToggle] _use_fractal_glow_rings("Glow Rings", float) = 0

        [Header(Fractal Spiral)]
        [MaterialToggle] _use_golden_spiral_tile("Golden Spiral Tile", float) = 0
        [MaterialToggle] _use_double_spiral("Double Spiral", float) = 0
        [MaterialToggle] _use_spiral_kifs("Spiral KIFS", float) = 0

        [Header(Arabesque)]
        [MaterialToggle] _use_arabesque_hexagon_star("Hexagon Star", float) = 0
        [MaterialToggle] _use_arabesque_square_star("Square Star", float) = 0
        [MaterialToggle] _use_karakusa_swirl("Karakusa Swirl", float) = 0

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
                float _use_fractal_sierpinski_triangle;
                float _use_fractal_koch_snowflake;
                float _use_fractal_sierpinski_carpet;
                float _use_fractal_box_fold;
                float _use_fractal_apollonian;
                float _use_fractal_kali;
                float _use_fractal_glow_rings;
                float _use_golden_spiral_tile;
                float _use_double_spiral;
                float _use_spiral_kifs;
                float _use_arabesque_hexagon_star;
                float _use_arabesque_square_star;
                float _use_karakusa_swirl;
            CBUFFER_END

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
                return OUT;
            }

            float oscillate_by_time(float center, float amplitude, float speed)
            {
                return center + amplitude * sin(_Time.y * speed);
            }

            float cycle_by_time(float rate, float period)
            {
                return fmod(_Time.y * rate, period);
            }

            float2 rotate_around_origin(float2 p, float radians)
            {
                return rotate(p + 0.5, radians / (2.0 * FRACTAL_PI)) - 0.5;
            }

            float edge_smoothing_width(float2 p)
            {
                float2 pixelSize = fwidth(p);
                return 0.75 * max(pixelSize.x, pixelSize.y);
            }

            float3 sample_fractal_kifs(float2 p)
            {
                float2 orbit = fractal_kifs(p * 1.3, 10, float2(0.5, 0.28), oscillate_by_time(0.62, 0.1, 0.3), 1.5);
                float3 tint = cosine_palette(0.3 * log(orbit.y + 0.05) + 0.1, float3(0.0, 0.2, 0.45));
                return float3(0.03, 0.04, 0.08) + tint * (0.85 * exp(-orbit.x * 260.0) + 0.1 * exp(-orbit.x * 45.0));
            }

            float3 sample_fractal_kaleidoscope_rings(float2 p)
            {
                float overallRotation = cycle_by_time(0.05, 2.0 * FRACTAL_PI);
                float2 rotated = rotate_around_origin(p * 1.15, overallRotation);
                float2 folded = fold_kaleidoscope(rotated, 6.0);
                float2 orbit = fractal_kifs_rings(folded, 8, float2(0.42, 0.16), oscillate_by_time(0.9, 0.12, 0.2), 1.35, 0.38);
                float3 tint = cosine_palette(0.35 * log(orbit.y + 0.05) + 0.62, float3(0.0, 0.1, 0.2));
                return float3(0.03, 0.03, 0.07) + tint * (0.8 * exp(-orbit.x * 240.0) + 0.1 * exp(-orbit.x * 40.0));
            }

            float3 sample_fractal_sierpinski_triangle(float2 p)
            {
                const float2 topVertex = float2(0.0, 1.0);
                float smoothing = edge_smoothing_width(p);
                float2 shifted = p * 1.05 + float2(0.0, 0.25);
                float2 zoomed = topVertex + (shifted - topVertex) * exp2(-cycle_by_time(0.12, 1.0));
                float2 fromTop = zoomed - topVertex;
                float distanceToTriangle = fractal_sierpinski_triangle(zoomed, 6);
                float fill = smoothstep(smoothing, -smoothing, distanceToTriangle);
                float hue = log2(length(fromTop) + 1e-4) + 0.25 * sin(3.0 * atan2(fromTop.x, -fromTop.y));
                float3 tint = cosine_palette(hue, float3(0.0, 0.15, 0.35));
                float3 ground = float3(0.03, 0.035, 0.07) + tint * 0.55 * exp(-max(distanceToTriangle, 0.0) * 45.0);
                return lerp(ground, tint, fill);
            }

            float3 sample_fractal_koch_snowflake(float2 p)
            {
                float2 rotated = rotate_around_origin(p, oscillate_by_time(0.0, 0.08, 0.25));
                float distanceToOutline = fractal_koch_snowflake(rotated * 0.62, 5);
                float3 tint = cosine_palette(0.6 * length(rotated) + cycle_by_time(0.08, 1.0) + 0.5, float3(0.0, 0.12, 0.3));
                float glow = exp(-distanceToOutline * 220.0) + 0.3 * exp(-distanceToOutline * 30.0) + 0.1 * exp(-distanceToOutline * 5.0);
                return float3(0.02, 0.035, 0.07) + tint * glow;
            }

            float3 sample_fractal_sierpinski_carpet(float2 p)
            {
                float smoothing = edge_smoothing_width(p);
                float2 scaled = p * 1.08;
                float distanceToCarpet = fractal_sierpinski_carpet(scaled, 5);
                float fill = smoothstep(smoothing, -smoothing, distanceToCarpet);
                float3 tint = cosine_palette(0.22 * (scaled.x - scaled.y) + cycle_by_time(0.05, 1.0) + 0.08, float3(0.0, 0.33, 0.6));
                return lerp(float3(0.08, 0.075, 0.15), tint, fill);
            }

            float3 sample_fractal_box_fold(float2 p)
            {
                float3 orbit = fractal_box_fold(p * 2.5, 12, oscillate_by_time(-1.75, 0.08, 0.3));
                float bounded = 1.0 - smoothstep(4.0, 40.0, orbit.z);
                float3 tint = cosine_palette(0.16 * log(orbit.x + 1e-3) + 0.58, float3(0.0, 0.1, 0.22));
                float3 shaded = tint * (0.18 + 0.82 * bounded);
                shaded += float3(0.9, 0.95, 1.0) * exp(-orbit.y * 26.0) * 0.45 * bounded;
                return shaded * 0.92 + float3(0.02, 0.02, 0.04);
            }

            float3 sample_fractal_apollonian(float2 p)
            {
                float2 shifted = p * 1.15 + float2(oscillate_by_time(0.0, 0.08, 0.2), 0.0);
                float2 orbit = fractal_apollonian(shifted, 8, oscillate_by_time(1.18, 0.07, 0.25));
                float3 tint = cosine_palette(0.28 * log(orbit.y + 1e-3) + 0.95, float3(0.0, 0.08, 0.18));
                float3 shaded = tint * (0.16 + 0.5 * smoothstep(0.0, 0.6, sqrt(orbit.y)));
                return shaded + float3(1.0, 0.92, 0.8) * exp(-orbit.x * 260.0) * 0.8;
            }

            float3 sample_fractal_kali(float2 p)
            {
                float2 offset = float2(oscillate_by_time(0.85, 0.025, 0.3), oscillate_by_time(0.52, 0.025, 0.23));
                float2 orbit = fractal_kali(p * 1.25 + float2(0.3, 0.15), 12, offset);
                float3 tint = cosine_palette(0.22 * log(orbit.y + 1e-3) + 0.72, float3(0.0, 0.12, 0.28));
                return float3(0.02, 0.02, 0.05) + tint * (0.2 + 2.6 * orbit.x * orbit.x) + float3(1.0, 0.9, 0.8) * exp(-orbit.y * 9.0) * 0.5;
            }

            float3 sample_fractal_glow_rings(float2 p)
            {
                return fractal_glow_rings(p, 4, cycle_by_time(0.6, 2.0 * FRACTAL_PI), cycle_by_time(0.12, 1.0), float3(0.263, 0.416, 0.557));
            }

            float3 sample_golden_spiral_tile(float2 p)
            {
                const float2 target = float2(0.22, -0.14);
                float2 coord = golden_spiral_coord(p, target);
                coord.y += cycle_by_time(0.04, 1.0);
                float2 fromTileCenter = abs(spiral_tile(coord, 4.0));
                float tileEdge = max(fromTileCenter.x, fromTileCenter.y);
                float tile = smoothstep(0.47, 0.41, tileEdge);
                float3 tint = cosine_palette(coord.y + 0.25 * coord.x + 0.1, float3(0.0, 0.12, 0.3));
                float3 shaded = lerp(float3(0.03, 0.035, 0.07), tint * (0.55 + 0.9 * (0.5 - tileEdge)), tile);
                shaded += float3(1.0, 0.92, 0.75) * exp(-log_spiral_line_distance(coord, FRACTAL_GOLDEN_RATIO) * 45.0);
                return lerp(tint * 0.45, shaded, smoothstep(0.004, 0.05, length(p - target)));
            }

            float3 sample_double_spiral(float2 p)
            {
                const float2 sink = float2(0.5, 0.12);
                const float2 source = float2(-0.5, -0.12);
                float2 coord = double_spiral_coord(p, sink, source, exp(0.32));
                coord.y -= cycle_by_time(0.05, 1.0);
                float fromTileCenter = length(spiral_tile(coord, 3.0));
                float disc = smoothstep(0.42, 0.34, fromTileCenter);
                float3 tint = cosine_palette(coord.y + 0.25 * coord.x + 0.55, float3(0.0, 0.33, 0.6));
                float3 shaded = lerp(float3(0.03, 0.035, 0.07), tint * (1.15 - 1.2 * fromTileCenter), disc);
                return lerp(tint * 0.35, shaded, smoothstep(0.0, 0.05, min(distance(p, sink), distance(p, source))));
            }

            float3 sample_spiral_kifs(float2 p)
            {
                const float2 target = float2(-0.2, 0.1);
                float2 coord = golden_spiral_coord(p, target);
                coord.y += cycle_by_time(0.03, 1.0);
                float2 tile = spiral_tile(coord, 2.0) * 2.6;
                float2 orbit = fractal_kifs(tile, 6, float2(0.5, 0.28), oscillate_by_time(0.62, 0.1, 0.3), 1.5);
                float3 tint = cosine_palette(coord.y + 0.25 * coord.x + 0.3 * log(orbit.y + 0.05), float3(0.0, 0.2, 0.45));
                float3 ground = float3(0.03, 0.04, 0.08);
                float3 shaded = ground + tint * (0.85 * exp(-orbit.x * 45.0) + 0.12 * exp(-orbit.x * 9.0));
                return lerp(ground, shaded, smoothstep(0.004, 0.06, length(p - target)));
            }

            float3 sample_arabesque_hexagon_star(float2 p)
            {
                const float strapWidth = 0.035;
                float2 scaled = p * 2.2;
                float smoothing = edge_smoothing_width(scaled);
                float signedDistance = arabesque_hexagon_star(scaled, oscillate_by_time(1.05, 0.3, 0.35));
                float strapDistance = abs(signedDistance);
                float3 shaded = lerp(float3(0.93, 0.88, 0.75), float3(0.04, 0.33, 0.47), smoothstep(-smoothing, smoothing, signedDistance));
                shaded = lerp(shaded, float3(0.86, 0.63, 0.2), 1.0 - smoothstep(strapWidth - smoothing, strapWidth + smoothing, strapDistance));
                return lerp(shaded, float3(0.07, 0.05, 0.08), 0.85 * (1.0 - smoothstep(smoothing, 2.5 * smoothing, abs(strapDistance - strapWidth))));
            }

            float3 sample_arabesque_square_star(float2 p)
            {
                const float strapWidth = 0.03;
                float2 scaled = p * 2.0;
                float smoothing = edge_smoothing_width(scaled);
                float contactAngle = oscillate_by_time(1.18, 0.25, 0.3);
                float straightDistance = arabesque_square_star(scaled, contactAngle);
                float diagonalDistance = arabesque_square_star(rotate_around_origin(scaled, FRACTAL_PI / 4.0) * 0.70710678, contactAngle) * 1.41421356;
                float insideStraight = smoothstep(-smoothing, smoothing, straightDistance);
                float insideDiagonal = smoothstep(-smoothing, smoothing, diagonalDistance);
                float3 shaded = lerp(float3(0.94, 0.9, 0.8), float3(0.1, 0.2, 0.5), abs(insideStraight - insideDiagonal));
                shaded = lerp(shaded, float3(0.68, 0.24, 0.16), insideStraight * insideDiagonal);
                float strapDistance = min(abs(straightDistance), abs(diagonalDistance));
                shaded = lerp(shaded, float3(0.95, 0.93, 0.86), 1.0 - smoothstep(strapWidth - smoothing, strapWidth + smoothing, strapDistance));
                return lerp(shaded, float3(0.06, 0.06, 0.1), 0.85 * (1.0 - smoothstep(smoothing, 2.5 * smoothing, abs(strapDistance - strapWidth))));
            }

            float3 sample_karakusa_swirl(float2 p)
            {
                const float vineWidth = 0.04;
                float2 scaled = p * 2.2;
                float smoothing = edge_smoothing_width(scaled);
                float vineDistance = karakusa_swirl(scaled, cycle_by_time(0.08, 1.0));
                float vine = 1.0 - smoothstep(vineWidth - smoothing, vineWidth + smoothing, vineDistance);
                return lerp(float3(0.03, 0.27, 0.19), float3(0.94, 0.95, 0.9), vine);
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
                if (_use_fractal_kifs)                 color.rgb += sample_fractal_kifs(p);
                if (_use_fractal_kaleidoscope_rings)   color.rgb += sample_fractal_kaleidoscope_rings(p);
                if (_use_fractal_sierpinski_triangle)  color.rgb += sample_fractal_sierpinski_triangle(p);
                if (_use_fractal_koch_snowflake)       color.rgb += sample_fractal_koch_snowflake(p);
                if (_use_fractal_sierpinski_carpet)    color.rgb += sample_fractal_sierpinski_carpet(p);
                if (_use_fractal_box_fold)             color.rgb += sample_fractal_box_fold(p);
                if (_use_fractal_apollonian)           color.rgb += sample_fractal_apollonian(p);
                if (_use_fractal_kali)                 color.rgb += sample_fractal_kali(p);
                if (_use_fractal_glow_rings)           color.rgb += sample_fractal_glow_rings(p);

                if (_use_golden_spiral_tile)  color.rgb += sample_golden_spiral_tile(p);
                if (_use_double_spiral)       color.rgb += sample_double_spiral(p);
                if (_use_spiral_kifs)         color.rgb += sample_spiral_kifs(p);

                if (_use_arabesque_hexagon_star)  color.rgb += sample_arabesque_hexagon_star(p);
                if (_use_arabesque_square_star)   color.rgb += sample_arabesque_square_star(p);
                if (_use_karakusa_swirl)          color.rgb += sample_karakusa_swirl(p);



                return color;
            }
            ENDHLSL
        }
    }
}
