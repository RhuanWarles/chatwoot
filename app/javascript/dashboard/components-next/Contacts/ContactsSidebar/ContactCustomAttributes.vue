<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import Draggable from 'vuedraggable';
import { useMapGetter } from 'dashboard/composables/store';
import { useUISettings } from 'dashboard/composables/useUISettings';
import {
  mergeAttributeOrder,
  reorderSubset,
  sortByAttributeOrder,
} from 'dashboard/helper/attributeOrder';

import ContactCustomAttributeItem from 'dashboard/components-next/Contacts/ContactsSidebar/ContactCustomAttributeItem.vue';

const props = defineProps({
  selectedContact: {
    type: Object,
    default: null,
  },
});

const { t } = useI18n();

const { uiSettings, updateUISettings } = useUISettings();

// The same key the conversation sidebar uses, so both screens show the attributes in one order.
const ORDER_KEY = 'conversation_elements_order_conversation_contact_panel';

const searchQuery = ref('');

const contactAttributes = useMapGetter('attributes/getContactAttributes') || [];

const hasContactAttributes = computed(
  () => contactAttributes.value?.length > 0
);

const processContactAttributes = (
  attributes,
  customAttributes,
  filterCondition
) => {
  if (!attributes.length || !customAttributes) {
    return [];
  }

  return attributes.reduce((result, attribute) => {
    const { attributeKey } = attribute;
    const meetsCondition = filterCondition(attributeKey, customAttributes);

    if (meetsCondition) {
      result.push({
        ...attribute,
        value: customAttributes[attributeKey] ?? '',
      });
    }

    return result;
  }, []);
};

const savedOrder = computed(() => uiSettings.value[ORDER_KEY] ?? []);

const sortByUISettings = attributes =>
  sortByAttributeOrder(
    attributes,
    ({ attributeKey }) => attributeKey,
    savedOrder.value
  );

// A list was reordered: its attributes keep their places among all the others, and elements this page does not show stay put.
const saveListOrder = reordered => {
  const allKeys = sortByUISettings(contactAttributes.value).map(
    ({ attributeKey }) => attributeKey
  );
  const order = reorderSubset(
    allKeys,
    reordered.map(({ attributeKey }) => attributeKey)
  );
  updateUISettings({
    [ORDER_KEY]: mergeAttributeOrder(savedOrder.value, order),
  });
};

const usedAttributes = computed(() => {
  const attributes = processContactAttributes(
    contactAttributes.value,
    props.selectedContact?.customAttributes,
    (key, custom) => key in custom
  );

  return sortByUISettings(attributes);
});

const unusedAttributes = computed(() => {
  const attributes = processContactAttributes(
    contactAttributes.value,
    props.selectedContact?.customAttributes,
    (key, custom) => !(key in custom)
  );

  return sortByUISettings(attributes);
});

const filteredUnusedAttributes = computed(() => {
  return unusedAttributes.value?.filter(attribute =>
    attribute.attributeDisplayName
      .toLowerCase()
      .includes(searchQuery.value.toLowerCase())
  );
});

const unusedAttributesCount = computed(() => unusedAttributes.value?.length);
const hasNoUnusedAttributes = computed(() => unusedAttributesCount.value === 0);
const hasNoUsedAttributes = computed(() => usedAttributes.value.length === 0);
</script>

<template>
  <div v-if="hasContactAttributes" class="flex flex-col gap-6 px-6">
    <Draggable
      v-if="!hasNoUsedAttributes"
      :model-value="usedAttributes"
      item-key="id"
      tag="div"
      class="flex flex-col gap-2"
      handle=".attribute-drag-handle"
      animation="200"
      @update:model-value="saveListOrder"
    >
      <template #item="{ element: attribute }">
        <div class="flex items-center gap-1" data-test="used-attribute">
          <span
            class="attribute-drag-handle i-lucide-grip-vertical size-4 shrink-0 cursor-grab text-n-slate-10"
            :title="t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.DRAG_TO_REORDER')"
            aria-hidden="true"
          />
          <div class="min-w-0 flex-1">
            <ContactCustomAttributeItem
              is-editing-view
              :attribute="attribute"
            />
          </div>
        </div>
      </template>
    </Draggable>
    <div v-if="!hasNoUnusedAttributes" class="flex items-center gap-3">
      <div class="flex-1 h-[1px] bg-n-slate-5" />
      <span class="text-sm font-medium text-n-slate-10">{{
        t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.UNUSED_ATTRIBUTES', {
          count: unusedAttributesCount,
        })
      }}</span>
      <div class="flex-1 h-[1px] bg-n-slate-5" />
    </div>
    <div class="flex flex-col gap-3">
      <div v-if="!hasNoUnusedAttributes" class="relative">
        <span class="absolute i-lucide-search size-3.5 top-2 left-3" />
        <input
          v-model="searchQuery"
          type="search"
          :placeholder="
            t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.SEARCH_PLACEHOLDER')
          "
          class="w-full h-8 py-2 pl-10 pr-2 text-sm reset-base outline-none border-none rounded-lg bg-n-alpha-black2 dark:bg-n-solid-1 text-n-slate-12"
        />
      </div>
      <div
        v-if="filteredUnusedAttributes.length === 0 && !hasNoUnusedAttributes"
        class="flex items-center justify-start h-11"
      >
        <p class="text-sm text-n-slate-11">
          {{ t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.NO_ATTRIBUTES') }}
        </p>
      </div>
      <Draggable
        v-if="!hasNoUnusedAttributes"
        :model-value="filteredUnusedAttributes"
        item-key="id"
        tag="div"
        class="flex flex-col gap-2"
        handle=".attribute-drag-handle"
        animation="200"
        :disabled="Boolean(searchQuery)"
        @update:model-value="saveListOrder"
      >
        <template #item="{ element: attribute }">
          <div class="flex items-center gap-1" data-test="unused-attribute">
            <span
              v-if="!searchQuery"
              class="attribute-drag-handle i-lucide-grip-vertical size-4 shrink-0 cursor-grab text-n-slate-10"
              :title="t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.DRAG_TO_REORDER')"
              aria-hidden="true"
            />
            <div class="min-w-0 flex-1">
              <ContactCustomAttributeItem :attribute="attribute" />
            </div>
          </div>
        </template>
      </Draggable>
    </div>
  </div>
  <p v-else class="px-6 py-10 text-sm leading-6 text-center text-n-slate-11">
    {{ t('CONTACTS_LAYOUT.SIDEBAR.ATTRIBUTES.EMPTY_STATE') }}
  </p>
</template>
