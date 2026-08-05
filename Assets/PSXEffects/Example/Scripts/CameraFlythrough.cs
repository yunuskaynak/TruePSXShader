using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

public class CameraFlythrough : MonoBehaviour {

	public float sensitivity = 2f;
	public float camSpeed = 10f;

	private float yaw;
	private float pitch;

	// Use this for initialization
	void Start () {
		Cursor.lockState = CursorLockMode.Locked;
		Cursor.visible = false;
	}

	static Vector2 MouseDelta() {
#if ENABLE_INPUT_SYSTEM
		return Mouse.current != null ? Mouse.current.delta.ReadValue() * 0.1f : Vector2.zero;
#else
		return new Vector2(Input.GetAxis("Mouse X"), Input.GetAxis("Mouse Y"));
#endif
	}

	static float ScrollDelta() {
#if ENABLE_INPUT_SYSTEM
		// Legacy "Mouse ScrollWheel" ~ kademe basina 0.1 (yeni sistemde 120)
		return Mouse.current != null ? Mouse.current.scroll.ReadValue().y / 1200f : 0f;
#else
		return Input.GetAxisRaw("Mouse ScrollWheel");
#endif
	}

	static float GetAxisKeys(bool vertical) {
#if ENABLE_INPUT_SYSTEM
		var kb = Keyboard.current;
		if (kb == null) return 0f;
		if (vertical)
			return ((kb.wKey.isPressed || kb.upArrowKey.isPressed) ? 1f : 0f)
			     - ((kb.sKey.isPressed || kb.downArrowKey.isPressed) ? 1f : 0f);
		return ((kb.dKey.isPressed || kb.rightArrowKey.isPressed) ? 1f : 0f)
		     - ((kb.aKey.isPressed || kb.leftArrowKey.isPressed) ? 1f : 0f);
#else
		return Input.GetAxis(vertical ? "Vertical" : "Horizontal");
#endif
	}

	// Update is called once per frame
	void Update () {
		if (!Cursor.visible) {
			Vector2 md = MouseDelta();
			yaw += md.x * sensitivity;
			pitch -= md.y * sensitivity;

			camSpeed += ScrollDelta() * 50;
		}

		transform.eulerAngles = new Vector3(pitch, yaw, 0);

		transform.Translate(camSpeed * Time.deltaTime * Vector3.forward * GetAxisKeys(true));
		transform.Translate(camSpeed * Time.deltaTime * Vector3.right * GetAxisKeys(false));
	}

	public void LockCursor(bool lockIt) {
		if (lockIt) {
			Cursor.lockState = CursorLockMode.Locked;
		} else {
			Cursor.lockState = CursorLockMode.None;
		}

		Cursor.visible = !lockIt;
	}
}
