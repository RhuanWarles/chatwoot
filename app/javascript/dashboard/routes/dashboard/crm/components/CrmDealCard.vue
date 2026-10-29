<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useMapGetter } from 'dashboard/composables/store';
import Avatar from 'dashboard/components-next/avatar/Avatar.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import DropdownBody from 'dashboard/components-next/dropdown-menu/base/DropdownBody.vue';
import DropdownContainer from 'dashboard/components-next/dropdown-menu/base/DropdownContainer.vue';
import DropdownItem from 'dashboard/components-next/dropdown-menu/base/DropdownItem.vue';
import { provideDropdownTeleport } from 'dashboard/components-next/dropdown-menu/base/provider';
import Label from 'dashboard/components-next/label/Label.vue';
import { DEFAULT_CARD_FIELDS } from './cardConfig';
import { formatContactPhone } from './contactHelpers';
import { brlFormatter } from './currencyHelpers';
import {
  formatCustomFieldValue,
  isEmptyCustomValue,
} from './customFieldHelpers';

const props = defineProps({
  deal: { type: Object, required: true },
  fields: { type: Array, default: () => DEFAULT_CARD_FIELDS },
  customFieldIds: { type: Array, default: () => [] },
  now: { type: Number, default: () => Date.now() },
});
// `open` opens the conversation of the customer; `openDeal` opens the deal page.
const emit = defineEmits(['open', 'openDeal', 'edit', 'setStatus']);
const MAX_LABELS = 3;
const ACTIVITY_NEAR_WINDOW_MS = 2 * 60 * 60 * 1000;
const STATUS_ACTIONS = {
  won: { label: 'CRM.MARK_WON', icon: 'i-lucide-trophy' },
  lost: { label: 'CRM.MARK_LOST', icon: 'i-lucide-circle-x' },
  open: { label: 'CRM.REOPEN_DEAL', icon: 'i-lucide-rotate-ccw' },
};
const DATE_ROWS = [
  {
    key: 'created_at',
    icon: 'i-lucide-calendar-plus',
    label: 'CRM.CARD_CREATED_ON',
  },
  { key: 'updated_at', icon: 'i-lucide-history', label: 'CRM.CARD_UPDATED_ON' },
];

const { t, locale } = useI18n();
const accountLabels = useMapGetter('labels/getLabels');
// The menu renders on <body>: the column list scrolls and would clip it.
provideDropdownTeleport();

const shows = key => props.fields.includes(key);
// The reason of a lost deal, with the note of whoever marked it as the tooltip.
const lostReason = computed(() => {
  const name = props.deal.status === 'lost' && props.deal.lost_reason?.name;
  if (!name) return null;
  const text = t('CRM.LOST_REASON_LINE', { reason: name });
  const note = props.deal.lost_note
    ? t('CRM.LOST_REASON_NOTE_LINE', { note: props.deal.lost_note })
    : '';
  return { text, title: [text, note].filter(Boolean).join('\n') };
});
const availableStatuses = computed(() =>
  Object.keys(STATUS_ACTIONS).filter(status => status !== props.deal.status)
);
const shortDate = value =>
  new Intl.DateTimeFormat(locale.value.replace('_', '-'), {
    dateStyle: 'short',
  }).format(new Date(value));

const labelChips = computed(() =>
  shows('labels')
    ? (props.deal.labels || []).map(
        title =>
          accountLabels.value.find(label => label.title === title) || { title }
      )
    : []
);
const hiddenLabels = computed(() => labelChips.value.slice(MAX_LABELS));
const hiddenLabelTitles = computed(() =>
  hiddenLabels.value.map(chip => chip.title).join(', ')
);
const moreLabelsText = computed(() => '+' + hiddenLabels.value.length);

