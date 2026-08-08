using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// PSX/Lit shader'i icin ozel inspector.
/// Render modu, blend islemi ve keyword yonetimini yapar.
/// </summary>
public class PSXLitShaderGUI : ShaderGUI
{
    enum RenderMode { Opaque, Cutout, Transparent }
    enum BlendOperation { Add, Subtract, ReverseSubtract }

    static readonly string[] RenderModeNames = Enum.GetNames(typeof(RenderMode));
    static readonly string[] BlendOpNames = Enum.GetNames(typeof(BlendOperation));

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
    {
        Material material = materialEditor.target as Material;

        MaterialProperty renderMode = FindProperty("_RenderMode", props);
        MaterialProperty blendOp = FindProperty("_BlendOp", props);
        MaterialProperty zWrite = FindProperty("_ZWrite", props);
        MaterialProperty cull = FindProperty("_Cull", props);
        MaterialProperty cutoff = FindProperty("_Cutoff", props);
        MaterialProperty mainTex = FindProperty("_MainTex", props);
        MaterialProperty color = FindProperty("_Color", props);
        MaterialProperty unlit = FindProperty("_Unlit", props);
        MaterialProperty vertexColors = FindProperty("_VertexColors", props);
        MaterialProperty modulate128 = FindProperty("_Modulate128", props);
        MaterialProperty affineShading = FindProperty("_AffineShading", props);
        MaterialProperty snapScale = FindProperty("_SnapScale", props);
        MaterialProperty affineOverride = FindProperty("_AffineOverride", props);
        MaterialProperty drawDist = FindProperty("_DrawDistInfluence", props);
        MaterialProperty diffModel = FindProperty("_PSX_DIFF", props);
        MaterialProperty texQuant = FindProperty("_TexQuant", props);
        MaterialProperty texBits = FindProperty("_TexBits", props);
        MaterialProperty noDither = FindProperty("_NoDither", props);
        MaterialProperty normalMap = FindProperty("_NormalMap", props);
        MaterialProperty normalStrength = FindProperty("_NormalStrength", props);
        MaterialProperty specMap = FindProperty("_SpecularMap", props);
        MaterialProperty specular = FindProperty("_Specular", props);
        MaterialProperty shininess = FindProperty("_Shininess", props);
        MaterialProperty specModel = FindProperty("_PSX_SPEC", props);
        MaterialProperty metallicMap = FindProperty("_MetallicMap", props);
        MaterialProperty metallic = FindProperty("_Metallic", props);
        MaterialProperty smoothness = FindProperty("_Smoothness", props);
        MaterialProperty metallicTint = FindProperty("_MetallicTint", props);
        MaterialProperty reflIntensity = FindProperty("_ReflectionIntensity", props);
        MaterialProperty metalUnlit = FindProperty("_MetalUnlit", props);
        MaterialProperty emissionMap = FindProperty("_EmissionMap", props);
        MaterialProperty emissionColor = FindProperty("_EmissionColor", props);
        MaterialProperty cube = FindProperty("_Cube", props);
        MaterialProperty cubeAmount = FindProperty("_CubeAmount", props);
        MaterialProperty lodTex = FindProperty("_LODTex", props);
        MaterialProperty lodAmt = FindProperty("_LODAmt", props);

        EditorGUI.BeginChangeCheck();

        EditorGUILayout.LabelField("Ayarlar", EditorStyles.boldLabel);
        renderMode.floatValue = EditorGUILayout.Popup("Render Mode", (int)renderMode.floatValue, RenderModeNames);
        if ((int)renderMode.floatValue == (int)RenderMode.Cutout)
            materialEditor.ShaderProperty(cutoff, "Alpha Cutoff");
        blendOp.floatValue = EditorGUILayout.Popup("Blend Operation", (int)blendOp.floatValue, BlendOpNames);

        bool ignoreDepth = zWrite.floatValue < 0.5f;
        ignoreDepth = EditorGUILayout.Toggle(new GUIContent("Ignore Depth Buffer",
            "Derinlik tamponuna yazmayi kapatir (PSX gokyuzu/saydamlik hilesi)."), ignoreDepth);
        zWrite.floatValue = ignoreDepth ? 0f : 1f;

        bool backfaceCulling = Mathf.Approximately(cull.floatValue, (float)CullMode.Back);
        backfaceCulling = EditorGUILayout.Toggle("Backface Culling", backfaceCulling);
        cull.floatValue = backfaceCulling ? (float)CullMode.Back : (float)CullMode.Off;

        materialEditor.ShaderProperty(unlit, "Unlit");
        materialEditor.ShaderProperty(vertexColors, "Use Vertex Colors");
        materialEditor.ShaderProperty(drawDist, "Draw Distance Influence");
        materialEditor.ShaderProperty(snapScale, new GUIContent("Vertex Snap Scale",
            "Global vertex snap siddetinin katsayisi. 0 = bu materyalde kapali."));
        materialEditor.ShaderProperty(affineOverride, new GUIContent("Affine Override",
            "-1 = global degeri kullan. 0-1 arasi bu materyal icin affine siddeti."));
        materialEditor.ShaderProperty(diffModel, "Diffuse Model");

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("PS1 Dogrulugu", EditorStyles.boldLabel);
        materialEditor.ShaderProperty(modulate128, new GUIContent("PS1 Vertex Colour Modulation",
            "Donanimda doku modulasyonunun notr degeri 255 degil 128'dir: final = (texel * vcol) / 128. " +
            "Yani vertex rengi yuzeyi 2x'e kadar PARLATABILIR. Acikken vertex renklerinizi 1.0 yerine " +
            "0.5 etrafinda boyayin."));
        materialEditor.ShaderProperty(affineShading, new GUIContent("Affine Vertex Shading",
            "Donanimda Gouraud renkleri de UV'ler gibi perspektif duzeltmesi gormez. " +
            "Etkisi UV kaymasindan cok daha ince; buyuk isikli poligonlarda gorunur. Ekstra maliyeti yok."));
        materialEditor.ShaderProperty(noDither, new GUIContent("Raw Texture (No Dither)",
            "Donanimda yalnizca gouraud golgeli VEYA modulasyonlu poligonlar dither alir. " +
            "Ham dokulu / duz golgeli yuzeyler icin bunu acin; post pass o pikselleri dither'lamaz."));

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("PS1 Doku", EditorStyles.boldLabel);
        materialEditor.ShaderProperty(texQuant, new GUIContent("Texture Color Quantization",
            "Dokuyu ornekleme sirasinda dusuk renk derinligine indirger (CLUT hissi). PS1 = 5 bit."));
        if (texQuant.floatValue > 0.5f)
            materialEditor.ShaderProperty(texBits, "Bits Per Channel");

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Dokular", EditorStyles.boldLabel);
        materialEditor.TexturePropertySingleLine(new GUIContent("Main Texture"), mainTex, color);
        materialEditor.TexturePropertySingleLine(new GUIContent("Normal Map"), normalMap,
            normalMap.textureValue != null ? normalStrength : null);
        materialEditor.TexturePropertySingleLine(new GUIContent("Specular Map"), specMap, specular);
        if (specular.floatValue > 0f)
        {
            materialEditor.ShaderProperty(shininess, "Shininess");
            materialEditor.ShaderProperty(specModel, "Specular Model");
        }

        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Yansima / Metal", EditorStyles.boldLabel);
        materialEditor.TexturePropertySingleLine(new GUIContent("Metallic Map",
            "Kirmizi kanal metallic maskesi olarak kullanilir. Yanindaki slider ile CARPILIR - " +
            "slider 0 iken doku hicbir sey yapmaz (doku atayinca otomatik 1'e cekilir)."),
            metallicMap, metallic);
        materialEditor.ShaderProperty(smoothness, new GUIContent("Reflection Smoothness",
            "1 = keskin ayna (mip 0), 0 = mat metal (en bulanik mip)."));
        materialEditor.ShaderProperty(metallicTint, new GUIContent("Reflection Tint By Albedo",
            "1 = yansima albedo ile renklenir (altin/bakir gibi renkli metaller). " +
            "0 = saf ayna, albedo'dan bagimsiz."));
        materialEditor.ShaderProperty(reflIntensity, new GUIContent("Reflection Intensity",
            "Yansimanin genel siddeti. Skybox'taki gunes / HDR probe yansimayi patlatiyorsa dusurun."));
        materialEditor.ShaderProperty(metalUnlit, new GUIContent("Metal Ignores Lighting",
            "ACIK (varsayilan): metal yuzey sahne isigina tepki VERMEZ - ne diffuse ne de specular " +
            "parlamasi alir, rengini yalnizca yansimadan alir. Temiz krom/ayna icin bunu acik birakin.\n\n" +
            "KAPALI: metal yuzey de isiklandirilir ve isik kaynagi parlamasi gorunur."));

        if (metallic.floatValue > 0f && cube.textureValue == null)
        {
            EditorGUILayout.HelpBox(
                "Cubemap atanmamis - yansima sahnenin reflection probe'undan / skybox'indan alinir. " +
                "Daha keskin bir ayna icin sahneye bir Reflection Probe ekleyip 'Box Projection' acin.",
                MessageType.Info);
        }

        if (GUILayout.Button(new GUIContent("Ayna Yap (Mirror Preset)",
            "Metallic = 1, Smoothness = 1, Tint = 0, Color = beyaz, Specular = 0")))
        {
            foreach (Material m in materialEditor.targets)
            {
                Undo.RecordObject(m, "Mirror Preset");
                m.SetFloat("_Metallic", 1f);
                m.SetFloat("_Smoothness", 1f);
                m.SetFloat("_MetallicTint", 0f);
                m.SetFloat("_ReflectionIntensity", 1f);
                m.SetFloat("_MetalUnlit", 1f);
                m.SetColor("_Color", Color.white);
                m.SetFloat("_Specular", 0f);
                EditorUtility.SetDirty(m);
            }
        }
        EditorGUILayout.Space();

        materialEditor.TexturePropertySingleLine(new GUIContent("Emission"), emissionMap, emissionColor);
        materialEditor.TexturePropertySingleLine(new GUIContent("Cubemap"), cube,
            cube.textureValue != null ? cubeAmount : null);
        materialEditor.TexturePropertySingleLine(new GUIContent("LOD Texture",
            "Kamera 'LOD Distance' mesafesini gecince ana doku yerine gosterilir."), lodTex,
            lodTex.textureValue != null ? lodAmt : null);

        EditorGUILayout.Space();
        materialEditor.TextureScaleOffsetProperty(mainTex);

        EditorGUILayout.Space();
        materialEditor.RenderQueueField();
        materialEditor.EnableInstancingField();

        if (EditorGUI.EndChangeCheck())
        {
            foreach (Material m in materialEditor.targets)
                ApplyMaterialState(m, (RenderMode)(int)renderMode.floatValue, (BlendOperation)(int)blendOp.floatValue);
        }
    }

