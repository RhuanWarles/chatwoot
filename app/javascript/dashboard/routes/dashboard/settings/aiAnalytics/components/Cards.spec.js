import { mount } from '@vue/test-utils';
import { analyticsPayload, emptyPayload, i18n } from '../analyticsFixtures';
import AnalyticsCard from './AnalyticsCard.vue';
import DetailTable from './DetailTable.vue';
import KnowledgeCard from './KnowledgeCard.vue';
import OutcomeCard from './OutcomeCard.vue';
import TokensCard from './TokensCard.vue';
import ToolsCard from './ToolsCard.vue';

const withI18n = (component, props) =>
  mount(component, {
    props: { locale: 'pt-BR', ...props },
    global: { plugins: [i18n()] },
  });
const tile = (wrapper, name) => wrapper.find(`[data-test="${name}"]`).text();

describe('AnalyticsCard', () => {
  const card = props =>
    mount(AnalyticsCard, {
      props: { title: 'Bloco', ...props },
      slots: { default: '<p data-test="content">dados</p>' },
      global: { plugins: [i18n()] },
    });

  it('states the period it covers under the title', () => {
    expect(
      card({ period: 'Este mês · 01/11 a 11/11' })
        .find('[data-test="card-period"]')
        .text()
    ).toBe('Este mês · 01/11 a 11/11');
  });

  it('shows a skeleton while loading, an error with a retry, or the empty message', async () => {
    expect(
      card({ loading: true }).find('[data-test="card-loading"]').exists()
    ).toBe(true);
    expect(card({ loading: true }).find('[data-test="content"]').exists()).toBe(
      false
    );

    const failing = card({ error: true });
    expect(failing.find('[role="alert"]').exists()).toBe(true);
    await failing.find('[data-test="card-error"] button').trigger('click');
    expect(failing.emitted('retry')).toHaveLength(1);

    expect(card({ empty: true }).find('[data-test="card-empty"]').text()).toBe(
      'Sem dados no período'
    );
    expect(card({}).find('[data-test="content"]').exists()).toBe(true);
  });

  it('puts an explanation in an "i" button when it has one', () => {
    const wrapper = card({ info: 'O que isto conta' });

    expect(
      wrapper.find('[data-test="info-tip"]').attributes('aria-label')
    ).toBe('O que isto conta');
    expect(wrapper.find('[data-test="info-tip"]').element.tagName).toBe(
      'BUTTON'
    );
  });
});

describe('OutcomeCard', () => {
  const outcome = (payload = analyticsPayload()) =>
    withI18n(OutcomeCard, {
      summary: payload.summary,
      timeseries: payload.timeseries,
      period: 'p',
    });

  it('splits the conversations into kept and handed off, with counts and shares', () => {
    const items = outcome().findAll('[data-test="share-item"]');

    expect(items[0].text()).toContain('Sem transferência');
    expect(items[0].text()).toContain('27');
    expect(items[0].text()).toContain('96,4%');
    expect(items[1].text()).toContain('1');
    expect(items[1].text()).toContain('3,6%');
  });

  it('lists the operation: turns, turns per conversation, handoff rate and the busiest day', () => {
    const wrapper = outcome();

    expect(tile(wrapper, 'operation-turns')).toContain('187');
    expect(tile(wrapper, 'operation-turns-per-conversation')).toContain('6,7');
    expect(tile(wrapper, 'operation-handoff-rate')).toContain('3,6%');
    expect(tile(wrapper, 'operation-busiest')).toContain('05/11 · 6 conversas');
  });

  it('hides the response time while the API does not measure it, and shows it when it does', () => {
    expect(
      outcome().find('[data-test="operation-response-time"]').exists()
    ).toBe(false);

    const measured = analyticsPayload();
    measured.summary.average_response_ms = 2500;
    expect(tile(outcome(measured), 'operation-response-time')).toContain(
      '2,5 s'
    );
  });

  it('is empty, without 0% anywhere, when no conversation was handled', () => {
    const wrapper = outcome(emptyPayload());

    expect(wrapper.find('[data-test="card-empty"]').exists()).toBe(true);
    expect(wrapper.text()).not.toContain('0%');
  });
});

