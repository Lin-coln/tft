import { createRoot } from "react-dom/client";
import { StrictMode, useEffect } from "react";

import "./index.css";
import { connect, useEvents, useEventStore } from "./stores/event";

const app = (
  <StrictMode>
    <App />
  </StrictMode>
);

const elem = document.getElementById("root")!;
if (import.meta.hot) {
  // With hot module reloading, `import.meta.hot.data` is persisted.
  const root = (import.meta.hot.data.root ??= createRoot(elem));
  root.render(app);
} else {
  // The hot module reloading API is not available in production.
  createRoot(elem).render(app);
}

function App() {
  useEffect(() => connect(), []);

  const clientId = useEventStore((s) => s.clientId);

  useEvents((event) => {
    console.log(event);
  });

  return (
    <div>
      <h2>{clientId}</h2>
      Lorem ipsum dolor sit amet, consectetur adipisicing elit. Alias aspernatur, aut cupiditate
      dolorum earum enim fugiat ipsum iusto labore nemo nobis officia officiis porro qui tempora
      unde veritatis voluptates voluptatum.
    </div>
  );
}
