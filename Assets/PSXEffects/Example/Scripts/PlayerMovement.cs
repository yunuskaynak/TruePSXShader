using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

public class PlayerMovement : MonoBehaviour {

	public float moveSpeed = 10f;
	public Light dirLight;
	public GameObject museumText;

	private CharacterController cc;
	private PSXEffects psx;

	// Use this for initialization
	void Start () {
		cc = GetComponent<CharacterController>();
		psx = FindObjectOfType<PSXEffects>();
		dirLight.gameObject.SetActive(false);
		museumText.SetActive(false);
	}

	static float GetVertical() {
#if ENABLE_INPUT_SYSTEM
		var kb = Keyboard.current;
		if (kb == null) return 0f;
		return ((kb.wKey.isPressed || kb.upArrowKey.isPressed) ? 1f : 0f)
		     - ((kb.sKey.isPressed || kb.downArrowKey.isPressed) ? 1f : 0f);
#else
		return Input.GetAxisRaw("Vertical");
#endif
	}

	static float GetHorizontal() {
#if ENABLE_INPUT_SYSTEM
		var kb = Keyboard.current;
		if (kb == null) return 0f;
		return ((kb.dKey.isPressed || kb.rightArrowKey.isPressed) ? 1f : 0f)
		     - ((kb.aKey.isPressed || kb.leftArrowKey.isPressed) ? 1f : 0f);
#else
		return Input.GetAxisRaw("Horizontal");
#endif
	}

	// Update is called once per frame
	void Update () {
		cc.Move((transform.forward * GetVertical() + transform.right * GetHorizontal()).normalized * moveSpeed * Time.deltaTime);
		if (!cc.isGrounded) {
			cc.Move(Vector3.up * Time.deltaTime * Physics.gravity.y);
		}
	}

	void OnTriggerEnter(Collider other) {
		if (other.transform.tag == "DemoRoom") {
			ToggleDemoMode(true);
		}
	}

	void OnTriggerExit(Collider other) {
		if (other.transform.tag == "DemoRoom") {
			ToggleDemoMode(false);
		}
	}

	public void ToggleDemoMode(bool enabled) {
		if (enabled) {
			RenderSettings.fog = false;
			psx.favorRed = 0;
			psx.maxDarkness = 0;
			psx.resolutionFactor = 1;
			psx.polygonalDrawDistance = -1;
			psx.dithering = false;
			psx.colorDepth = 24;
			dirLight.gameObject.SetActive(true);
			museumText.SetActive(true);
			psx.UpdateProperties();
		} else {
			RenderSettings.fog = true;
			psx.favorRed = 1;
			psx.maxDarkness = 10;
			psx.resolutionFactor = 2;
			psx.polygonalDrawDistance = 30.61f;
			psx.dithering = false;
			psx.colorDepth = 24;
			dirLight.gameObject.SetActive(false);
			museumText.SetActive(false);
			psx.UpdateProperties();
		}
	}
}
