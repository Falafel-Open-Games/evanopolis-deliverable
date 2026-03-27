import React from "react";
import ReactDOM from "react-dom/client";

import { LaunchApp } from "./LaunchApp";
import "./styles.css";
import "./launch-styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <LaunchApp />
  </React.StrictMode>,
);
