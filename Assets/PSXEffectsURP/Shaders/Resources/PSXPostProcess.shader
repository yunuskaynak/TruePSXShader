// ============================================================
//  Hidden/PSX/PostProcess
//  Dusuk cozunurluk upscale + 15-bit renk posterizasyonu +
//  PS1 dither matrisi + scanline / interlace / CRT / vignette
// ============================================================
Shader "Hidden/PSX/PostProcess"
{
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        ZWrite Off
        ZTest Always
        Cull Off

        Pass
        {
            Name "PSXPost"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment PSXFrag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            // Nokta (point) filtreleme - PS1 upscale gorunumu
            SAMPLER(psx_point_clamp_sampler);

            TEXTURE2D_X(_PSX_DepthTex);

            float4 _PSX_TargetRes;    // x = w, y = h (dusuk cozunurluk)
            float4 _PSX_PostParams0;  // x = renk biti, y = dither siddeti, z = ditherSky, w = subtractFade
            float4 _PSX_PostParams1;  // x = scanline siddeti, y = dikey scanline, z = interlace, w = kare paritesi
            float4 _PSX_PostParams2;  // x = CRT bombe, y = vignette, z = favorRed, w = depth var mi

            // ------------------------------------------------------------
            //  Orijinal PS1 GPU 4x4 dither matrisi (psx-spx)
            //
            //  Donanim algoritmasi, kanal basina bagimsiz:
            //    offset = M[y & 3][x & 3]
            //    v8     = clamp(color8 + offset, 0, 255)   // ONCE doyur
            //    v5     = v8 / 8                           // sonra tam sayi bolme
            //
            //  Genlik yalnizca +-4/255, yani bir 5-bit adiminin yarisi.
            //  Cogu "PS1 shader"i 5-10 kat fazla siddette Bayer matrisi
            //  kullanir; bu matris gercek donanim degerleridir.
            //  3. ve 4. satirlar 1. ve 2. satirlarin 2 piksel yatay
            //  kaydirilmis halidir (Bayer DEGILDIR).
            // ------------------------------------------------------------
            static const float PSX_DITHER[16] =
            {
                -4.0,  0.0, -3.0,  1.0,
                 2.0, -2.0,  3.0, -1.0,
                -3.0,  1.0, -4.0,  0.0,
                 3.0, -1.0,  2.0, -2.0
            };

            half4 PSXFrag(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 uv = input.texcoord;

                // --- CRT bombeleme ---
                float crt = _PSX_PostParams2.x;
                float border = 1.0;
                if (crt > 0.0)
                {
                    float2 c = uv * 2.0 - 1.0;
                    float r2 = dot(c, c);
                    c *= 1.0 + crt * 0.15 * r2;
                    uv = c * 0.5 + 0.5;
                    border = (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) ? 1.0 : 0.0;
                }

                half4 src = SAMPLE_TEXTURE2D_X(_BlitTexture, psx_point_clamp_sampler, uv);
                half3 col = saturate(src.rgb);

                // Alpha kanali PSX/Lit'ten gelen dither uygunluk maskesini
                // tasir (1 = gouraud/modulasyonlu -> dither'lanir,
                // 0 = ham doku / duz golge -> donanimda dither YOK).
                // Kamera formatinda alpha yoksa 1 okunur ve eski davranis
                // (her seyi dither'la) aynen korunur.
                bool materialSkipsDither = src.a < 0.5;

                // Islemler orijinaldeki gibi gamma (sRGB) uzayinda yapilir.
                // PS1 framebuffer'i hicbir zaman lineer degildi; dither'i
                // lineer uzayda uygulamak yanlis kontrastta desen uretir.
            #if !defined(UNITY_COLORSPACE_GAMMA)
                col = LinearToSRGB(col);
            #endif

                // --- Subtraction fade (PS1 ekran kararmasi) ---
                // PS1 yari-saydamlik modu 2 (B - F) ile duz bir renk cikarmak
                // oyunlarin standart fade-to-black yontemiydi. Dogrudan
                // cikarma kullanilir: fade = 0.5 -> yarim yol, fade = 1 -> siyah.
                // (Eski formul col -= (3.0 - col) * fade idi; fade = 0.5'te bile
                // her seyi siyaha goturdugu icin pratikte kullanilamiyordu.)
                float fade = _PSX_PostParams0.w;
                if (fade > 0.0)
                    col = saturate(col - fade);

                // --- Darken darks / favor red (PS1 aydinlatma tonu) ---
                float favorRed = _PSX_PostParams2.z;
                if (favorRed > 0.0)
                {
                    col -= favorRed * ((1.0 - col) * 0.25);
                    col.r += favorRed * ((0.5 - col.r) * 0.1);
                }
                col = saturate(col);

                // Sanal dusuk cozunurluk piksel koordinati.
                // Dither donanimda VRAM piksel koordinatiyla indekslenir, bu
                // yuzden tam cozunurluk ekran pikseli DEGIL, emule edilen
                // dusuk cozunurluk pikseli kullanilmalidir.
                float2 pix = floor(uv * _PSX_TargetRes.xy);

                // --- Scanline ---
                float slI = _PSX_PostParams1.x;
                if (slI > 0.0)
                {
                    float lineCoord = _PSX_PostParams1.y > 0.5 ? pix.x : pix.y;
                    float sl = fmod(lineCoord, 2.0);
                    col *= 1.0 - sl * slI;
                }

                // --- Interlace (alternatif satir titremesi) ---
                float il = _PSX_PostParams1.z;
                if (il > 0.0)
                {
                    float parity = _PSX_PostParams1.w;
                    float lp = fmod(pix.y + parity, 2.0);
                    col *= 1.0 - lp * il * 0.5;
                }

                // --- Gokyuzu maskesi (istege bagli dither haric tutma) ---
                bool skipDither = materialSkipsDither;
                if (_PSX_PostParams0.z < 0.5 && _PSX_PostParams2.w > 0.5)
                {
                    float raw = SAMPLE_TEXTURE2D_X(_PSX_DepthTex, psx_point_clamp_sampler, uv).r;
                #if UNITY_REVERSED_Z
                    skipDither = skipDither || (raw <= 0.000001);
                #else
                    skipDither = skipDither || (raw >= 0.999999);
                #endif
                }

                // --- PS1 dither + renk posterizasyonu ---
                float bits = clamp(_PSX_PostParams0.x, 1.0, 8.0);
                float ditherI = _PSX_PostParams0.y;
                float divisor = exp2(8.0 - bits);           // 5 bit icin 8
                float levels = exp2(bits) - 1.0;            // 5 bit icin 31

                float3 c255 = col * 255.0;
                if (ditherI > 0.0 && !skipDither)
                {
                    int2 m = int2(pix) & 3;
                    int idx = m.y * 4 + m.x;
                    float d = PSX_DITHER[idx];
                    // divisor/8 katsayisi matrisi diger bit derinliklerine
                    // olceklendirir; 5 bitte 1.0'dir (donanim degeri).
                    c255 += d * (divisor / 8.0) * ditherI;
                }
                // clamp(floor(c/8), 0, 31) ile floor(clamp(c,0,255)/8) ozdestir
                // (floor monoton oldugu icin) - donanim sirasiyla ayni sonuc.
                col = clamp(floor(c255 / divisor), 0.0, levels) / levels;

                // --- Vignette ---
                float vig = _PSX_PostParams2.y;
                if (vig > 0.0)
                {
                    float2 dc = input.texcoord - 0.5;
                    col *= saturate(1.0 - vig * dot(dc, dc) * 2.5);
                }

                col *= border;

            #if !defined(UNITY_COLORSPACE_GAMMA)
                col = SRGBToLinear(col);
            #endif

                return half4(col, 1.0);
            }
            ENDHLSL
        }
    }
    FallBack Off
}
