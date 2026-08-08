#ifndef PSX_COMMON_INCLUDED
#define PSX_COMMON_INCLUDED

// ============================================================
//  PSX Effects URP - Ortak fonksiyonlar
//  PSXEffectsManager tarafindan set edilen global degiskenler
// ============================================================

float4 _PSX_TargetRes;        // x = genislik, y = yukseklik, z = 1/w, w = 1/h
float  _PSX_SnapAmount;       // 0-1 vertex snap siddeti (0 = kapali)
float  _PSX_WorldSnap;        // 0/1 dunya-uzayi snap
float  _PSX_WorldSnapUnits;   // dunya-uzayi snap birimi
float  _PSX_AffineAmount;     // 0-1 affine texture mapping siddeti
float  _PSX_DrawDistance;     // 0 = kapali, >0 = poligon cizim mesafesi
float  _PSX_ShadowMode;       // 0 = normal (carpimsal), 1 = PSX (cikarimsal)
float  _PSX_ShadowIntensity;  // cikarimsal golge siddeti

// PS1 depth-cue sisi (GTE IR0 egrisi: 1/z'de lineer)
float  _PSX_FogMode;          // 0 = URP sisi, 1 = PS1 depth cue
float4 _PSX_FogParams;        // x = DQA, y = DQB
float4 _PSX_FogColor;         // PS1 "far color" (FC)

// Yakin poligon reddi (PS1'in 1023x511 boyut sinirinin yaklasik karsiligi)
float  _PSX_NearCullDist;     // 0 = kapali, >0 = bu view-uzayi derinliginden yakin vertexler atilir

// ------------------------------------------------------------
// Dunya uzayinda vertex snap (kamera-goreli, hassasiyet icin)
// NOT: Bu donanim davranisi DEGILDIR. PS1'in gercek titremesi
// ekran uzayindadir (bkz. PSXSnapClipPos). Bu mod tamamen
// sanatsal bir secenektir.
// ------------------------------------------------------------
float3 PSXWorldSnap(float3 positionWS)
{
    if (_PSX_WorldSnap > 0.5 && _PSX_WorldSnapUnits > 0.00001)
    {
        float3 rel = positionWS - _WorldSpaceCameraPos;
        rel = round(rel / _PSX_WorldSnapUnits) * _PSX_WorldSnapUnits;
        positionWS = rel + _WorldSpaceCameraPos;
    }
    return positionWS;
}

// ------------------------------------------------------------
// Ekran uzayinda vertex snap (PS1'in subpixel rasterizasyon
// eksikligini taklit eder). Grid = hedef cozunurlugun yarisi.
// snapScale: materyal bazli katsayi (0 = bu materyalde kapali)
//
// GUVENLIK: _PSX_TargetRes hic set edilmemisse (render feature
// renderer'a eklenmemis olabilir) deger (0,0,0,0) olur ve grid
// 1.0'a kilitlenip tum sahneyi 3x3 NDC kafesine cokertirdi.
// Bu yuzden gecersiz cozunurlukte snap tamamen atlanir.
// ------------------------------------------------------------
float4 PSXSnapClipPos(float4 positionCS, float snapScale)
{
    // Cozunurluk yazilmamis / bozuksa snap uygulama.
    if (_PSX_TargetRes.x < 2.0 || _PSX_TargetRes.y < 2.0)
        return positionCS;

    float amount = saturate(_PSX_SnapAmount * snapScale);
    if (amount <= 0.0001)
        return positionCS;

    float w = positionCS.w;
    if (abs(w) < 0.00001)
        return positionCS;

    float2 grid = max(_PSX_TargetRes.xy * 0.5, 1.0);
    float2 ndc = positionCS.xy / w;
    float2 snapped = floor(ndc * grid + 0.5) / grid;
    positionCS.xy = lerp(ndc, snapped, amount) * w;
    return positionCS;
}

