using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace PSX.EditorTools
{
    /// <summary>
    /// Tak-calistir kurulum: sahnede PSXEffectsManager gorulur gorulmez
    /// URP renderer'ina PSXRenderFeature'i ekler ve bir PSX Volume
    /// profili olusturur. Ayrica Tools menusunden manuel kurulum ve
    /// materyal donusturme araclari sunar.
    /// </summary>
    [InitializeOnLoad]
    public static class PSXEditorSetup
    {
        const string kProfileFolder = "Assets/PSXEffectsURP/Settings";
        const string kProfilePath = kProfileFolder + "/PSX Post Profile.asset";

        static PSXEditorSetup()
        {
            EditorApplication.hierarchyChanged += OnHierarchyChanged;
        }

        static void OnHierarchyChanged()
        {
            if (Application.isPlaying)
                return;
            var mgr = Object.FindFirstObjectByType<PSXEffectsManager>();
            if (mgr == null)
                return;
            EnsureRendererFeature(logIfAdded: true);
            EnsureVolume(mgr);
        }

        // ------------------------------------------------------------
        //  Menuler
        // ------------------------------------------------------------
        [MenuItem("Tools/PSX Effects/Sahneye Kur (Add To Scene)")]
        static void AddToScene()
        {
            var mgr = Object.FindFirstObjectByType<PSXEffectsManager>();
            if (mgr == null)
            {
                var go = new GameObject("PSX Effects");
                mgr = go.AddComponent<PSXEffectsManager>();
                Undo.RegisterCreatedObjectUndo(go, "PSX Effects Kur");
            }
            EnsureRendererFeature(logIfAdded: true);
            EnsureVolume(mgr);
            Selection.activeObject = mgr.gameObject;
            Debug.Log("[PSXEffects] Kurulum tamam. Ayarlar: 'PSX Effects' objesi + PSX Post Profile volume profili.");
        }

        [MenuItem("Tools/PSX Effects/Renderer Feature'i Kur")]
        static void SetupFeatureMenu()
        {
            EnsureRendererFeature(logIfAdded: true, logIfPresent: true);
        }

        [MenuItem("Tools/PSX Effects/Secili Materyalleri PSX-Lit'e Donustur")]
        static void ConvertSelectedMaterials()
        {
            Shader psxLit = Shader.Find("PSX/Lit");
            if (psxLit == null)
            {
                Debug.LogError("[PSXEffects] PSX/Lit shader bulunamadi.");
                return;
            }

            int count = 0;
            foreach (var obj in Selection.objects)
            {
                var mat = obj as Material;
                if (mat == null || mat.shader == psxLit)
                    continue;

                Undo.RecordObject(mat, "PSX-Lit Donustur");

                Texture baseMap = null;
                Color baseColor = Color.white;
                if (mat.HasProperty("_BaseMap")) baseMap = mat.GetTexture("_BaseMap");
                else if (mat.HasProperty("_MainTex")) baseMap = mat.GetTexture("_MainTex");
                if (mat.HasProperty("_BaseColor")) baseColor = mat.GetColor("_BaseColor");
                else if (mat.HasProperty("_Color")) baseColor = mat.GetColor("_Color");

                mat.shader = psxLit;
                if (baseMap != null) mat.SetTexture("_MainTex", baseMap);
                mat.SetColor("_Color", baseColor);
                EditorUtility.SetDirty(mat);
                count++;
            }
            Debug.Log($"[PSXEffects] {count} materyal PSX/Lit'e donusturuldu.");
        }

        // ------------------------------------------------------------
        //  Renderer feature kurulumu
        // ------------------------------------------------------------
        static void EnsureRendererFeature(bool logIfAdded = false, bool logIfPresent = false)
        {
            foreach (var rendererData in GetAllRendererData())
            {
                if (rendererData == null)
                    continue;
                if (rendererData.rendererFeatures.Any(f => f is PSXRenderFeature))
                {
                    if (logIfPresent)
                        Debug.Log($"[PSXEffects] '{rendererData.name}' zaten PSXRenderFeature iceriyor.");
                    continue;
                }
                AddFeature(rendererData);
                if (logIfAdded)
                    Debug.Log($"[PSXEffects] PSXRenderFeature '{rendererData.name}' renderer'ina eklendi.");
            }
        }

        static IEnumerable<ScriptableRendererData> GetAllRendererData()
        {
            var assets = new HashSet<UniversalRenderPipelineAsset>();
            if (GraphicsSettings.defaultRenderPipeline is UniversalRenderPipelineAsset def)
                assets.Add(def);
            for (int i = 0; i < QualitySettings.names.Length; i++)
            {
                if (QualitySettings.GetRenderPipelineAssetAt(i) is UniversalRenderPipelineAsset qa)
                    assets.Add(qa);
            }

            var field = typeof(UniversalRenderPipelineAsset).GetField("m_RendererDataList",
                BindingFlags.NonPublic | BindingFlags.Instance);
            foreach (var asset in assets)
            {
                if (field?.GetValue(asset) is ScriptableRendererData[] list)
                {
                    foreach (var data in list)
                        yield return data;
                }
            }
        }

        static void AddFeature(ScriptableRendererData rendererData)
        {
            var feature = ScriptableObject.CreateInstance<PSXRenderFeature>();
            feature.name = "PSX Render Feature";

            if (EditorUtility.IsPersistent(rendererData))
                AssetDatabase.AddObjectToAsset(feature, rendererData);
            AssetDatabase.TryGetGUIDAndLocalFileIdentifier(feature, out _, out long localId);

            var so = new SerializedObject(rendererData);
            var features = so.FindProperty("m_RendererFeatures");
            var map = so.FindProperty("m_RendererFeatureMap");

            features.arraySize++;
            features.GetArrayElementAtIndex(features.arraySize - 1).objectReferenceValue = feature;
            map.arraySize++;
            map.GetArrayElementAtIndex(map.arraySize - 1).longValue = localId;

            so.ApplyModifiedProperties();
            EditorUtility.SetDirty(rendererData);
            AssetDatabase.SaveAssets();
        }

        // ------------------------------------------------------------
        //  Volume kurulumu
        // ------------------------------------------------------------
        static void EnsureVolume(PSXEffectsManager mgr)
        {
            // Sahnede PSXPostVolume iceren bir volume var mi?
            foreach (var vol in Object.FindObjectsByType<Volume>(FindObjectsSortMode.None))
            {
                if (vol.sharedProfile != null && vol.sharedProfile.Has<PSXPostVolume>())
                    return;
            }

            var profile = AssetDatabase.LoadAssetAtPath<VolumeProfile>(kProfilePath);
            if (profile == null)
            {
                if (!AssetDatabase.IsValidFolder(kProfileFolder))
                {
                    if (!AssetDatabase.IsValidFolder("Assets/PSXEffectsURP"))
                        AssetDatabase.CreateFolder("Assets", "PSXEffectsURP");
                    AssetDatabase.CreateFolder("Assets/PSXEffectsURP", "Settings");
                }
                profile = ScriptableObject.CreateInstance<VolumeProfile>();
                AssetDatabase.CreateAsset(profile, kProfilePath);
            }

            if (!profile.Has<PSXPostVolume>())
            {
                var comp = profile.Add<PSXPostVolume>(overrides: true);
                comp.name = "PSXPostVolume";
                AssetDatabase.AddObjectToAsset(comp, profile);
                EditorUtility.SetDirty(profile);
                AssetDatabase.SaveAssets();
            }

            var volume = mgr.GetComponent<Volume>();
            if (volume == null)
            {
                volume = Undo.AddComponent<Volume>(mgr.gameObject);
                volume.isGlobal = true;
            }
            if (volume.sharedProfile == null)
                volume.sharedProfile = profile;
        }
    }
}
