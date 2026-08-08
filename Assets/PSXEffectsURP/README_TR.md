# PSX Effects URP

PlayStation 1 tarzı render paketi — orijinal **PSXEffects** (Built-in RP) paketinin
Unity 6 / URP 17 için **sıfırdan yazılmış** sürümü. Mantık aynı, mimari modern:
Render Graph tabanlı renderer feature + URP Volume entegrasyonu.

Referanslar:
[david-colson.com — PS1 Style Renderer](https://www.david-colson.com/2021/11/30/ps1-style-renderer.html) ·
[pikuma.com — How PS1 Graphics Work](https://pikuma.com/blog/how-to-make-ps1-graphics) ·
[psx-spx — GPU](https://psx-spx.consoledev.net/graphicsprocessingunitgpu/) ·
[psx-spx — GTE](https://psx-spx.consoledev.net/geometrytransformationenginegte/)

---

## Hızlı Kurulum (tak-çalıştır)

1. `Prefabs/PSX Effects` prefabını sahneye sürükleyin. **Bu kadar.**
   - Editor otomatik olarak URP renderer'ına `PSX Render Feature`'ı ekler.
   - `Settings/PSX Post Profile.asset` volume profili oluşturulur ve prefaba global Volume olarak bağlanır.
2. Materyallerinizde `PSX/Lit` shader'ını kullanın.
   - Toplu dönüştürme: materyalleri seçin → **Tools → PSX Effects → Seçili Materyalleri PSX-Lit'e Dönüştür**.
3. Dokularınızı PS1 sınırlarına çekin: dokuları seçin →
   **Tools → PSX Effects → Seçili Dokuları PSX-leştir (256 / 64, Point, Mipsiz)**.
4. Manuel kurulum gerekirse: **Tools → PSX Effects → Sahneye Kur**.

> Işıksız (%99 PS1 oyunu gibi) bir görünüm için materyalde **Unlit** açın ve
> sahnenizi vertex color ile boyayın — orijinal paketle aynı mantık.

---

## Bileşenler

### PSX Effects Manager (`PSX Effects` objesi)

Geometri/kamera efektleri — global shader değişkenleriyle tüm PSX/Lit materyallerini yönetir:

| Ayar | Açıklama | Orijinal karşılığı |
|---|---|---|
| Resolution Mode / Fixed 320x240 | Düşük çözünürlük hedefi (Match Aspect: 16:9'da 426x240) | Custom Resolution / Resolution Factor |
| Frame Hold | Görüntüyü N kare tutar | Frame Skip |
| Target Frame Rate | FPS sınırı | Target Framerate |
| Vertex Snapping + Snap Amount | Poligon titremesi (0-1 şiddet) | Vertex Inaccuracy |
| World Space Snapping | Dünya uzayında snap (**donanım davranışı değildir**) | Use World Space Snapping |
| Affine Amount | Doku kayması şiddeti 0-1 (kademeli) | Affine Texture Mapping |
| Draw Distance | Poligon çizim mesafesi | Polygonal Draw Distance |
| **Near Cull Distance** *(yeni)* | Kameraya çok yakın büyük yüzeylerin yok olması | — |
| **Fog Mode / Start / End / Color** *(yeni)* | PS1 depth-cue sisi (1/z'de lineer) | — |
| PSX Style Shadows | Çıkarımsal (subtractive) gölge | Shadow Type: PSX |
| Camera Snapping | Kamera pozisyon titremesi (parent hilesi olmadan) | Camera Inaccuracy |

### PSX Post Process (Volume override)

Volume profilinde **PSX → PSX Post Process**:

- **Color Depth** (5 = 15-bit PS1), **Dither Intensity** (gerçek PS1 4x4 GPU matrisi), **Dither Sky**
- **Favor Red / Subtract Fade** (orijinal ton ayarları)
- **Scanline**, **Interlacing**, **CRT Curvature**, **Vignette**

Volume yoksa bile klasik PS1 varsayılanları otomatik uygulanır.
Sahne bazlı geçişler için local Volume'lar kullanabilirsiniz.

### PSX/Lit Shader

- Render Mode: Opaque / Cutout / Transparent, Blend Op (Add/Subtract/RevSubtract — PS1 yarı-saydamlık modu 2)
- Ignore Depth Buffer, Backface Culling, Unlit, Vertex Colors
- Diffuse Model: Vertex (Gouraud) / Fragment; Specular: Gouraud / Phong
- Normal Map, Specular Map, **Metallic Map** *(yeni)*, Emission, Cubemap (sahte env-map)
- LOD Texture + LOD Distance: mesafeye göre düşük çözünürlüklü dokuya geçiş
- Texture Color Quantization: doku örneklemede bit kırpma (CLUT hissi)
- **PS1 Vertex Colour Modulation (128 = neutral)** *(yeni)*
- **Affine Vertex Shading** *(yeni)*
- **Raw Texture (No Dither)** *(yeni)*
- Vertex Snap Scale ve Affine Override: materyal bazlı geçersiz kılma
- Lightmap, ana ışık gölgeleri, ek ışıklar (Forward ve Forward+/Cluster), sis desteği

---

## Yeni: Metallic Map

PS1'de PBR yoktu. Buradaki metallic, orijinal paketteki **Metal dokusunun** modern
karşılığıdır: bir **sahte env-map maskesi**.

`_MetallicMap` **kırmızı kanalı** × `_Metallic` skaleri = M değeri:

| Etki | Davranış |
|---|---|
| Cubemap yansıması | `M = 0` iken eskisi gibi eklemeli; `M = 1` iken yüzeyin rengini yansıma belirler |
| Yansıma rengi | Metal yansımaları albedo ile renklenir (metallerin yansıması renklidir) |
| Specular | Metal yüzeylerde specular da albedo ile renklenir |
| Cubemap yoksa | M yalnızca diffuse'u kısar (uyarı kutusu inspector'da görünür) |

`_Metallic` varsayılanı **0**'dır — mevcut materyalleriniz birebir aynı kalır.
Metalik bir görünüm için mutlaka bir **Cubemap** atayın; PS1 krom efekti buydu.

---

## PS1 doğruluk anahtarları (yeni, hepsi varsayılan KAPALI)

Bu üçü mevcut sahnenizin görünümünü değiştirebileceği için opt-in bırakıldı.

### PS1 Vertex Colour Modulation (128 = neutral)

Donanımda doku modülasyonunun nötr değeri 255 değil **128**'dir:

```
finalChannel.rgb = (texel.rgb * vertexColour.rgb) / 128.0
```

Yani vertex rengi yüzeyi **2x'e kadar parlatabilir**, sadece karartamaz. PS1 oyunları
bu overbright aralığını ışık parlamaları ve highlight'lar için sürekli kullanırdı.

Açtığınızda vertex renklerinizi `1.0` yerine **`0.5` etrafında** boyayın.

### Affine Vertex Shading

Donanımda Gouraud renkleri de UV'ler gibi perspektif düzeltmesi görmez.
Etkisi UV kaymasından çok daha incedir (psx-spx: *"shading is kinda blurry anyways"*),
büyük ışıklı poligonlarda görünür. **Ekstra interpolator maliyeti yoktur** — `w` zaten
affine UV için taşınıyor.

### Fog Mode: PS1 Depth Cue

Donanımda sis GPU'nun değil GTE'nin işidir ve perspektif bölmesinin yan ürünüdür:

```
MAC0 = (H*20000h/SZ3) * DQA + DQB,  IR0 = MAC0/1000h   (0..1)
[MAC1,MAC2,MAC3] = MAC + (FC - MAC) * IR0
```

Yani sis **z'de değil 1/z'de lineerdir** ve tek bir "far color"a düz lerp edilir.
Manager `fogStart` / `fogEnd` değerlerinden DQA/DQB'yi kendisi hesaplar:

```
DQA = (start * end) / (start - end)
DQB = end / (end - start)
```

---

## Yeni: donanım kuralına göre dither maskesi

psx-spx, dither'ın her yere uygulanmadığını açıkça söyler:

> POLYGONs (triangles/quads) are dithered ONLY if they do use gouraud shading or modulation.
> RECTs are NOT dithered.

Yani **ham (modülasyonsuz) dokulu veya düz gölgeli** bir poligon donanımda hiç dither
almaz — texel'ler zaten 15-bit olduğu için ortada 8-bit ara değer yoktur.

PSX/Lit artık her piksele bir **uygunluk bayrağı** yazar (alpha kanalında) ve post pass
o pikselleri dither'lamaz:

- **Otomatik:** Unlit + Vertex Colors kapalı = ham doku → dither yok
- **Manuel:** materyalde **Raw Texture (No Dither)** toggle'ı
- Transparent materyallerde gerçek alpha korunur (harmanlama için gerekli)

> **Not:** Bu maskenin çalışması için kamera renk hedefinin alpha kanalı olmalıdır.
> URP asset'iniz HDR'de `B10G11R11` gibi alpha'sız bir format kullanıyorsa maske
> kaybolur ve eski davranış (her şeyi dither'la) aynen korunur — hata vermez.

---

## Orijinalden farklar / iyileştirmeler

- `OnRenderImage` yerine **Render Graph** (Unity 6 uyumlu).
- Post ayarları **URP Volume** sistemine taşındı (sahne geçişleri, blend).
- Vertex snap makaledeki gibi **hedef çözünürlük gridine**, **perspektif bölmesinden
  sonra** yapılır — donanım mekanizmasıyla birebir (çözünürlükle tutarlı titreme).
- Affine mapping 0-1 kademeli; `uv*w` / `÷w` yöntemi `noperspective`'den daha taşınabilir.
- Dither dosyası gerekmez; PS1'in **gerçek 4x4 matrisi** (±4/255, Bayer değil) shader içinde.
- Kamera snap parent objesi oluşturmadan, delta takibiyle çalışır.
- Yeni: interlacing, CRT bombeleme, vignette, texture quantization, materyal dönüştürücü,
  doku import aracı, metallic map, PS1 sisi, yakın poligon reddi, dither maskesi.
- Bilinçli çıkarılanlar: otomatik güncelleme denetimi, Ordering Table taklidi
  (Colson'ın da belirttiği gibi Unity'de genelde sadece bozuk görünür).

---

## Notlar

- URP asset'inizde **Depth Texture** açık olmalı (Dither Sky = kapalı kullanılacaksa).
- Renderer **Forward+** modunda ek ışıklar cluster döngüsüyle hesaplanır; tam Gouraud
  nokta ışıkları için Forward modu da kullanabilirsiniz.
- Affine kayması aşırıysa: poligonları bölün (hem Colson hem Sony'nin tavsiyesi) veya
  Affine Amount'u düşürün. Bölme T-junction üretebilir, dikkat.
- ForwardLit pass'i temel varyantta **8 interpolator** kullanır (`target 3.5` garantisi).
  **Normal Map** açıkken 9'a çıkar — normal map zaten PS1 dönemi dışı bir kolaylıktır.
- `_PSX_TargetRes` artık manager tarafından da yazılır; render feature renderer'a
  eklenmemiş olsa bile geometri çökmez (shader tarafında da ayrıca guard vardır).

## Doku import ayarları (shader dışı ama aynı derecede önemli)

| Ayar | Değer | Neden |
|---|---|---|
| Filter Mode | **Point** | Donanımda bilinear filtreleme yok |
| Generate Mip Maps | **Kapalı** | Mipmap yok; mesafe parlaması otantik |
| Max Size | **256** (ideali 64) | Texture page sınırı 256x256 |
| Wrap Mode | Repeat, 2'nin kuvveti boyutlar | Texture window bitwise-AND tabanlı |
| Compression | Uncompressed | DXT bozulması yanlış türden bir çirkinlik |

**Tools → PSX Effects → Seçili Dokuları PSX-leştir** bunların hepsini tek seferde uygular.
