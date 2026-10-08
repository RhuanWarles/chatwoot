<script setup>
import { ref } from 'vue';
import { useI18n } from 'vue-i18n';
import Button from 'dashboard/components-next/button/Button.vue';
import Popover from 'dashboard/components-next/popover/Popover.vue';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import ComposeConversation from 'dashboard/components-next/NewConversation/ComposeConversation.vue';
import CreateWhatsappGroup from './CreateWhatsappGroup.vue';

const { t } = useI18n();
const menu = ref(null);
const composer = ref(null);
const menuItems = available => [
  {
    label: t('WHATSAPP_GROUPS.NEW_CONVERSATION'),
    action: 'conversation',
    icon: 'i-lucide-message-square-plus',
  },
  ...(available
    ? [
        {
          label: t('WHATSAPP_GROUPS.NEW_GROUP'),
          action: 'group',
          icon: 'i-lucide-users-round',
        },
      ]
    : []),
];
const create = ({ action }, openGroup) => {
  menu.value.hide();
  if (action === 'group') openGroup();
  else composer.value.open();
};
</script>

<template>
  <div class="inline-flex shrink-0">
    <ComposeConversation ref="composer">
      <template #trigger />
    </ComposeConversation>
    <CreateWhatsappGroup>
      <template #trigger="{ available, open }">
        <Popover ref="menu" align="end">
          <Button
            icon="i-lucide-plus"
            variant="ghost"
            color="slate"
            size="xs"
            :aria-label="t('WHATSAPP_GROUPS.CREATE_MENU')"
            :title="t('WHATSAPP_GROUPS.CREATE_MENU')"
          />
          <template #content>
            <DropdownMenu
              class="!relative w-56 max-w-full"
              :menu-items="menuItems(available)"
              @action="create($event, open)"
            />
          </template>
        </Popover>
      </template>
    </CreateWhatsappGroup>
  </div>
</template>