const infoRows = computed(() => {
  const { contact } = props.deal;
  return [
    { key: 'contact', icon: 'i-lucide-user', text: contact?.name },
    {
      key: 'phone',
      icon: 'i-lucide-phone',
      text: formatContactPhone(contact?.phone_number),
    },
    { key: 'email', icon: 'i-lucide-mail', text: contact?.email },
    {
      key: 'company',
      icon: 'i-lucide-building-2',
      text:
        contact?.company?.name || contact?.additional_attributes?.company_name,
    },
  ].filter(row => shows(row.key) && row.text);
});
const amount = computed(() =>
  shows('value') && props.deal.value != null && props.deal.value !== ''
    ? brlFormatter.format(Number(props.deal.value))
    : ''
);
const customRows = computed(() =>
  props.customFieldIds
    .map(id =>
      props.deal.custom_field_values?.find(item => item.custom_field_id === id)
    )
    .filter(
      item => item?.custom_field.active && !isEmptyCustomValue(item.typed_value)
    )
    .map(item => {
      const { name, field_type: fieldType } = item.custom_field;
      const text = String(
        formatCustomFieldValue(fieldType, item.typed_value, {
          t,
          locale: locale.value,
        })
      );
      return {
        id: item.custom_field_id,
        label: name + ':',
        text,
        title: name + ': ' + text,
      };
    })
);
const dateRows = computed(() =>
  DATE_ROWS.filter(row => shows(row.key) && props.deal[row.key]).map(row => ({
    ...row,
    text: t(row.label, { date: shortDate(props.deal[row.key]) }),
  }))
);

const activityIsOverdue = activity =>
  new Date(activity.due_at).getTime() < props.now;
const activityIsNear = activity => {
  const dueAt = new Date(activity.due_at).getTime();
  return dueAt >= props.now && dueAt - props.now <= ACTIVITY_NEAR_WINDOW_MS;
};
const activityDate = activity =>
  new Intl.DateTimeFormat(undefined, {
    day: '2-digit',
    month: 'short',
    hour: '2-digit',
    minute: '2-digit',
  }).format(new Date(activity.due_at));
const activityTooltip = activity =>
  [activity.title, activityDate(activity), activity.owner?.name]
    .filter(Boolean)
    .join(' · ');
</script>

