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

// ------------------------------------------------------------
// Dunya uzayinda vertex snap (kamera-goreli, hassasiyet icin)
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
// ------------------------------------------------------------
float4 PSXSnapClipPos(float4 positionCS, float snapScale)
{
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
// Cizim mesafesi bayragi (1 = gizle)
// ------------------------------------------------------------
float PSXDrawDistanceFlag(float3 positionWS, float drawDistInfluence)
{
    return (_PSX_DrawDistance > 0.0 &&
            drawDistInfluence > 0.5 &&
            distance(positionWS, _WorldSpaceCameraPos) > _PSX_DrawDistance) ? 1.0 : 0.0;
}

#endif // PSX_COMMON_INCLUDED