describe('TokensCard', () => {
  const tokens = (payload = analyticsPayload()) =>
    withI18n(TokensCard, {
      billing: payload.billing,
      summary: payload.summary,
      timeseries: payload.timeseries,
      period: 'p',
    });

  it('estimates the cost of the reference account: about US$ 1,73, US$ 0,06 per conversation', () => {
    const wrapper = tokens();

    expect(tile(wrapper, 'tile-cost')).toContain('US$ 1,73');
    expect(tile(wrapper, 'tile-cost-per-conversation')).toContain('US$ 0,06');
  });

  it('shows input and output with their share of the total', () => {
    const wrapper = tokens();

    expect(tile(wrapper, 'tile-input')).toContain('835.121');
    expect(tile(wrapper, 'tile-input')).toContain('99,2% do total');
    expect(tile(wrapper, 'tile-output')).toContain('6.913');
    expect(tile(wrapper, 'tile-output')).toContain('0,8% do total');
  });

  it('explains the price used in a tooltip', () => {
    const wrapper = tokens();
    const info = wrapper.find('[data-test="tile-cost"] [data-test="info-tip"]');

    expect(info.attributes('aria-label')).toBe(
      'Estimado pelo preço de lista do modelo (gpt-4.1: US$ 2,00 entrada / US$ 8,00 saída por 1M de tokens).'
    );
  });

  it('has no estimate for a model without a price, and says why', () => {
    const payload = analyticsPayload();
    payload.billing.models[0].model = 'some-new-model';
    const wrapper = tokens(payload);

    expect(tile(wrapper, 'tile-cost')).toContain('—');
    expect(tile(wrapper, 'tile-cost-per-conversation')).toContain('—');
    expect(
      wrapper
        .find('[data-test="tile-cost"] [data-test="info-tip"]')
        .attributes('aria-label')
    ).toContain('Não há preço cadastrado');
  });

  it('shows "< US$ 0,01" for a cost below one cent', () => {
    const payload = analyticsPayload();
    payload.billing.models[0].prompt_tokens = 100;
    payload.billing.models[0].completion_tokens = 10;
    payload.billing.prompt_tokens = 100;
    payload.billing.completion_tokens = 10;

    expect(tile(tokens(payload), 'tile-cost')).toContain('< US$ 0,01');
  });

  it('says how many tokens each AI turn sends and generates', () => {
    expect(tokens().find('[data-test="tokens-callout"]').text()).toBe(
      'Cada turno da IA envia ≈ 4,5 mil tokens de entrada e gera ≈ 37 de saída.'
    );
  });

  it('draws the tokens of every day', () => {
    expect(tokens().findAll('[data-test="column"]')).toHaveLength(9);
  });

  it('keeps the credits when the account pays in credits', () => {
    const payload = analyticsPayload();
    payload.billing = {
      ...payload.billing,
      mode: 'platform',
      credits_consumed: 42,
      credits_available: 958,
      average_credits_per_conversation: 1.5,
    };
    const wrapper = tokens(payload);

    expect(wrapper.find('[data-test="credit-tiles"]').text()).toContain('42');
    expect(wrapper.find('[data-test="credit-tiles"]').text()).toContain('958');
    expect(wrapper.find('[data-test="credit-tiles"]').text()).toContain('1,5');
    expect(tokens().find('[data-test="credit-tiles"]').exists()).toBe(false);
  });

  it('shows dashes when turns happened but the provider reported no tokens', () => {
    const payload = analyticsPayload();
    payload.billing = {
      ...payload.billing,
      prompt_tokens: 0,
      completion_tokens: 0,
      total_tokens: 0,
      models: [],
    };
    const wrapper = tokens(payload);

    expect(tile(wrapper, 'tile-input')).toContain('—');
    expect(tile(wrapper, 'tile-cost')).toContain('—');
    expect(wrapper.find('[data-test="tokens-callout"]').exists()).toBe(false);
  });

  it('is empty when the AI did not answer anything', () => {
    expect(
      tokens(emptyPayload()).find('[data-test="card-empty"]').exists()
    ).toBe(true);
  });
});

