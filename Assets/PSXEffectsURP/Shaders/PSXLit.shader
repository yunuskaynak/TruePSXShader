// ============================================================
//  PSX/Lit - PlayStation 1 tarzi URP shader
//  Vertex snapping, affine texture mapping, Gouraud (per-vertex)
//  aydinlatma, lightmap, golge ve sis destekli.
// ============================================================
Shader "PSX/Lit"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Color("Color", Color) = (1,1,1,1)
        _Cutoff("Alpha Cutoff", Range(0,1)) = 0.5

        [Toggle(_PSX_UNLIT)] _Unlit("Unlit", Float) = 0
        [Toggle] _VertexColors("Use Vertex Colors", Float) = 1
        _SnapScale("Vertex Snap Scale", Range(0,4)) = 1
        _AffineOverride("Affine Override (-1 = Global)", Float) = -1
        [Toggle] _DrawDistInfluence("Draw Distance Influence", Float) = 1

        [KeywordEnum(Vertex, Fragment)] _PSX_DIFF("Diffuse Model", Float) = 0

        [Toggle(_PSX_TEX_QUANT)] _TexQuant("Texture Color Quantization", Float) = 0
        _TexBits("Texture Bits Per Channel", Range(1,8)) = 5

        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalStrength("Normal Strength", Range(0,2)) = 1

        _SpecularMap("Specular Map", 2D) = "white" {}
        _Specular("Specular Amount", Range(0,4)) = 0
        _Shininess("Shininess", Range(1,128)) = 20
        [KeywordEnum(Gouraud, Phong)] _PSX_SPEC("Specular Model", Float) = 0

        _EmissionMap("Emission Map", 2D) = "white" {}
        [HDR] _EmissionColor("Emission Color", Color) = (0,0,0,1)

        _Cube("Cubemap", Cube) = "" {}
        _CubeAmount("Cubemap Amount", Range(0,2)) = 0.5

        _LODTex("LOD Texture", 2D) = "white" {}
        _LODAmt("LOD Distance", Float) = 0

        // ShaderGUI tarafindan yonetilir
        [HideInInspector] _RenderMode("__mode", Float) = 0
        [HideInInspector] _SrcBlend("__src", Float) = 1
        [HideInInspector] _DstBlend("__dst", Float) = 0
        [HideInInspector] _ZWrite("__zw", Float) = 1
        [HideInInspector] _Cull("__cull", Float) = 2
        [HideInInspector] _BlendOp("__op", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
            "IgnoreProjector" = "True"
        }
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "PSXCommon.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            half4 _Color;
            half4 _EmissionColor;
            half _Cutoff;
            half _VertexColors;
            half _SnapScale;
            half _AffineOverride;
            half _DrawDistInfluence;
            half _TexBits;
            half _NormalStrength;
            half _Specular;
            half _Shininess;
            half _CubeAmount;
            half _RenderMode;
            float _LODAmt;
        CBUFFER_END

        TEXTURE2D(_MainTex);      SAMPLER(sampler_MainTex);
        TEXTURE2D(_NormalMap);    SAMPLER(sampler_NormalMap);
        TEXTURE2D(_SpecularMap);  SAMPLER(sampler_SpecularMap);
        TEXTURE2D(_EmissionMap);  SAMPLER(sampler_EmissionMap);
        TEXTURECUBE(_Cube);       SAMPLER(sampler_Cube);
        TEXTURE2D(_LODTex);       SAMPLER(sampler_LODTex);

        half3 PSXQuantizeTex(half3 rgb)
        {
        #if defined(_PSX_TEX_QUANT)
            float levels = exp2(_TexBits) - 1.0;
            rgb = floor(rgb * levels + 0.5) / levels;
        #endif
            return rgb;
        }
        ENDHLSL

        // ====================================================
        //  Forward Lit
        // ====================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Blend [_SrcBlend] [_DstBlend]
            BlendOp [_BlendOp]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex LitVert
            #pragma fragment LitFrag

            // --- URP ---
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP _FORWARD_PLUS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fog

            // --- PSX ---
            #pragma shader_feature_local _PSX_UNLIT
            #pragma shader_feature_local _PSX_DIFF_VERTEX _PSX_DIFF_FRAGMENT
            #pragma shader_feature_local _PSX_SPEC_GOURAUD _PSX_SPEC_PHONG
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PSX_CUBEMAP
            #pragma shader_feature_local _PSX_TEX_QUANT
            #pragma shader_feature_local _PSX_LOD_TEX
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                float2 staticLightmapUV : TEXCOORD1;
                float4 color      : COLOR;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;   // perspektif-dogru uv (ham)
                float3 affineUV   : TEXCOORD1;   // uv*w, w
                float3 positionWS : TEXCOORD2;
                half3 normalWS    : TEXCOORD3;
                half4 color       : COLOR;
                half3 mainDiff    : TEXCOORD4;   // ana isik vertex diffuse
                half3 addDiff     : TEXCOORD5;   // ek isiklar vertex diffuse
                half3 spec        : TEXCOORD6;   // Gouraud specular
                half3 fogFlag     : TEXCOORD7;   // x = fog, y = drawdist, z = LOD bayragi
                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);
            #if defined(_NORMALMAP)
                half4 tangentWS   : TEXCOORD9;
            #endif
            };

            // Ek isiklar (point/spot/ek directional). screenUV: cluster (Forward+)
            // dongusunun ihtiyac duydugu normalize ekran koordinati.
            half3 PSXAdditionalLights(float3 positionWS, half3 normalWS, float2 screenUV)
            {
                half3 c = half3(0, 0, 0);
            #if defined(_ADDITIONAL_LIGHTS) || defined(_ADDITIONAL_LIGHTS_VERTEX) || USE_CLUSTER_LIGHT_LOOP || USE_FORWARD_PLUS
                #if USE_CLUSTER_LIGHT_LOOP || USE_FORWARD_PLUS
                    // Forward+ / cluster isik dongusu
                    InputData inputData = (InputData)0;
                    inputData.normalizedScreenSpaceUV = screenUV;
                    inputData.positionWS = positionWS;

                    #ifdef URP_FP_DIRECTIONAL_LIGHTS_COUNT
                    for (uint dIdx = 0; dIdx < URP_FP_DIRECTIONAL_LIGHTS_COUNT; dIdx++)
                    {
                        Light dl = GetAdditionalLight(dIdx, positionWS);
                        c += dl.color * (dl.distanceAttenuation * saturate(dot(normalWS, dl.direction)));
                    }
                    #endif

                    uint pixelLightCount = GetAdditionalLightsCount();
                    LIGHT_LOOP_BEGIN(pixelLightCount)
                        Light l = GetAdditionalLight(lightIndex, positionWS);
                        c += l.color * (l.distanceAttenuation * saturate(dot(normalWS, l.direction)));
                    LIGHT_LOOP_END
                #else
                    uint count = GetAdditionalLightsCount();
                    for (uint li = 0u; li < count; li++)
                    {
                        Light l = GetAdditionalLight(li, positionWS);
                        c += l.color * (l.distanceAttenuation * saturate(dot(normalWS, l.direction)));
                    }
                #endif
            #endif
                return c;
            }

            Varyings LitVert(Attributes v)
            {
                Varyings o = (Varyings)0;

                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                positionWS = PSXWorldSnap(positionWS);
                float4 positionCS = TransformWorldToHClip(positionWS);
                positionCS = PSXSnapClipPos(positionCS, _SnapScale);

                o.positionCS = positionCS;
                o.positionWS = positionWS;
                o.uv = v.uv;
                o.affineUV = PSXAffineUV(v.uv, positionCS);

                half3 normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.normalWS = normalWS;
            #if defined(_NORMALMAP)
                half3 tangentWS = TransformObjectToWorldDir(v.tangentOS.xyz);
                o.tangentWS = half4(tangentWS, v.tangentOS.w * GetOddNegativeScale());
            #endif

                o.color = _VertexColors > 0.5 ? v.color : half4(1, 1, 1, 1);

                half3 mainDiff = half3(0, 0, 0);
                half3 addDiff  = half3(0, 0, 0);
                half3 spec     = half3(0, 0, 0);
            #if !defined(_PSX_UNLIT)
                Light mainLight = GetMainLight();
                #if defined(_PSX_DIFF_VERTEX)
                    mainDiff = mainLight.color * saturate(dot(normalWS, mainLight.direction));

                    // Vertex (Gouraud) modunda ek isiklar da vertex'te hesaplanir
                    float2 suv = positionCS.xy / max(abs(positionCS.w), 0.00001) * 0.5 + 0.5;
                    #if UNITY_UV_STARTS_AT_TOP
                        suv.y = 1.0 - suv.y;
                    #endif
                    addDiff = PSXAdditionalLights(positionWS, normalWS, suv);
                #endif

                #if defined(_PSX_SPEC_GOURAUD)
                if (_Specular > 0.0)
                {
                    float3 viewDir = normalize(GetWorldSpaceViewDir(positionWS));
                    float3 r = reflect(-mainLight.direction, normalWS);
                    spec = mainLight.color * pow(saturate(dot(r, viewDir)), _Shininess);
                }
                #endif
            #endif
                o.mainDiff = mainDiff;
                o.addDiff = addDiff;
                o.spec = spec;

                half lodFlag = (_LODAmt > 0.0 &&
                                distance(positionWS, _WorldSpaceCameraPos) > _LODAmt) ? 1.0 : 0.0;
                o.fogFlag = half3(ComputeFogFactor(positionCS.z),
                                  PSXDrawDistanceFlag(positionWS, _DrawDistInfluence),
                                  lodFlag);

                OUTPUT_LIGHTMAP_UV(v.staticLightmapUV, unity_LightmapST, o.staticLightmapUV);
                OUTPUT_SH(normalWS, o.vertexSH);

                return o;
            }

            half4 LitFrag(Varyings i) : SV_Target
            {
                // Cizim mesafesi disinda kalan poligonlari at
                clip(0.5 - i.fogFlag.y);

                float2 uvRaw = PSXResolveUV(i.uv, i.affineUV, _AffineOverride);
                float2 uv = uvRaw * _MainTex_ST.xy + _MainTex_ST.zw;

                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

                // Mesafe LOD dokusu (orijinaldeki LOD Texture / LOD Amount)
            #if defined(_PSX_LOD_TEX)
                half4 lodTex = SAMPLE_TEXTURE2D(_LODTex, sampler_LODTex, uv);
                albedo = lerp(albedo, lodTex, i.fogFlag.z);
            #endif

                albedo.rgb = PSXQuantizeTex(albedo.rgb);

                half4 tint = _Color * i.color;
                half alpha = albedo.a * tint.a;
            #if defined(_ALPHATEST_ON)
                clip(alpha - _Cutoff);
            #endif

                half3 col;
            #if defined(_PSX_UNLIT)
                col = albedo.rgb * tint.rgb;
            #else
                half3 normalWS = normalize(i.normalWS);
                #if defined(_NORMALMAP)
                    half3 tangentWS = normalize(i.tangentWS.xyz);
                    half3 bitangentWS = normalize(cross(normalWS, tangentWS)) * i.tangentWS.w;
                    half3 nTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv), _NormalStrength);
                    normalWS = normalize(mul(nTS, half3x3(tangentWS, bitangentWS, normalWS)));
                #endif

                float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half atten = mainLight.shadowAttenuation;

                half3 mainDiff;
                half3 addLight;
                #if defined(_PSX_DIFF_FRAGMENT)
                    // Fragment modunda TUM isiklar per-pixel hesaplanir
                    mainDiff = mainLight.color * saturate(dot(normalWS, mainLight.direction));
                    addLight = PSXAdditionalLights(i.positionWS, normalWS,
                                                   GetNormalizedScreenSpaceUV(i.positionCS));
                #else
                    // Vertex (Gouraud) modunda tum isiklar vertex'ten gelir (PS1 dogrulugu)
                    mainDiff = i.mainDiff;
                    addLight = i.addDiff;
                #endif

                half3 bakedGI = SAMPLE_GI(i.staticLightmapUV, i.vertexSH, normalWS);

                half3 lighting;
                if (_PSX_ShadowMode > 0.5)
                    lighting = mainDiff + addLight + bakedGI;           // PSX: golge sonra cikarilir
                else
                    lighting = mainDiff * atten + addLight + bakedGI;   // Normal: carpimsal golge

                col = albedo.rgb * tint.rgb * lighting;

                // Specular
                half3 spec = i.spec;
                #if defined(_PSX_SPEC_PHONG)
                if (_Specular > 0.0)
                {
                    float3 viewDir = normalize(GetWorldSpaceViewDir(i.positionWS));
                    float3 r = reflect(-mainLight.direction, normalWS);
                    spec = mainLight.color * pow(saturate(dot(r, viewDir)), _Shininess);
                }
                #endif
                if (_Specular > 0.0)
                {
                    half specMask = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, uv).r;
                    col += spec * specMask * _Specular * (_PSX_ShadowMode > 0.5 ? 1.0 : atten);
                }

                // PSX tarzi cikarimsal golge
                if (_PSX_ShadowMode > 0.5)
                    col -= (1.0 - atten) * _PSX_ShadowIntensity;

                // Cubemap yansima (PS1 sahte env-map)
                #if defined(_PSX_CUBEMAP)
                {
                    half3 viewDir = normalize(GetWorldSpaceViewDir(i.positionWS));
                    half3 refl = reflect(-viewDir, normalWS);
                    col += SAMPLE_TEXTURECUBE(_Cube, sampler_Cube, refl).rgb * _CubeAmount;
                }
                #endif
            #endif // _PSX_UNLIT

                // Emission
                col += SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;

                col = max(col, 0.0);
                col = MixFog(col, i.fogFlag.x);

                return half4(col, alpha);
            }
            ENDHLSL
        }

        // ====================================================
        //  Shadow Caster
        // ====================================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowVert
            #pragma fragment ShadowFrag
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            Varyings ShadowVert(Attributes v)
            {
                Varyings o;
                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                positionWS = PSXWorldSnap(positionWS);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);

            #if defined(_CASTING_PUNCTUAL_LIGHT_SHADOW)
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
                float3 lightDirectionWS = _LightDirection;
            #endif

                float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
            #if UNITY_REVERSED_Z
                positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #else
                positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
            #endif
                o.positionCS = positionCS;
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                return o;
            }

            half4 ShadowFrag(Varyings i) : SV_Target
            {
            #if defined(_ALPHATEST_ON)
                half a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).a * _Color.a;
                clip(a - _Cutoff);
            #endif
                return 0;
            }
            ENDHLSL
        }

        // ====================================================
        //  Depth Only
        // ====================================================
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthVert
            #pragma fragment DepthFrag
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            };

            Varyings DepthVert(Attributes v)
            {
                Varyings o;
                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                positionWS = PSXWorldSnap(positionWS);
                float4 positionCS = TransformWorldToHClip(positionWS);
                o.positionCS = PSXSnapClipPos(positionCS, _SnapScale);
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                return o;
            }

            half4 DepthFrag(Varyings i) : SV_Target
            {
            #if defined(_ALPHATEST_ON)
                half a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).a * _Color.a;
                clip(a - _Cutoff);
            #endif
                return 0;
            }
            ENDHLSL
        }

        // ====================================================
        //  Depth Normals (SSAO vb. icin)
        // ====================================================
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }

            ZWrite On
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthNormalsVert
            #pragma fragment DepthNormalsFrag
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                half3 normalWS    : TEXCOORD1;
            };

            Varyings DepthNormalsVert(Attributes v)
            {
                Varyings o;
                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                positionWS = PSXWorldSnap(positionWS);
                float4 positionCS = TransformWorldToHClip(positionWS);
                o.positionCS = PSXSnapClipPos(positionCS, _SnapScale);
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                return o;
            }

            half4 DepthNormalsFrag(Varyings i) : SV_Target
            {
            #if defined(_ALPHATEST_ON)
                half a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv).a * _Color.a;
                clip(a - _Cutoff);
            #endif
                return half4(normalize(i.normalWS), 0.0);
            }
            ENDHLSL
        }

        // ====================================================
        //  Meta (lightmap pisirme)
        // ====================================================
        Pass
        {
            Name "Meta"
            Tags { "LightMode" = "Meta" }

            Cull Off

            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex MetaVert
            #pragma fragment MetaFrag
            #pragma shader_feature EDITOR_VISUALIZATION

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv0        : TEXCOORD0;
                float2 uv1        : TEXCOORD1;
                float2 uv2        : TEXCOORD2;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
            #ifdef EDITOR_VISUALIZATION
                float2 vizUV      : TEXCOORD1;
                float4 lightCoord : TEXCOORD2;
            #endif
            };

            Varyings MetaVert(Attributes v)
            {
                Varyings o = (Varyings)0;
                o.positionCS = UnityMetaVertexPosition(v.positionOS.xyz, v.uv1, v.uv2);
                o.uv = v.uv0 * _MainTex_ST.xy + _MainTex_ST.zw;
            #ifdef EDITOR_VISUALIZATION
                UnityEditorVizData(v.positionOS.xyz, v.uv0, v.uv1, v.uv2, o.vizUV, o.lightCoord);
            #endif
                return o;
            }

            half4 MetaFrag(Varyings i) : SV_Target
            {
                UnityMetaInput metaInput = (UnityMetaInput)0;
                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * _Color;
                metaInput.Albedo = albedo.rgb;
                metaInput.Emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, i.uv).rgb * _EmissionColor.rgb;
            #ifdef EDITOR_VISUALIZATION
                metaInput.VizUV = i.vizUV;
                metaInput.LightCoord = i.lightCoord;
            #endif
                return UnityMetaFragment(metaInput);
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "PSXLitShaderGUI"
}
