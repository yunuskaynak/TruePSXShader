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
        MaterialProperty snapScale = FindProperty("_SnapScale", props);
        MaterialProperty affineOverride = FindProperty("_AffineOverride", props);
        MaterialProperty drawDist = FindProperty("_DrawDistInfluence", props);
        MaterialProperty diffModel = FindProperty("_PSX_DIFF", props);
        MaterialProperty texQuant = FindProperty("_TexQuant", props);
        MaterialProperty texBits = FindProperty("_TexBits", props);
        MaterialProperty normalMap = FindProperty("_NormalMap", props);
        MaterialProperty normalStrength = FindProperty("_NormalStrength", props);
        MaterialProperty specMap = FindProperty("_SpecularMap", props);
        MaterialProperty specular = FindProperty("_Specular", props);
        MaterialProperty shininess = FindProperty("_Shininess", props);
        MaterialProperty specModel = FindProperty("_PSX_SPEC", props);
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
        EditorGUILayout.LabelField("PS1 Doku", EditorStyles.boldLabel);
        materialEditor.ShaderProperty(texQuant, new GUIContent("Texture Color Quantization",
            "Dokuyu ornekleme sirasinda dusuk renk derinligine indirger (CLUT hissi)."));
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

        SetKeyword(material, "_NORMALMAP", material.GetTexture("_NormalMap") != null);
        SetKeyword(material, "_PSX_CUBEMAP", material.GetTexture("_Cube") != null);
        SetKeyword(material, "_PSX_LOD_TEX", material.GetTexture("_LODTex") != null);
    }

    static void SetKeyword(Material m, string keyword, bool state)
    {
        if (state) m.EnableKeyword(keyword);
        else m.DisableKeyword(keyword);
    }
}