describe('ToolsCard', () => {
  const tools = (payload = analyticsPayload()) =>
    withI18n(ToolsCard, { tools: payload.tools, period: 'p' });

  it('shows the totals and a bar per tool, the most used first', () => {
    const wrapper = tools();
    const rows = wrapper.findAll('[data-test="tool-row"]');

    expect(tile(wrapper, 'tile-success')).toContain('10');
    expect(tile(wrapper, 'tile-failures')).toContain('2');
    expect(tile(wrapper, 'tile-success-rate')).toContain('83,3%');
    expect(rows).toHaveLength(2);
    expect(rows[0].text()).toContain('buscar_pedido');
    expect(rows[0].text()).toContain('88%');
    expect(rows[0].find('.font-mono').exists()).toBe(true);
  });

  it('paints success green and failures red only when there are some', () => {
    const wrapper = tools();
    expect(
      wrapper
        .find('[data-test="tile-success"] [data-test="tile-value"]')
        .classes()
    ).toContain('text-n-teal-11');
    expect(
      wrapper
        .find('[data-test="tile-failures"] [data-test="tile-value"]')
        .classes()
    ).toContain('text-n-ruby-11');

    const none = analyticsPayload();
    none.tools = { ...none.tools, success: 0, failures: 0 };
    const grey = tools(none);
    expect(
      grey.find('[data-test="tile-success"] [data-test="tile-value"]').classes()
    ).toContain('text-n-slate-11');
    expect(
      grey
        .find('[data-test="tile-failures"] [data-test="tile-value"]')
        .classes()
    ).toContain('text-n-slate-11');
  });

  it('collapses into one line when no tool ran, with no 0% success rate', () => {
    const wrapper = tools(emptyPayload());

    expect(wrapper.find('[data-test="tools-empty"]').text()).toContain(
      'Nenhuma execução de ferramenta'
    );
    expect(wrapper.find('[data-test="tile-success-rate"]').exists()).toBe(
      false
    );
    expect(wrapper.text()).not.toContain('0%');
  });

  it('shows a skeleton while loading, not the empty line', () => {
    const wrapper = withI18n(ToolsCard, { tools: null, loading: true });

    expect(wrapper.find('[data-test="card-loading"]').exists()).toBe(true);
    expect(wrapper.find('[data-test="tools-empty"]').exists()).toBe(false);
  });
});

describe('KnowledgeCard', () => {
  const knowledge = (payload = analyticsPayload()) =>
    withI18n(KnowledgeCard, {
      knowledge: payload.knowledge,
      summary: payload.summary,
      period: 'p',
    });

  it('splits the queries into with and without result, with counts and shares', () => {
    const items = knowledge().findAll('[data-test="share-item"]');

    expect(items[0].text()).toContain('Com resultado');
    expect(items[0].text()).toContain('16');
    expect(items[0].text()).toContain('80%');
    expect(items[1].text()).toContain('Sem resultado');
    expect(items[1].text()).toContain('4');
    expect(items[1].text()).toContain('20%');
  });

  it('says how many conversations used the base out of the handled ones, and the utilization rate', () => {
    const wrapper = knowledge();

    expect(tile(wrapper, 'tile-used')).toContain('9 de 28');
    expect(tile(wrapper, 'tile-utilization')).toContain('32,1%');
  });

  it('lists the questions without a result with how many times each was asked', () => {
    const wrapper = knowledge();
    const items = wrapper.findAll('[data-test="unanswered-list"] li');

    expect(wrapper.text()).toContain('Perguntas sem resultado · 4');
    expect(items).toHaveLength(2);
    expect(items[0].text()).toContain('qual o prazo de entrega?');
    expect(items[0].text()).toContain('3×');
  });

  it('says so when every question found something', () => {
    const payload = analyticsPayload();
    payload.knowledge = { ...payload.knowledge, hits: 20, unanswered: [] };

    expect(
      knowledge(payload).find('[data-test="unanswered-empty"]').exists()
    ).toBe(true);
  });

  it('has no utilization rate when no conversation was handled', () => {
    const payload = analyticsPayload();
    payload.summary = { ...payload.summary, conversations: 0 };

    expect(tile(knowledge(payload), 'tile-utilization')).toContain('—');
  });

  it('is empty, without 0%, when the bases were not queried', () => {
    const wrapper = knowledge(emptyPayload());

    expect(wrapper.text()).toContain('Nenhuma consulta à base de conhecimento');
    expect(wrapper.text()).not.toContain('0%');
  });
});

