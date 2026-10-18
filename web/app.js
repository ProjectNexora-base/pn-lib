/* Minimal NUI bridge for WebRTC signaling (panel drives the peer connection). */
window.addEventListener("message", (event) => {
  const data = event.data;
  if (!data || data.action !== "webrtc:signal") return;
  // Future: attach RTCPeerConnection here when panel requests a local stream.
  console.debug("[pn-lib] signal", data.payload);
});

fetch(`https://${GetParentResourceName()}/webrtc:ready`, {
  method: "POST",
  headers: { "Content-Type": "application/json; charset=UTF-8" },
  body: "{}",
}).catch(() => {});
