import {
  formatGroupMentionContent,
  resolveMention,
} from '../groupMentionRendering';

const participants = [
  {
    lid: '27114849988829@lid',
    jid: '556294808700@s.whatsapp.net',
    phone: '556294808700',
    contact_name: 'RWHub',
    whatsapp_name: 'Nome WhatsApp',
  },
  {
    lid: '181419536064672@lid',
    jid: '556291212010@s.whatsapp.net',
    phone: '556291212010',
    contact_name: 'Rhuan',
  },
];

describe('group mention presentation', () => {
  it.each([
    '27114849988829',
    '27114849988829@lid',
    '556294808700',
    '556294808700@s.whatsapp.net',
  ])(
    'resolves %s to the saved contact without treating a LID as a phone',
    identifier => {
      expect(resolveMention(identifier, participants).display_name).toBe(
        'RWHub'
      );
    }
  );

  it('uses the Evolution name when there is no saved contact', () => {
    expect(
      resolveMention('27114849988829', [
        { ...participants[0], contact_name: null },
      ]).display_name
    ).toBe('Nome WhatsApp');
  });

  it('formats the actual phone when names are missing', () => {
    expect(
      resolveMention('27114849988829', [
        { ...participants[0], contact_name: null, whatsapp_name: null },
      ]).display_name
    ).toBe('+55 62 9480-8700');
  });

  it('uses structured identity metadata even when a participant has left the group', () => {
    expect(
      resolveMention(
        '27114849988829',
        [],
        [
          {
            ...participants[0],
            display_name: 'Nome selecionado',
            contact_name: null,
            whatsapp_name: null,
          },
        ]
      ).display_name
    ).toBe('Nome selecionado');
  });

  it('keeps an unknown number unresolved rather than guessing its identity', () => {
    expect(resolveMention('999999999999999', participants)).toBeNull();
  });

  it('renders multiple raw identifiers from history without mutating content', () => {
    const message = { content: '@27114849988829, fale com @181419536064672.' };
    const html = formatGroupMentionContent(message.content, participants);
    expect(html).toContain('@RWHub</span>');
    expect(html).toContain('@Rhuan</span>');
    expect(html).not.toContain('27114849988829');
    expect(message.content).toBe('@27114849988829, fale com @181419536064672.');
  });

  it.each(['@27114849988829@lid', '@556294808700@s.whatsapp.net'])(
    'renders the complete suffixed identifier %s',
    content => {
      const html = formatGroupMentionContent(content, participants);
      expect(html).toContain('@RWHub</span>');
      expect(html).not.toContain('@lid');
      expect(html).not.toContain('@s.whatsapp.net');
    }
  );

  it('resolves an existing human label by its metadata identity and current Contact name', () => {
    const html = formatGroupMentionContent('Oi @Nome anterior', participants, [
      {
        lid: participants[0].lid,
        display_name: 'Nome anterior',
        start: 3,
        end: 17,
      },
    ]);
    expect(html).toContain('@RWHub</span>');
  });

  it('distinguishes selected people with identical names and ignores a manually typed name', () => {
    const mentions = [
      { lid: participants[0].lid, display_name: 'Nome', start: 6, end: 11 },
      { lid: participants[1].lid, display_name: 'Nome', start: 12, end: 17 },
    ];
    const html = formatGroupMentionContent(
      '@Nome @Nome @Nome',
      participants,
      mentions
    );
    expect(html).toContain('<p>@Nome <span');
    expect(html).toContain('@RWHub</span> <span');
    expect(html).toContain('@Rhuan</span>');
    expect(mentions[0].display_name).toBe('Nome');
  });

  it('uses Unicode ranges after an emoji and preserves literal metadata inside code', () => {
    const html = formatGroupMentionContent('👋 @Nome `@Nome`', participants, [
      { lid: participants[0].lid, display_name: 'Nome', start: 2, end: 7 },
      { lid: participants[1].lid, display_name: 'Nome', start: 9, end: 14 },
    ]);
    expect(html).toContain('👋 <span');
    expect(html).toContain('@RWHub</span>');
    expect(html).toContain('<code>@Nome</code>');
    expect(html).not.toContain('CWGM');
  });

  it('preserves unresolved mentions, email addresses, code and link destinations', () => {
    const html = formatGroupMentionContent(
      '@999999999999999 teste@27114849988829.com `@27114849988829` [link](https://example.com/@27114849988829)',
      participants
    );
    expect(html).toContain('@999999999999999');
    expect(html).toContain('teste@27114849988829.com');
    expect(html).toContain('<code>@27114849988829</code>');
    expect(html).toContain('href="https://example.com/@27114849988829"');
    expect(html).not.toContain('@RWHub');
  });

  it('escapes participant names and keeps Markdown formatting around mentions', () => {
    const html = formatGroupMentionContent('**@27114849988829**', [
      { ...participants[0], contact_name: '<img src=x onerror=alert(1)>' },
    ]);
    expect(html).toContain('<strong><span');
    expect(html).toContain('@&lt;img');
    expect(html).not.toContain('<img');
  });

  it('preserves existing native agent/team mention rendering', () => {
    const html = formatGroupMentionContent(
      '[@Agente](mention://user/1/Agente)',
      participants
    );
    expect(html).toContain('class="prosemirror-mention-node">@Agente</span>');
  });

  it('does not resolve identifiers inside autolinked URLs or fenced code', () => {
    const html = formatGroupMentionContent(
      'https://example.com/@27114849988829\n\n```\n@27114849988829\n```',
      participants
    );
    expect(html).not.toContain('@RWHub');
    expect(html).toContain('https://example.com/@27114849988829</a>');
    expect(html).toContain('<pre><code>@27114849988829');
  });
});