describe('DetailTable', () => {
  const table = (payload = analyticsPayload()) =>
    withI18n(DetailTable, {
      timeseries: payload.timeseries,
      summary: payload.summary,
      billing: payload.billing,
      period: 'p',
    });
  const cells = row => row.findAll('th, td').map(cell => cell.text());

  it('is a real table with column headers and a row header per day', () => {
    const wrapper = table();

    expect(wrapper.findAll('thead th[scope="col"]')).toHaveLength(5);
    expect(wrapper.findAll('tbody th[scope="row"]')).toHaveLength(11);
    expect(wrapper.find('table caption').exists()).toBe(true);
    expect(wrapper.find('[data-test="detail-scroll"]').classes()).toContain(
      'overflow-auto'
    );
  });

  it('lists the most recent day first', () => {
    const rows = table().findAll('[data-test="detail-row"]');

    expect(cells(rows[0])[0]).toContain('11/11/2026');
    expect(cells(rows[10])[0]).toContain('01/11/2026');
    expect(cells(rows[0]).slice(1)).toEqual(['3', '29', '31', '77.000']);
  });

  it('greys out the days without activity and shows dashes instead of zeros', () => {
    const quiet = table().findAll('[data-test="detail-row"]')[9];

    expect(quiet.attributes('data-active')).toBe('false');
    expect(quiet.classes()).toContain('text-n-slate-10');
    expect(cells(quiet).slice(1)).toEqual(['—', '—', '—', '—']);
  });

  it('tags the busiest day as the peak', () => {
    const tags = table().findAll('[data-test="peak-tag"]');

    expect(tags).toHaveLength(1);
    expect(tags[0].text()).toBe('pico');
    expect(tags[0].element.closest('tr').textContent).toContain('05/11/2026');
  });

  it('closes with the total row, where conversations are the unique ones, marked with an asterisk', () => {
    const wrapper = table();
    const total = wrapper.find('[data-test="total-row"]');

    expect(wrapper.find('tfoot').exists()).toBe(true);
    expect(cells(total)).toEqual(['Total', '28*', '187', '198', '842.034']);
    expect(wrapper.find('[data-test="total-note"]').text()).toContain(
      'A soma diária pode ser maior'
    );
  });

  it('adds a credits column when the account pays in credits', () => {
    const payload = analyticsPayload();
    payload.billing = {
      ...payload.billing,
      mode: 'platform',
      credits_consumed: 42,
    };
    const wrapper = table(payload);

    expect(wrapper.findAll('thead th')).toHaveLength(6);
    expect(cells(wrapper.find('[data-test="total-row"]')).pop()).toBe('42');
  });

  it('is empty when there are no days', () => {
    const wrapper = table({ ...analyticsPayload(), timeseries: [] });

    expect(wrapper.find('[data-test="card-empty"]').exists()).toBe(true);
  });
});