// ------------------------------------------------------------
// Affine mapping icin UV hazirligi (vertex asamasi).
// uv * w ve w ayri ayri interpolasyona sokulur; fragment'ta
// bolununce ekran-uzayi lineer (affine) uv elde edilir.
//
// Matematik: rasterizer her varying icin
//   A_pc = (SUM b_i * A_i / w_i) / (SUM b_i / w_i)
// hesaplar. A = uv*w verilirse pay SUM b_i*uv_i (affine uv),
// B = w verilirse B_pc = 1/D olur; A_pc/B_pc = affine uv.
// ------------------------------------------------------------
float3 PSXAffineUV(float2 uv, float4 positionCS)
{
    float w = positionCS.w;
    w = (abs(w) < 0.00001) ? 0.00001 : w;
    return float3(uv * w, w);
}

// ------------------------------------------------------------
// Fragment asamasinda nihai UV secimi.
// affineOverride < 0 ise global deger kullanilir.
// ------------------------------------------------------------
float2 PSXResolveUV(float2 perspUV, float3 affineUV, float affineOverride)
{
    float amount = affineOverride >= 0.0 ? affineOverride : _PSX_AffineAmount;
    float2 uvA = affineUV.xy / max(abs(affineUV.z), 0.00001) * sign(affineUV.z);
    return lerp(perspUV, uvA, saturate(amount));
}

// ------------------------------------------------------------
// Cizim mesafesi + yakin poligon reddi tek bayrakta.
// 1 = bu vertex bolgesi atilacak.
// ------------------------------------------------------------
float PSXCullFlag(float3 positionWS, float clipW, float drawDistInfluence)
{
    float far = (_PSX_DrawDistance > 0.0 &&
                 drawDistInfluence > 0.5 &&
                 distance(positionWS, _WorldSpaceCameraPos) > _PSX_DrawDistance) ? 1.0 : 0.0;

    // PS1'de iki vertex arasi mesafe 1023x511 pikseli asarsa poligon
    // HIC cizilmez; pratikte kameraya cok yakin buyuk yuzeyler yok olur.
    float near = (_PSX_NearCullDist > 0.0 && clipW < _PSX_NearCullDist) ? 1.0 : 0.0;

    return max(far, near);
}

// Geriye donuk uyumluluk (eski isim)
float PSXDrawDistanceFlag(float3 positionWS, float drawDistInfluence)
{
    return (_PSX_DrawDistance > 0.0 &&
            drawDistInfluence > 0.5 &&
            distance(positionWS, _WorldSpaceCameraPos) > _PSX_DrawDistance) ? 1.0 : 0.0;
}

// ------------------------------------------------------------
// PS1 depth-cue sis faktoru (GTE IR0).
// Donanimda IR0 perspektif bolmesinin yan urunudur:
//   MAC0 = (H*20000h/SZ3) * DQA + DQB,  IR0 = MAC0/1000h  (0..1)
// yani sis z'de degil 1/z'de lineerdir. clipW standart bir
// projeksiyonda view-uzayi z'ye esittir.
// ------------------------------------------------------------
float PSXFogFactorPS1(float clipW)
{
    float invZ = 1.0 / max(clipW, 0.00001);
    return saturate(invZ * _PSX_FogParams.x + _PSX_FogParams.y);
}

// Aktif sis moduna gore faktor uret (vertex asamasinda cagrilir)
float PSXFogFactor(float4 positionCS)
{
    if (_PSX_FogMode > 0.5)
        return PSXFogFactorPS1(positionCS.w);
    return ComputeFogFactor(positionCS.z);
}

// Aktif sis moduna gore renk karistir (fragment asamasinda cagrilir).
// PS1 modunda tek bir "far color"a dogru duz lerp yapilir:
//   [MAC1,MAC2,MAC3] = MAC + (FC - MAC) * IR0
// ------------------------------------------------------------
half3 PSXMixFog(half3 color, float fogFactor)
{
    if (_PSX_FogMode > 0.5)
        return lerp(color, _PSX_FogColor.rgb, saturate(fogFactor));
    return MixFog(color, fogFactor);
}

#endif // PSX_COMMON_INCLUDED
