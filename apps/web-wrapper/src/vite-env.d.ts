/// <reference types="vite/client" />

type EthereumRequestArguments = {
  method: string;
  params?: unknown[] | Record<string, unknown>;
};

type EthereumProvider = {
  request<T = unknown>(args: EthereumRequestArguments): Promise<T>;
  on?(eventName: string, listener: (...args: unknown[]) => void): void;
  removeListener?(
    eventName: string,
    listener: (...args: unknown[]) => void,
  ): void;
};

interface Window {
  ethereum?: EthereumProvider;
}
