import React, { useEffect, useState } from "react";

// The backend URL is injected at deploy time via an environment variable
// set in helm/frontend/values-<env>.yaml, so the same image works in
// dev and prod without a rebuild. See ../Dockerfile - both build stages
// run `apk upgrade` so OS package CVEs get patched at build time.
const BACKEND_URL = process.env.REACT_APP_BACKEND_URL || "/api/items";

function App() {
  const [message, setMessage] = useState("Loading...");

  useEffect(() => {
    fetch(BACKEND_URL)
      .then((res) => res.json())
      .then((data) => setMessage(data.message || JSON.stringify(data)))
      .catch(() => setMessage("Could not reach the backend"));
  }, []);

  return (
    <div style={{ fontFamily: "sans-serif", padding: "2rem", textAlign: "center" }}>
      <h1>EKS Platform Demo</h1>
      <p>Frontend deployed via Helm, delivered by ArgoCD, running on EKS.</p>
      <p>Backend says: <strong>{message}</strong></p>
    </div>
  );
}

export default App;
