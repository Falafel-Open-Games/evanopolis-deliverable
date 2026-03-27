import type { AuthSession } from "../lib/auth";

type SignInPanelProps = {
  authSession: AuthSession | null;
  authStatusMessage: string;
  isConnectingWallet: boolean;
  onConnectWallet: () => void;
};

export function SignInPanel({
  authSession,
  authStatusMessage,
  isConnectingWallet,
  onConnectWallet,
}: SignInPanelProps) {
  const isSignedIn = authSession !== null;

  return (
    <section className="panel panel-wide" id="sign-in">
      <div className="panel-heading">
        <h2>Sign In</h2>
        <span>Connect your wallet to continue</span>
      </div>
      <div className="status-block">
        <p>
          {isSignedIn
            ? "Wallet connected. You can now continue."
            : "Please sign in first by connecting your wallet."}
        </p>
        {!isSignedIn ? <p>{authStatusMessage}</p> : null}
      </div>
      <div className="button-row">
        <button
          className="button-secondary"
          type="button"
          disabled={isConnectingWallet || isSignedIn}
          onClick={onConnectWallet}
        >
          {isSignedIn
            ? "Wallet Connected"
            : isConnectingWallet
              ? "Connecting..."
              : "Connect Wallet"}
        </button>
      </div>
    </section>
  );
}
