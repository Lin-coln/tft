import { StrictMode } from "react";
import { createRoot } from "react-dom/client";

import "./index.css";
import { App } from "./views/App";

const app = (
  <StrictMode>
    <App />
  </StrictMode>
);

const elem = document.getElementById("root")!;
if (import.meta.hot) {
  const root = (import.meta.hot.data.root ??= createRoot(elem));
  root.render(app);
} else {
  createRoot(elem).render(app);
}
