import { mount } from '@vue/test-utils';
import { nextTick, ref } from 'vue';
import { createI18n } from 'vue-i18n';
import { beforeAll, describe, expect, it, vi } from 'vitest';
import messages from 'dashboard/i18n/locale/en/automation.json';
import { buildLookups } from '../lookups';
import { hydrateGraph } from '../graph';
import { NODE_ISSUES_KEY } from '../workflowContext';
import WorkflowCanvas from './WorkflowCanvas.vue';

const i18n = createI18n({
  legacy: false,
  locale: 'en',
  messages: { en: messages },
  missingWarn: false,
  fallbackWarn: false,
});

vi.mock('../useWorkflowLookups', () => ({
  useWorkflowLookups: () => ({
    lookups: ref(
      buildLookups(
        {
          lostReasons: [{ id: 5, name: 'Sem orçamento', active: true }],
          pipelines: [
            {
              id: 1,
              name: 'Vendas',
              stages: [{ id: 10, name: 'Proposta', position: 1 }],
            },
          ],
        },
        i18n.global.t
      )
    ),
  }),
}));

beforeAll(() => {
  // jsdom has no layout engine: Vue Flow needs these to measure the viewport.
  vi.stubGlobal(
    'ResizeObserver',
    vi.fn(() => ({ observe: vi.fn(), unobserve: vi.fn(), disconnect: vi.fn() }))
  );
  vi.stubGlobal(
    'DOMMatrixReadOnly',
    vi.fn(() => ({ m22: 1 }))
  );
});

const graph = {
  nodes: [
    {
      id: 't',
      type: 'trigger',
      position: { x: 0, y: 0 },
      data: { event: 'crm_deal_lost' },
    },
    {
      id: 's',
      type: 'switch',
      position: { x: 320, y: 0 },
      data: { field: 'deal.lost_reason_id', cases: [{ id: 'c1', value: '5' }] },
    },
    {
      id: 'm',
      type: 'action',
      position: { x: 640, y: 0 },
      data: {
        action: 'move_deal',
        params: { pipeline_id: 1, pipeline_stage_id: 10, reopen: true },
      },
    },
  ],
  edges: [
    { id: 'e1', source: 't', sourceHandle: 'out', target: 's' },
    { id: 'e2', source: 's', sourceHandle: 'c1', target: 'm' },
  ],
};

const mountCanvas = () => {
  const { nodes, edges } = hydrateGraph(graph);
  return mount(WorkflowCanvas, {
    props: { nodes, edges },
    global: {
      plugins: [i18n],
      directives: { tooltip: {} },
      provide: {
        [NODE_ISSUES_KEY]: ref({
          m: [{ nodeId: 'm', code: 'PARAM_REQUIRED' }],
        }),
      },
    },
  });
};

describe('WorkflowCanvas', () => {
  it('renders one block per node with a readable summary', async () => {
    const wrapper = mountCanvas();
    await nextTick();

    const text = wrapper.text();
    expect(text).toContain('Deal lost');
    expect(text).toContain('Route by value');
    expect(text).toContain('Sem orçamento');
    expect(text).toContain('Vendas › Proposta');
    expect(wrapper.findAll('.vue-flow__node')).toHaveLength(3);
  });

  it('labels the handles of a switch with its cases and the default branch', async () => {
    const wrapper = mountCanvas();
    await nextTick();

    const switchNode = wrapper.find('.vue-flow__node-switch');
    expect(switchNode.text()).toContain('Sem orçamento');
    expect(switchNode.text()).toContain('Anything else');
    expect(switchNode.findAll('.vue-flow__handle.source')).toHaveLength(2);
  });

  it('adds a selected node of the requested type', async () => {
    const wrapper = mountCanvas();
    await nextTick();

    wrapper.vm.addNode('wait', {});
    await nextTick();

    const [nodes] = wrapper.emitted('update:nodes').at(-1);
    expect(nodes.at(-1)).toMatchObject({ type: 'wait', selected: true });
    expect(wrapper.emitted('select').at(-1)).toEqual([nodes.at(-1).id]);
  });
});
