import { createRoot } from "react-dom/client";
import { StrictMode } from "react";

import "./index.css";

const app = (
  <StrictMode>
    <div>
      Lorem ipsum dolor sit amet, consectetur adipisicing elit. Accusantium ad alias consectetur
      deleniti ducimus earum, et exercitationem explicabo impedit in magni nam natus nisi pariatur
      porro provident ratione rem velit?
    </div>
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
