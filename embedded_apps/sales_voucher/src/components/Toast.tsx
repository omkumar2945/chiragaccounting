interface ToastProps {
  message: string;
  kind: 'success' | 'error';
  onClose: () => void;
}

export default function Toast({ message, kind, onClose }: ToastProps) {
  const isSuccess = kind === 'success';
  return (
    <div className="fixed bottom-6 right-6 z-50 animate-toast-in">
      <div
        className={`flex items-center gap-3 rounded-lg px-4 py-3 shadow-lg text-sm font-medium text-white ${
          isSuccess ? 'bg-emerald-600' : 'bg-rose-600'
        }`}
      >
        <span className="text-lg leading-none">{isSuccess ? '✓' : '⚠'}</span>
        <span>{message}</span>
        <button
          onClick={onClose}
          className="ml-2 text-white/80 hover:text-white text-xs font-semibold"
          aria-label="Dismiss"
        >
          ✕
        </button>
      </div>
    </div>
  );
}
