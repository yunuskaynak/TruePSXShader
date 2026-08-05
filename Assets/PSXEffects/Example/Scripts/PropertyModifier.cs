using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

public class PropertyModifier : MonoBehaviour {

	public PSXEffects effects;

	public Text pForProps;
	public Image panel;

	public CameraFlythrough flythrough;

	private bool propsShown = false;

	// Use this for initialization
	void Start () {
		propsShown = false;
		panel.gameObject.SetActive(false);
		pForProps.gameObject.SetActive(true);
	}

	static bool KeyDown_Q() {
#if ENABLE_INPUT_SYSTEM
		return Keyboard.current != null && Keyboard.current.qKey.wasPressedThisFrame;
#else
		return Input.GetKeyDown(KeyCode.Q);
#endif
	}

	// Update is called once per frame
	void Update () {
		if (KeyDown_Q()) {
			propsShown = !propsShown;
			panel.gameObject.SetActive(propsShown);
			pForProps.gameObject.SetActive(!propsShown);

			flythrough.LockCursor(!propsShown);
		}
	}

	public void SetResFactor(InputField input) {
		effects.resolutionFactor = int.Parse(input.text);
	}
	public void SetLimFrame(InputField input) {
		effects.limitFramerate = int.Parse(input.text);
	}
	public void SetDD(InputField input) {
		Debug.Log("Set DD");
		effects.polygonalDrawDistance = int.Parse(input.text);
	}
	public void SetVI(InputField input) {
		effects.vertexInaccuracy = int.Parse(input.text);
	}
	public void SetPI(InputField input) {
		effects.polygonInaccuracy = int.Parse(input.text);
	}
	public void SetCD(InputField input) {
		effects.colorDepth = int.Parse(input.text);
	}

	public void SetScanlines(Toggle input) {
		effects.scanlines = input.isOn;
	}
	public void SetDithering(Toggle input) {
		effects.dithering = input.isOn;
	}

	public void SetSF(Slider input) {
		effects.subtractFade = (int)(input.value * 100);
	}
	public void SetDR(InputField input) {
		effects.favorRed = float.Parse(input.text);
	}
}
