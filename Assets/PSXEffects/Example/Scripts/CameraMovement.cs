using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

public class CameraMovement : MonoBehaviour {

	public float sensitivity = 10f;
	public Text infoText;
	public GameObject menu;

	private Camera cam;
	private bool menuEnabled = false;

	// Use this for initialization
	void Start () {
		cam = GetComponent<Camera>();
		Cursor.lockState = CursorLockMode.Locked;
		Cursor.visible = false;
		menuEnabled = false;
		menu.SetActive(menuEnabled);
	}

	static bool KeyDown_Q() {
#if ENABLE_INPUT_SYSTEM
		return Keyboard.current != null && Keyboard.current.qKey.wasPressedThisFrame;
#else
		return Input.GetKeyDown(KeyCode.Q);
#endif
	}

	static bool KeyDown_E() {
#if ENABLE_INPUT_SYSTEM
		return Keyboard.current != null && Keyboard.current.eKey.wasPressedThisFrame;
#else
		return Input.GetKeyDown(KeyCode.E);
#endif
	}

	static Vector2 MouseDelta() {
#if ENABLE_INPUT_SYSTEM
		// Legacy "Mouse X/Y" ekseni ~ piksel deltasi * 0.1
		return Mouse.current != null ? Mouse.current.delta.ReadValue() * 0.1f : Vector2.zero;
#else
		return new Vector2(Input.GetAxis("Mouse X"), Input.GetAxis("Mouse Y"));
#endif
	}

	// Update is called once per frame
	void Update () {
		infoText.text = "";
		if (KeyDown_Q()) {
			menuEnabled = !menuEnabled;
			menu.SetActive(menuEnabled);
			Cursor.lockState = menuEnabled ? CursorLockMode.None : CursorLockMode.Locked;
			Cursor.visible = menuEnabled;
		}

		if (!menuEnabled) {
			Vector2 md = MouseDelta();
			transform.Rotate(-md.y * sensitivity, 0, 0);
			transform.parent.Rotate(0, md.x * sensitivity, 0);

			RaycastHit hit;
			Ray ray = cam.ViewportPointToRay(new Vector3(0.5f, 0.5f, 0));
			if (Physics.Raycast(ray, out hit)) {
				DemoInfo info = hit.transform.GetComponent<DemoInfo>();
				if (info) {
					infoText.text = "- " + info.info + " -";
				}
				if (KeyDown_E()) {
					if (hit.transform.name == "DMOn")
						FindObjectOfType<PlayerMovement>().ToggleDemoMode(true);
					if (hit.transform.name == "DMOff")
						FindObjectOfType<PlayerMovement>().ToggleDemoMode(false);
				}
			}
		}
	}
}
