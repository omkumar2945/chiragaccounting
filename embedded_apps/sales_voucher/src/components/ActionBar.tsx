interface Props {
  onSave: () => void;
  onSaveAndPrint: () => void;
  onSaveAndNew: () => void;
  onPreview: () => void;
  onCancel: () => void;
}

export default function ActionBar({ onSave, onSaveAndPrint, onSaveAndNew, onPreview, onCancel }: Props) {
  return (
    <footer className="flex items-center justify-between border-t border-slate-200 bg-white px-5 py-3">
      <div className="text-[11px] text-slate-400">
        <kbd className="rounded border border-slate-300 bg-slate-50 px-1.5 py-0.5">Ctrl+S</kbd> Save &nbsp;
        <kbd className="rounded border border-slate-300 bg-slate-50 px-1.5 py-0.5">Ctrl+P</kbd> Print &nbsp;
        <kbd className="rounded border border-slate-300 bg-slate-50 px-1.5 py-0.5">Ctrl+N</kbd> New &nbsp;
        <kbd className="rounded border border-slate-300 bg-slate-50 px-1.5 py-0.5">Esc</kbd> Cancel
      </div>
      <div className="flex gap-2">
        <button
          onClick={onCancel}
          className="rounded-md border border-slate-300 px-4 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-50"
        >
          Cancel
        </button>
        <button
          onClick={onPreview}
          className="rounded-md border border-slate-300 px-4 py-1.5 text-sm font-medium text-slate-600 hover:bg-slate-50"
        >
          Preview
        </button>
        <button
          onClick={onSaveAndNew}
          className="rounded-md border border-blue-300 bg-blue-50 px-4 py-1.5 text-sm font-medium text-blue-700 hover:bg-blue-100"
        >
          Save &amp; New
        </button>
        <button
          onClick={onSaveAndPrint}
          className="rounded-md border border-blue-300 bg-blue-50 px-4 py-1.5 text-sm font-medium text-blue-700 hover:bg-blue-100"
        >
          Save &amp; Print
        </button>
        <button
          onClick={onSave}
          className="rounded-md bg-blue-600 px-5 py-1.5 text-sm font-semibold text-white shadow-sm hover:bg-blue-700"
        >
          Save
        </button>
      </div>
    </footer>
  );
}
