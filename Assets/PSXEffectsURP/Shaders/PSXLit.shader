// ============================================================
//  PSX/Lit - PlayStation 1 tarzi URP shader
//  Vertex snapping, affine texture mapping, Gouraud (per-vertex)
//  aydinlatma, lightmap, golge ve sis destekli.
//
//  Interpolator butcesi: temel varyant 8 slot (TEXCOORD0-7).
//  Normal Map acikken 9 olur (TEXCOORD8) - normal map zaten
//  PS1 donemi disi bir kolaylik ozelligidir.
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
        [Toggle(_PSX_MODULATE128)] _Modulate128("PS1 Vertex Colour Modulation (128 = neutral)", Float) = 0
        [Toggle(_PSX_AFFINE_SHADING)] _AffineShading("Affine Vertex Shading", Float) = 0
        _SnapScale("Vertex Snap Scale", Range(0,4)) = 1
        _AffineOverride("Affine Override (-1 = Global)", Float) = -1
        [Toggle] _DrawDistInfluence("Draw Distance Influence", Float) = 1

        [KeywordEnum(Vertex, Fragment)] _PSX_DIFF("Diffuse Model", Float) = 0

        [Toggle(_PSX_TEX_QUANT)] _TexQuant("Texture Color Quantization", Float) = 0
        _TexBits("Texture Bits Per Channel", Range(1,8)) = 5
        [Toggle(_PSX_NO_DITHER)] _NoDither("Raw Texture (No Dither)", Float) = 0

        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalStrength("Normal Strength", Range(0,2)) = 1

        _SpecularMap("Specular Map", 2D) = "white" {}
        _Specular("Specular Amount", Range(0,4)) = 0
        _Shininess("Shininess", Range(1,128)) = 20
        [KeywordEnum(Gouraud, Phong)] _PSX_SPEC("Specular Model", Float) = 0

        _MetallicMap("Metallic Map", 2D) = "white" {}
        _Metallic("Metallic", Range(0,1)) = 0
        _Smoothness("Reflection Smoothness", Range(0,1)) = 1
        _MetallicTint("Reflection Tint By Albedo", Range(0,1)) = 1
        _ReflectionIntensity("Reflection Intensity", Range(0,2)) = 1
        [Toggle] _MetalUnlit("Metal Ignores Lighting", Float) = 1

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
            half _Metallic;
            half _Smoothness;
            half _MetallicTint;
            half _ReflectionIntensity;
            half _MetalUnlit;
            half _CubeAmount;
            half _RenderMode;
            float _LODAmt;
        CBUFFER_END

        TEXTURE2D(_MainTex);      SAMPLER(sampler_MainTex);
        TEXTURE2D(_NormalMap);    SAMPLER(sampler_NormalMap);
        TEXTURE2D(_SpecularMap);  SAMPLER(sampler_SpecularMap);
        TEXTURE2D(_MetallicMap);  SAMPLER(sampler_MetallicMap);
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
            #pragma shader_feature_local _PSX_MODULATE128
            #pragma shader_feature_local _PSX_AFFINE_SHADING
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _PSX_METALLIC
            #pragma shader_feature_local _PSX_CUBEMAP
            #pragma shader_feature_local _PSX_TEX_QUANT
            #pragma shader_feature_local _PSX_LOD_TEX
            #pragma shader_feature_local_fragment _PSX_NO_DITHER
            #pragma shader_feature_local_fragment _ALPHATEST_ON

            // --- Reflection probe (URP Lit ile ayni set) ---
            // Bunlar OLMADAN Forward+ ta yansima calismaz: Forward+ ta URP
            // reflection probe'lari per-object BAGLAMAZ, cluster yapisinda
            // tutar ve yalnizca _REFLECTION_PROBE_BLENDING acikken
            // CalculateIrradianceFromReflectionProbes yolunu kullanir.
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile_fragment _ REFLECTION_PROBE_ROTATION

            // PS1 shader'inin screen-space reflection ile isi yok; kapatmak
            // hem varyant sayisini dusurur hem de GetScreenSpaceReflection
            // bagimliligini tamamen kaldirir.
            #define _SCREENSPACEREFLECTIONS_OFF 1

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ------------------------------------------------------------
            //  Ortam yansimasi ornekleme.
            //
            //  Materyale bir Cubemap atanmissa onu kullanir (PS1'in sahte
            //  env-map hilesi). ATANMAMISSA URP'nin kendi
            //  GlossyEnvironmentReflection'ina duser - bu fonksiyon
            //  Forward'da unity_SpecCube0'i, Forward+ ta ise cluster'lanmis
            //  reflection probe'lari kullanir. Elle unity_SpecCube0
            //  ornekleyen bir kod Forward+ ta CALISMAZ.
            //
            //  smoothness = 1 -> mip 0 = keskin ayna
            //  smoothness = 0 -> en bulanik mip = mat metal
            // ------------------------------------------------------------
            half3 PSXSampleEnv(half3 reflDir, half smoothness, float3 positionWS, float2 screenUV)
            {
                half perceptualRoughness = 1.0h - saturate(smoothness);

            #if defined(_PSX_CUBEMAP)
                half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
                half3 env = SAMPLE_TEXTURECUBE_LOD(_Cube, sampler_Cube, reflDir, mip).rgb;
            #else
                half3 env = GlossyEnvironmentReflection(reflDir, positionWS, perceptualRoughness, 1.0h, screenUV);
            #endif

                // Skybox'taki gunes / HDR probe yansimayi patlatabiliyor;
                // bu carpan onu kisip PS1 tonuna cekmeye yarar.
                return env * _ReflectionIntensity;
            }

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float4 tangentOS  : TANGENT;
                float2 uv         : TEXCOORD0;
                float2 staticLightmapUV : TEXCOORD1;
                float4 color      : COLOR;
            };

            // ----------------------------------------------------------
            //  Paketlenmis varyings - temel varyant 8 interpolator.
            //  Onceki surum 11 slot kullaniyordu ve target 3.5'in
            //  garanti ettigi 8 slotu asiyordu (GLES3.0'da kirilir).
            // ----------------------------------------------------------
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uvPack     : TEXCOORD0;   // xy = perspektif uv, zw = affine uv * w
                float4 wsAffineW  : TEXCOORD1;   // xyz = positionWS,   w  = affine w
                half4  nrmFog     : TEXCOORD2;   // xyz = normalWS,     w  = fog faktoru
                half4  color      : TEXCOORD3;   // vertex rengi (rgb) + alpha
                half4  mainDiffCull : TEXCOORD4; // rgb = ana isik diffuse, a = cull bayragi
                half4  addDiffLod : TEXCOORD5;   // rgb = ek isik diffuse,  a = LOD bayragi
                half4  specTanSign : TEXCOORD6;  // rgb = Gouraud specular, a = tangent isareti
                DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 7);
            #if defined(_NORMALMAP)
                half3 tangentWS   : TEXCOORD8;
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

                float3 affine = PSXAffineUV(v.uv, positionCS);
                o.uvPack    = float4(v.uv, affine.xy);
                o.wsAffineW = float4(positionWS, affine.z);

                half3 normalWS = TransformObjectToWorldNormal(v.normalOS);
                half tangentSign = 0.0;
            #if defined(_NORMALMAP)
                o.tangentWS = TransformObjectToWorldDir(v.tangentOS.xyz);
                tangentSign = v.tangentOS.w * GetOddNegativeScale();
            #endif

                half4 vcol = _VertexColors > 0.5 ? (half4)v.color : half4(1, 1, 1, 1);

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

                // ----------------------------------------------------
                //  Affine vertex shading: donanimda Gouraud renkleri de
                //  UV'ler gibi perspektif duzeltmesi GORMEZ. Ayni uv*w /
                //  w hilesini renklere uygulariz - ekstra interpolator
                //  gerekmez, cunku w zaten wsAffineW.w'de tasiniyor.
                // ----------------------------------------------------
            #if defined(_PSX_AFFINE_SHADING)
                {
                    float aw = affine.z;
                    vcol.rgb *= aw;
                    mainDiff *= aw;
                    addDiff  *= aw;
                    spec     *= aw;
                }
            #endif

                half cullFlag = PSXCullFlag(positionWS, positionCS.w, _DrawDistInfluence);
                half lodFlag  = (_LODAmt > 0.0 &&
                                 distance(positionWS, _WorldSpaceCameraPos) > _LODAmt) ? 1.0 : 0.0;

                o.nrmFog       = half4(normalWS, (half)PSXFogFactor(positionCS));
                o.color        = vcol;
                o.mainDiffCull = half4(mainDiff, cullFlag);
                o.addDiffLod   = half4(addDiff, lodFlag);
                o.specTanSign  = half4(spec, tangentSign);

                OUTPUT_LIGHTMAP_UV(v.staticLightmapUV, unity_LightmapST, o.staticLightmapUV);
                OUTPUT_SH(normalWS, o.vertexSH);

                return o;
            }

            half4 LitFrag(Varyings i) : SV_Target
            {
                // Cizim mesafesi / yakin poligon reddi
                clip(0.5 - i.mainDiffCull.a);

                float3 positionWS = i.wsAffineW.xyz;
                float  affineW    = i.wsAffineW.w;

                float2 uvRaw = PSXResolveUV(i.uvPack.xy, float3(i.uvPack.zw, affineW), _AffineOverride);
                float2 uv = uvRaw * _MainTex_ST.xy + _MainTex_ST.zw;

                // Vertex renkleri / vertex aydinlatmasi
                half4 vcol     = i.color;
                half3 mainDiffV = i.mainDiffCull.rgb;
                half3 addDiffV  = i.addDiffLod.rgb;
                half3 specV     = i.specTanSign.rgb;

            #if defined(_PSX_AFFINE_SHADING)
                {
                    float invAw = 1.0 / max(abs(affineW), 0.00001);
                    vcol.rgb  *= invAw;
                    mainDiffV *= invAw;
                    addDiffV  *= invAw;
                    specV     *= invAw;
                }
            #endif

                half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

                // Mesafe LOD dokusu (orijinaldeki LOD Texture / LOD Amount)
            #if defined(_PSX_LOD_TEX)
                half4 lodTex = SAMPLE_TEXTURE2D(_LODTex, sampler_LODTex, uv);
                albedo = lerp(albedo, lodTex, i.addDiffLod.a);
            #endif

                albedo.rgb = PSXQuantizeTex(albedo.rgb);

                // ----------------------------------------------------
                //  PS1 doku modulasyonu: donanimda notr deger 128'dir
                //    final = (texel * vertexColour) / 128
                //  yani vertex rengi yuzeyi 2x'e kadar PARLATABILIR.
                //  Acikken vertex renklerinizi 1.0 yerine 0.5 etrafinda
                //  boyayin.
                // ----------------------------------------------------
            #if defined(_PSX_MODULATE128)
                vcol.rgb *= 2.0;
            #endif

                half4 tint = half4(_Color.rgb * vcol.rgb, _Color.a * vcol.a);
                half alpha = albedo.a * tint.a;
            #if defined(_ALPHATEST_ON)
                clip(alpha - _Cutoff);
            #endif

                // Metallic (PS1 doneminde PBR yoktu; bu sahte krom/env-map
                // maskesi olarak calisir - orijinal paketteki Metal dokusunun
                // modern karsiligi)
                half metallic = _Metallic;
            #if defined(_PSX_METALLIC)
                metallic *= SAMPLE_TEXTURE2D(_MetallicMap, sampler_MetallicMap, uv).r;
            #endif
                metallic = saturate(metallic);

                half3 col;
            #if defined(_PSX_UNLIT)
                col = albedo.rgb * tint.rgb;

                // Unlit + metallic: yansima yine de uygulanir
                if (metallic > 0.0 || _CubeAmount > 0.0)
                {
                    half3 viewDirU = normalize(GetWorldSpaceViewDir(positionWS));
                    half3 reflU = reflect(-viewDirU, normalize(i.nrmFog.xyz));
                    half3 envU = PSXSampleEnv(reflU, _Smoothness, positionWS,
                                              GetNormalizedScreenSpaceUV(i.positionCS));

                    col += envU * _CubeAmount * (1.0 - metallic);

                    half3 mirrorTintU = lerp(half3(1, 1, 1), albedo.rgb * tint.rgb, _MetallicTint);
                    col = lerp(col, envU * mirrorTintU, metallic);
                }
            #else
                half3 normalWS = normalize(i.nrmFog.xyz);
                #if defined(_NORMALMAP)
                    half3 tangentWS = normalize(i.tangentWS);
                    half3 bitangentWS = normalize(cross(normalWS, tangentWS)) * i.specTanSign.a;
                    half3 nTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv), _NormalStrength);
                    normalWS = normalize(mul(nTS, half3x3(tangentWS, bitangentWS, normalWS)));
                #endif

                float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
                Light mainLight = GetMainLight(shadowCoord);
                half atten = mainLight.shadowAttenuation;

                half3 mainDiff;
                half3 addLight;
                #if defined(_PSX_DIFF_FRAGMENT)
                    // Fragment modunda TUM isiklar per-pixel hesaplanir
                    mainDiff = mainLight.color * saturate(dot(normalWS, mainLight.direction));
                    addLight = PSXAdditionalLights(positionWS, normalWS,
                                                   GetNormalizedScreenSpaceUV(i.positionCS));
                #else
                    // Vertex (Gouraud) modunda tum isiklar vertex'ten gelir (PS1 dogrulugu)
                    mainDiff = mainDiffV;
                    addLight = addDiffV;
                #endif

                half3 bakedGI = SAMPLE_GI(i.staticLightmapUV, i.vertexSH, normalWS);

                half3 lighting;
                if (_PSX_ShadowMode > 0.5)
                    lighting = mainDiff + addLight + bakedGI;           // PSX: golge sonra cikarilir
                else
                    lighting = mainDiff * atten + addLight + bakedGI;   // Normal: carpimsal golge

                // "Metal Ignores Lighting" acikken metal orani kadar sahne
                // aydinlatmasi devre disi kalir - metal yuzey isiga tepki
                // vermez, rengini yalnizca yansimadan alir.
                // _MetalUnlit = 0 iken bu satir hicbir sey yapmaz.
                half metalUnlitAmt = saturate(metallic * _MetalUnlit);
                lighting = lerp(lighting, half3(1, 1, 1), metalUnlitAmt);

                col = albedo.rgb * tint.rgb * lighting;

                // Specular - metaller yansimalarini albedo ile renklendirir
                half3 spec = specV;
                #if defined(_PSX_SPEC_PHONG)
                if (_Specular > 0.0)
                {
                    float3 viewDirS = normalize(GetWorldSpaceViewDir(positionWS));
                    float3 r = reflect(-mainLight.direction, normalWS);
                    spec = mainLight.color * pow(saturate(dot(r, viewDirS)), _Shininess);
                }
                #endif
                if (_Specular > 0.0)
                {
                    half specMask = SAMPLE_TEXTURE2D(_SpecularMap, sampler_SpecularMap, uv).r;
                    half3 specTint = lerp(half3(1, 1, 1), albedo.rgb, metallic);

                    // Metal yuzeyde isik kaynagi parlamasi (specular hotspot)
                    // istenmiyorsa metal orani kadar kis.
                    half specFade = 1.0h - metalUnlitAmt;

                    col += spec * specMask * specTint * _Specular * specFade
                           * (_PSX_ShadowMode > 0.5 ? 1.0 : atten);
                }

                // PSX tarzi cikarimsal golge (PS1 yari-saydamlik modu 2: B - F)
                if (_PSX_ShadowMode > 0.5)
                    col -= (1.0 - atten) * _PSX_ShadowIntensity;

                // Ortam yansimasi (PS1 sahte env-map) + metallic
                //
                // Cubemap atanmamissa PSXSampleEnv sahnenin reflection
                // probe'una / skybox'ina duser; yani metallic > 0 her
                // zaman bir yansima uretir. (Eskiden cubemap yoksa
                // yalnizca diffuse kisiliyordu ve "ayna" olmuyordu.)
                if (metallic > 0.0 || _CubeAmount > 0.0)
                {
                    half3 viewDir = normalize(GetWorldSpaceViewDir(positionWS));
                    half3 refl = reflect(-viewDir, normalWS);
                    half3 env = PSXSampleEnv(refl, _Smoothness, positionWS,
                                             GetNormalizedScreenSpaceUV(i.positionCS));

                    // Dielektrik yuzeyler: yansima eklenir (metallic = 0'da
                    // eski davranis birebir korunur)
                    col += env * _CubeAmount * (1.0 - metallic);

                    // Metal yuzeyler: rengi yansimanin kendisi belirler.
                    // _MetallicTint = 1 -> yansima albedo ile renklenir
                    //   (altin/bakir gibi renkli metaller icin dogru)
                    // _MetallicTint = 0 -> saf ayna, albedo'dan bagimsiz
                    half3 mirrorTint = lerp(half3(1, 1, 1), albedo.rgb * tint.rgb, _MetallicTint);
                    col = lerp(col, env * mirrorTint, metallic);
                }
            #endif // _PSX_UNLIT

                // Emission
                col += SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, uv).rgb * _EmissionColor.rgb;

                col = max(col, 0.0);
                col = PSXMixFog(col, i.nrmFog.w);

                // ----------------------------------------------------
                //  Dither uygunlugu (donanim kurali)
                //
                //  psx-spx: "POLYGONs (triangles/quads) are dithered ONLY
                //  if they do use gouraud shading or modulation."
                //  Yani duz golgeli VEYA ham (modulasyonsuz) dokulu bir
                //  poligon donanimda HIC dither almaz - texel'ler zaten
                //  15-bit oldugu icin ortada 8-bit ara deger yoktur.
                //
                //  Bu bayrak alpha kanalinda post pass'e tasinir.
                //  Opaque/Cutout'ta alpha harmanlamada kullanilmadigi icin
                //  bedavadir; Transparent'ta gercek alpha korunur.
                // ----------------------------------------------------
                half ditherFlag = 1.0;
            #if defined(_PSX_NO_DITHER)
                ditherFlag = 0.0;               // materyal bazli acik reddetme
            #elif defined(_PSX_UNLIT)
                // Unlit + vertex renkleri kapali = ham doku, modulasyon yok
                ditherFlag = (_VertexColors > 0.5) ? 1.0 : 0.0;
            #endif

                half outAlpha = (_RenderMode > 1.5) ? alpha : ditherFlag;
                return half4(col, outAlpha);
            }
            ENDHLSL
        }

        // ====================================================
        //  Shadow Caster
        //  NOT: Burada BILEREK PSXSnapClipPos cagrilmaz. Bu pass
        //  isigin projeksiyonundan render eder; kameranin hedef
        //  cozunurluk gridine snap etmek anlamsiz olur ve agir
        //  shadow acne uretir.
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
        //  Kamera projeksiyonunu ForwardLit ile PAYLASIR, bu
        //  yuzden ayni snap uygulanmali - yoksa derinlik tabanli
        //  efektler (SSAO, sky mask) geometriyle uyusmaz.
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
                float3 uvCull     : TEXCOORD0;   // xy = uv, z = cull bayragi
            };

            Varyings DepthVert(Attributes v)
            {
                Varyings o;
                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                positionWS = PSXWorldSnap(positionWS);
                float4 positionCS = TransformWorldToHClip(positionWS);
                o.positionCS = PSXSnapClipPos(positionCS, _SnapScale);
                o.uvCull = float3(v.uv * _MainTex_ST.xy + _MainTex_ST.zw,
                                  PSXCullFlag(positionWS, positionCS.w, _DrawDistInfluence));
                return o;
            }

            half4 DepthFrag(Varyings i) : SV_Target
            {
                clip(0.5 - i.uvCull.z);
            #if defined(_ALPHATEST_ON)
                half a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvCull.xy).a * _Color.a;
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
                float3 uvCull     : TEXCOORD0;   // xy = uv, z = cull bayragi
                half3 normalWS    : TEXCOORD1;
            };

            Varyings DepthNormalsVert(Attributes v)
            {
                Varyings o;
                float3 positionWS = TransformObjectToWorld(v.positionOS.xyz);
                positionWS = PSXWorldSnap(positionWS);
                float4 positionCS = TransformWorldToHClip(positionWS);
                o.positionCS = PSXSnapClipPos(positionCS, _SnapScale);
                o.uvCull = float3(v.uv * _MainTex_ST.xy + _MainTex_ST.zw,
                                  PSXCullFlag(positionWS, positionCS.w, _DrawDistInfluence));
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                return o;
            }

            half4 DepthNormalsFrag(Varyings i) : SV_Target
            {
                clip(0.5 - i.uvCull.z);
            #if defined(_ALPHATEST_ON)
                half a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uvCull.xy).a * _Color.a;
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
