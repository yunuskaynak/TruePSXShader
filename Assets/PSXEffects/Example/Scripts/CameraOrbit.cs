using System.Collections;
using System.Collections.Generic;
using UnityEngine;
#if ENABLE_INPUT_SYSTEM
using UnityEngine.InputSystem;
#endif

public class CameraOrbit : MonoBehaviour {

	public Transform origin;
	public float speed = 20;

	public bool scrollControl = false;
	public float scrollSpeed = 10;

	static float ScrollDelta() {
#if ENABLE_INPUT_SYSTEM
		return Mouse.current != null ? Mouse.current.scroll.ReadValue().y / 1200f : 0f;
#else
		return Input.GetAxis("Mouse ScrollWheel");
#endif
	}

	// Update is called once per frame
	void Update () {
		transform.LookAt(origin);
		if (scrollControl)
			transform.Translate(Vector3.forward * ScrollDelta() * scrollSpeed);
		transform.RotateAround(origin.position, origin.transform.up, Time.deltaTime * speed);
	}
}
