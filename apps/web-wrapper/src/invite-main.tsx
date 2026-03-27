import React from "react";
import ReactDOM from "react-dom/client";

import { InviteApp } from "./InviteApp";
import "./styles.css";
import "./invite-styles.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <InviteApp />
  </React.StrictMode>,
);