<template>
  <article
    class="flex flex-col flex-shrink-0 min-w-0 gap-1.5 p-2.5 rounded-lg border border-n-weak bg-n-background shadow-sm cursor-grab transition-colors hover:border-n-strong"
    @click="emit('open')"
  >
    <div class="flex items-start justify-between gap-1">
      <p
        :title="deal.name"
        class="flex-1 min-w-0 mb-0 font-medium text-n-slate-12 line-clamp-2 [overflow-wrap:anywhere]"
      >
        {{ deal.name }}
      </p>
      <div class="flex items-center flex-shrink-0">
        <Button
          type="button"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-pencil"
          :aria-label="t('CRM.QUICK_EDIT')"
          @click.stop="emit('edit')"
        />
        <Button
          type="button"
          variant="ghost"
          color="slate"
          size="xs"
          icon="i-lucide-external-link"
          :aria-label="t('CRM.LEAD_OPEN_DEAL')"
          @click.stop="emit('openDeal')"
        />
        <DropdownContainer>
          <template #trigger="{ toggle, isOpen }">
            <Button
              type="button"
              variant="ghost"
              color="slate"
              size="xs"
              icon="i-lucide-ellipsis-vertical"
              :aria-label="t('CRM.DEAL_ACTIONS')"
              aria-haspopup="menu"
              :aria-expanded="isOpen"
              @click.stop="toggle"
            />
          </template>
          <DropdownBody class="min-w-44">
            <DropdownItem
              v-for="status in availableStatuses"
              :key="status"
              :label="t(STATUS_ACTIONS[status].label)"
              :icon="STATUS_ACTIONS[status].icon"
              :click="() => emit('setStatus', status)"
            />
          </DropdownBody>
        </DropdownContainer>
      </div>
    </div>
    <div v-if="labelChips.length" class="flex flex-wrap items-center gap-1">
      <Label
        v-for="chip in labelChips.slice(0, MAX_LABELS)"
        :key="chip.title"
        :label="chip"
        compact
        class="max-w-full overflow-hidden"
      />
      <span
        v-if="hiddenLabels.length"
        :title="hiddenLabelTitles"
        class="text-xs text-n-slate-11"
      >
        {{ moreLabelsText }}
      </span>
    </div>
    <p
      v-for="row in infoRows"
      :key="row.key"
      :title="row.text"
      class="flex items-center min-w-0 gap-1.5 mb-0 text-xs text-n-slate-11"
    >
      <span
        class="flex-shrink-0 size-3.5"
        :class="row.icon"
        aria-hidden="true"
      />
      <span class="min-w-0 truncate">{{ row.text }}</span>
    </p>
    <div
      v-if="amount || deal.status !== 'open'"
      class="flex flex-wrap items-center justify-between gap-1"
    >
      <p v-if="amount" class="mb-0 text-sm font-medium text-n-slate-12">
        {{ amount }}
      </p>
      <span
        v-if="deal.status === 'won'"
        class="inline-flex flex-shrink-0 items-center rounded-md px-2 py-0.5 text-label-small bg-n-teal-3 text-n-teal-11"
      >
        {{ t('CRM.STATUS_WON') }}
      </span>
      <span
        v-else-if="deal.status === 'lost'"
        class="inline-flex flex-shrink-0 items-center rounded-md px-2 py-0.5 text-label-small bg-n-ruby-3 text-n-ruby-11"
      >
        {{ t('CRM.STATUS_LOST') }}
      </span>
    </div>
    <p
      v-if="lostReason"
      :title="lostReason.title"
      class="flex items-center min-w-0 gap-1.5 mb-0 text-xs text-n-ruby-11"
    >
      <span
        class="flex-shrink-0 size-3.5 i-lucide-circle-x"
        aria-hidden="true"
      />
      <span class="min-w-0 truncate">{{ lostReason.text }}</span>
    </p>
    <p
      v-for="row in customRows"
      :key="row.id"
      :title="row.title"
      class="flex min-w-0 gap-1 mb-0 text-xs"
    >
      <span class="flex-shrink-0 max-w-[50%] truncate text-n-slate-10">
        {{ row.label }}
      </span>
      <span class="min-w-0 truncate text-n-slate-12">{{ row.text }}</span>
    </p>
    <p
      v-if="shows('description') && deal.description"
      class="mb-0 text-xs text-n-slate-11 line-clamp-2 [overflow-wrap:anywhere]"
    >
      {{ deal.description }}
    </p>
    <div
      v-if="dateRows.length"
      class="flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-n-slate-10"
    >
      <span
        v-for="row in dateRows"
        :key="row.key"
        class="inline-flex items-center gap-1"
      >
        <span
          class="flex-shrink-0 size-3"
          :class="row.icon"
          aria-hidden="true"
        />
        <span>{{ row.text }}</span>
      </span>
    </div>
    <div
      v-if="shows('owner') && deal.owner"
      :title="deal.owner.name"
      class="flex items-center min-w-0 gap-1.5"
    >
      <Avatar
        :name="deal.owner.name"
        :src="deal.owner.thumbnail || ''"
        :size="16"
        rounded-full
      />
      <span class="min-w-0 truncate text-xs text-n-slate-10">
        {{ deal.owner.name }}
      </span>
    </div>
    <button
      v-if="shows('next_activity') && deal.next_activity"
      data-activity-indicator="true"
      type="button"
      class="flex items-center w-full min-w-0 gap-1.5 pt-2 border-t border-n-weak text-start"
      :title="activityTooltip(deal.next_activity)"
      :aria-label="activityTooltip(deal.next_activity)"
      @click.stop="emit('openDeal')"
    >
      <span
        class="flex-shrink-0"
        :class="
          activityIsOverdue(deal.next_activity)
            ? 'i-lucide-circle-alert text-n-ruby-11'
            : activityIsNear(deal.next_activity)
              ? 'i-lucide-clock-3 text-n-blue-11'
              : 'i-lucide-calendar-clock text-n-slate-11'
        "
      />
      <span class="min-w-0 truncate text-xs text-n-slate-11">
        {{ deal.next_activity.title }}
      </span>
      <span
        class="flex-shrink-0 text-xs"
        :class="
          activityIsOverdue(deal.next_activity)
            ? 'text-n-ruby-11'
            : activityIsNear(deal.next_activity)
              ? 'text-n-blue-11'
              : 'text-n-slate-10'
        "
      >
        {{
          activityIsOverdue(deal.next_activity)
            ? t('CRM.ACTIVITY_OVERDUE')
            : activityDate(deal.next_activity)
        }}
      </span>
    </button>
  </article>
</template>
