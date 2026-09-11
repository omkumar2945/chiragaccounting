interface ConfirmDialogProps {
  title: string;
  message: string;
  confirmLabel?: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export default function ConfirmDialog({
  title,
  message,
  confirmLabel = 'Confirm',
  onConfirm,
  onCancel,
}: ConfirmDialogProps) {
  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/40">
      <div className="w-[380px] rounded-lg bg-white shadow-xl border border-slate-200">
        <div className="flex items-center gap-2 border-b border-slate-200 px-4 py-3">
          <span className="text-amber-500 text-lg">⚠</span>
          <h3 className="text-sm font-semibold text-slate-800">{title}</h3>
        </div>
        <div className="px-4 py-4 text-sm text-slate-600">{message}</div>
        <div className="flex justify-end gap-2 border-t border-slate-200 px-4 py-3">
          <button
            onClick={onCancel}
            className="rounded-md border border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="rounded-md bg-amber-500 px-3 py-1.5 text-xs font-semibold text-white hover:bg-amber-600"
          >
            {confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
