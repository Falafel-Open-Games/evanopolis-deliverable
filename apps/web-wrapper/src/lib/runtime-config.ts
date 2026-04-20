export type RuntimeConfig = {
  authBaseUrl: string;
  roomsBaseUrl: string;
  expectedChainId: string;
  gameServerUrl: string;
  graphicalClientUrl: string;
  paymentTokenAddress: string;
  paymentHandlerAddress: string;
  paymentAdapterAddress: string;
};

type RuntimeConfigOverride = Partial<RuntimeConfig>;

function getDevProxyBaseUrl(proxyPath: string): string {
  return `${window.location.origin}${proxyPath}`;
}

function getTunneledAuthBaseUrl(host: string): string | null {
  if (host.startsWith("tabletop-demo.")) {
    return `${window.location.protocol}//${host.replace(/^tabletop-demo\./, "tabletop-demo-auth.")}`;
  }

  if (
    host.startsWith("tabletop-demo-") &&
    host.endsWith(".falafel.com.br")
  ) {
    return `${window.location.protocol}//tabletop-demo-auth.falafel.com.br`;
  }

  return null;
}

function getDefaultAuthBaseUrl(): string {
  const host = window.location.hostname;
  const tunneledAuthBase = getTunneledAuthBaseUrl(host);

  if (import.meta.env.DEV) {
    return getDevProxyBaseUrl("/__auth_proxy__");
  }

  if (host === "localhost" || host === "127.0.0.1") {
    return "http://localhost:3000";
  }

  if (tunneledAuthBase !== null) {
    return tunneledAuthBase;
  }

  return window.location.origin;
}

function getDefaultPaymentAddresses(expectedChainId: string): {
  paymentTokenAddress: string;
  paymentHandlerAddress: string;
  paymentAdapterAddress: string;
} {
  if (expectedChainId === "421614") {
    return {
      paymentTokenAddress: "0x422d3188537b3226c9a3cd47647d363fc5e0d727",
      paymentHandlerAddress: "0x666711a0e1b300d3ba0e5d9579974ebaf28fecdb",
      paymentAdapterAddress: "0x6863896de06241853470205f2df5d6a76f491fe1",
    };
  }

  return {
    paymentTokenAddress: "",
    paymentHandlerAddress: "",
    paymentAdapterAddress: "",
  };
}

export function getRuntimeConfig(): RuntimeConfig {
  const runtimeOverride: RuntimeConfigOverride =
    window.__EVANOPOLIS_CONFIG__ ?? {};
  const configuredExpectedChainId =
    runtimeOverride.expectedChainId?.trim() ||
    import.meta.env.VITE_EXPECTED_CHAIN_ID ||
    "421614";
  const defaultPaymentAddresses = getDefaultPaymentAddresses(
    configuredExpectedChainId,
  );

  return {
    authBaseUrl:
      runtimeOverride.authBaseUrl?.trim() ||
      import.meta.env.VITE_AUTH_BASE_URL ||
      getDefaultAuthBaseUrl(),
    roomsBaseUrl:
      runtimeOverride.roomsBaseUrl?.trim() ||
      import.meta.env.VITE_ROOMS_BASE_URL ||
      (import.meta.env.DEV
        ? getDevProxyBaseUrl("/__rooms_proxy__")
        : "http://127.0.0.1:3001"),
    expectedChainId: configuredExpectedChainId,
    gameServerUrl:
      runtimeOverride.gameServerUrl?.trim() ||
      import.meta.env.VITE_GAME_SERVER_URL ||
      "ws://127.0.0.1:9010",
    graphicalClientUrl:
      runtimeOverride.graphicalClientUrl?.trim() ||
      import.meta.env.VITE_GRAPHICAL_CLIENT_URL ||
      "/graphical-client/index.html",
    paymentTokenAddress:
      runtimeOverride.paymentTokenAddress?.trim() ||
      import.meta.env.VITE_PAYMENT_TOKEN_ADDRESS ||
      defaultPaymentAddresses.paymentTokenAddress,
    paymentHandlerAddress:
      runtimeOverride.paymentHandlerAddress?.trim() ||
      import.meta.env.VITE_PAYMENT_HANDLER_ADDRESS ||
      defaultPaymentAddresses.paymentHandlerAddress,
    paymentAdapterAddress:
      runtimeOverride.paymentAdapterAddress?.trim() ||
      import.meta.env.VITE_PAYMENT_ADAPTER_ADDRESS ||
      defaultPaymentAddresses.paymentAdapterAddress,
  };
}
