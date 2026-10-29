// Injection key: map of node id -> validation issues, already filtered by "show validation".
export const NODE_ISSUES_KEY = Symbol('workflowNodeIssues');

// Visual identity per kind of block (n-* tokens). Triggers, logic and actions get one color each.
export const NODE_TONES = {
  trigger: {
    header: 'bg-n-amber-3 text-n-amber-11',
    icon: 'text-n-amber-11',
  },
  logic: {
    header: 'bg-n-blue-3 text-n-blue-11',
    icon: 'text-n-blue-11',
  },
  action: {
    header: 'bg-n-teal-3 text-n-teal-11',
    icon: 'text-n-teal-11',
  },
};

export const HANDLE_TONES = {
  positive: '!bg-n-teal-9',
  negative: '!bg-n-ruby-9',
  neutral: '!bg-n-blue-9',
  muted: '!bg-n-slate-8',
};

// dataTransfer type used when a palette item is dragged onto the canvas.
export const DRAG_MIME = 'application/x-workflow-node';