    static void ApplyMaterialState(Material material, RenderMode mode, BlendOperation op)
    {
        switch (mode)
        {
            case RenderMode.Transparent:
                material.SetOverrideTag("RenderType", "Transparent");
                material.SetFloat("_SrcBlend", (float)BlendMode.SrcAlpha);
                material.SetFloat("_DstBlend", (float)BlendMode.OneMinusSrcAlpha);
                material.SetFloat("_ZWrite", 0f);
                material.DisableKeyword("_ALPHATEST_ON");
                material.renderQueue = (int)RenderQueue.Transparent;
                break;
            case RenderMode.Cutout:
                material.SetOverrideTag("RenderType", "TransparentCutout");
                material.SetFloat("_SrcBlend", (float)BlendMode.One);
                material.SetFloat("_DstBlend", (float)BlendMode.Zero);
                material.EnableKeyword("_ALPHATEST_ON");
                material.renderQueue = (int)RenderQueue.AlphaTest;
                break;
            default:
                material.SetOverrideTag("RenderType", "Opaque");
                material.SetFloat("_SrcBlend", (float)BlendMode.One);
                material.SetFloat("_DstBlend", (float)BlendMode.Zero);
                material.DisableKeyword("_ALPHATEST_ON");
                material.renderQueue = (int)RenderQueue.Geometry;
                break;
        }

        switch (op)
        {
            case BlendOperation.Subtract:
                material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.Subtract);
                break;
            case BlendOperation.ReverseSubtract:
                material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.ReverseSubtract);
                break;
            default:
                material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.Add);
                break;
        }

        // Metallic dokusu atandiginda skaler hala 0 ise doku hicbir sey
        // yapmazdi (ikisi carpiliyor). Ilk atamada 1'e cek.
        bool hasMetallicMap = material.GetTexture("_MetallicMap") != null;
        if (hasMetallicMap && material.GetFloat("_Metallic") <= 0f)
            material.SetFloat("_Metallic", 1f);

        SetKeyword(material, "_NORMALMAP", material.GetTexture("_NormalMap") != null);
        SetKeyword(material, "_PSX_METALLIC", hasMetallicMap);
        SetKeyword(material, "_PSX_CUBEMAP", material.GetTexture("_Cube") != null);
        SetKeyword(material, "_PSX_LOD_TEX", material.GetTexture("_LODTex") != null);
    }

    static void SetKeyword(Material m, string keyword, bool state)
    {
        if (state) m.EnableKeyword(keyword);
        else m.DisableKeyword(keyword);
    }
}
