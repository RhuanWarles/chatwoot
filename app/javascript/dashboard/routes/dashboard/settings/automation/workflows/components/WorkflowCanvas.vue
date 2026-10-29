<script setup>
import { markRaw } from 'vue';
import { VueFlow, useVueFlow } from '@vue-flow/core';
import { Background } from '@vue-flow/background';
import { Controls } from '@vue-flow/controls';
import { MiniMap } from '@vue-flow/minimap';
import '@vue-flow/core/dist/style.css';
import '@vue-flow/core/dist/theme-default.css';
import '@vue-flow/controls/dist/style.css';
import '@vue-flow/minimap/dist/style.css';
import WorkflowNode from './WorkflowNode.vue';
import { NODE_TYPES } from '../constants';
import {
  connectionError,
  createEdge,
  createNode,
  findFreePosition,
} from '../graph';
import { DRAG_MIME } from '../workflowContext';

const emit = defineEmits(['select']);
const GRID = 16;
const NODE_HALF_WIDTH = 128;
const NODE_HALF_HEIGHT = 40;
const MIN_ZOOM = 0.2;
const MAX_ZOOM = 1.5;

const nodes = defineModel('nodes', { type: Array, required: true });
const edges = defineModel('edges', { type: Array, required: true });

const nodeTypes = Object.fromEntries(
  Object.values(NODE_TYPES).map(type => [type, markRaw(WorkflowNode)])
);

const {
  onConnect,
  addEdges,
  onNodeClick,
  onPaneClick,
  screenToFlowCoordinate,
  vueFlowRef,
  fitView,
} = useVueFlow();

const isValidConnection = (connection, elements) =>
  !connectionError(elements.nodes, elements.edges, connection);

onConnect(connection => addEdges([createEdge(connection)]));
onNodeClick(({ node }) => emit('select', node.id));
onPaneClick(() => emit('select', null));

const viewportCenter = () => {
  const rect = vueFlowRef.value?.getBoundingClientRect();
  if (!rect) return { x: 0, y: 0 };
  return screenToFlowCoordinate({
    x: rect.left + rect.width / 2,
    y: rect.top + rect.height / 2,
  });
};

// `position` (a drop point) is the top-left corner; without it the node lands on the viewport center.
const addNode = (type, preset, position) => {
  const origin = position || {
    x: viewportCenter().x - NODE_HALF_WIDTH,
    y: viewportCenter().y - NODE_HALF_HEIGHT,
  };
  const node = createNode(type, {
    position: findFreePosition(nodes.value, origin),
    preset,
  });
  nodes.value = [
    ...nodes.value.map(item => ({ ...item, selected: false })),
    { ...node, selected: true },
  ];
  emit('select', node.id);
};

const onDrop = event => {
  const raw = event.dataTransfer.getData(DRAG_MIME);
  if (!raw) return;
  const { type, preset } = JSON.parse(raw);
  addNode(
    type,
    preset,
    screenToFlowCoordinate({ x: event.clientX, y: event.clientY })
  );
};

const onDragOver = event => {
  event.dataTransfer.dropEffect = 'move';
};

defineExpose({ addNode, fitView });
</script>

<template>
  <div
    class="relative flex-1 h-full min-w-0 bg-n-surface-1"
    @dragover.prevent="onDragOver"
    @drop.prevent="onDrop"
  >
    <VueFlow
      v-model:nodes="nodes"
      v-model:edges="edges"
      :node-types="nodeTypes"
      :min-zoom="MIN_ZOOM"
      :max-zoom="MAX_ZOOM"
      snap-to-grid
      :snap-grid="[GRID, GRID]"
      :delete-key-code="['Delete', 'Backspace']"
      :is-valid-connection="isValidConnection"
      fit-view-on-init
      class="size-full"
    >
      <Background :gap="GRID" pattern-color="#94a3b8" class="opacity-40" />
      <Controls position="bottom-left" />
      <MiniMap pannable zoomable class="!bg-n-solid-2" />
    </VueFlow>
  </div>
</template>
