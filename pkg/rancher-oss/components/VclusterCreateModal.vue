<script lang="ts">
import { defineComponent, PropType } from 'vue';
import Select from '@shell/components/form/Select.vue';
import AsyncButton from '@shell/components/AsyncButton.vue';
import AppModal from '@shell/components/AppModal.vue';


interface ClusterOption {
  label: string;
  value: string;
  disabled?: boolean;
}

interface VersionOption {
  label: string;
  value: string;
}

export default defineComponent({
  name: 'VClusterCreateModal',

  components: {
    Select: Select as any,
    AsyncButton,
    AppModal
  },

  props: {
    show: {
      type: Boolean,
      default: false
    },
    clusterOptions: {
      type: Array as PropType<ClusterOption[]>,
      default: () => []
    },
    versionOptions: {
      type: Array as PropType<VersionOption[]>,
      default: () => []
    },
    selectedClusterId: {
      type: String,
      default: ''
    },
    selectedVersion: {
      type: String,
      default: ''
    },
    loading: {
      type: Boolean,
      default: false
    },
    loadingRepos: {
      type: Boolean,
      default: false
    }
  },

  emits: ['close', 'update:selectedClusterId', 'update:selectedVersion', 'create'],

  methods: {
    onClusterSelected(value: string): void {
      this.$emit('update:selectedClusterId', value);
    },

    onVersionSelected(value: string): void {
      this.$emit('update:selectedVersion', value);
    },

    closeModal(result: boolean): void {
      this.$emit('close', result);
    },

    handleCreate(callback: (ok: boolean) => void): void {
      this.$emit('create', callback);
    }
  }
});
</script>

<template>
  <AppModal
    v-if="show"
    name="create-vcluster-dialog"
    height="auto"
    :scrollable="true"
    :trigger-focus-trap="true"
    @close="closeModal(false)"
  >
    <div class="modal-dialog">
      <h4>Create vCluster</h4>

      <div class="mt-20">
        <div class="row mb-10">
          <div class="col span-12">
            <label class="mb-10 block">Select a Cluster:</label>
            <Select
              :options="clusterOptions"
              :value="selectedClusterId"
              :disabled="loading"
              :searchable="true"
              placeholder="Select a cluster"
              @update:value="onClusterSelected"
            >
              <template #option="option">
                <div class="select-option">
                  <span>{{ option.label }}</span>
                  <span v-if="option.disabled" class="text-muted"
                    >(Not ready)</span
                  >
                </div>
              </template>
            </Select>
          </div>
        </div>

        <div class="row mb-10">
          <div class="col span-12">
            <label class="mb-10 block">vCluster Version:</label>
            <Select
              :options="versionOptions"
              :value="selectedVersion"
              :disabled="loadingRepos"
              :searchable="true"
              placeholder="Select a version"
              @update:value="onVersionSelected"
            >
              <template #option="option">
                <div class="select-option">
                  <span>{{ option.label }}</span>
                </div>
              </template>
            </Select>
            <div v-if="loadingRepos" class="mt-5 text-muted">
              Loading versions...
            </div>
          </div>
        </div>
      </div>

      <div class="dialog-buttons mt-20">
        <button class="btn role-secondary" @click="closeModal(false)">
          Cancel
        </button>
        <AsyncButton
          :disabled="!selectedClusterId || !selectedVersion"
          mode="create"
          class="ml-10"
          @click="handleCreate"
        />
      </div>
    </div>
  </AppModal>
</template>

<style lang="css" scoped>
.modal-dialog {
  padding: 10px;
}

.modal-dialog h4 {
  font-weight: bold;
}

.block {
  display: block;
}

.mb-5 {
  margin-bottom: 5px;
}

.mb-10 {
  margin-bottom: 10px;
}

.mt-5 {
  margin-top: 5px;
}

.mt-20 {
  margin-top: 20px;
}

.ml-10 {
  margin-left: 10px;
}

.text-muted {
  color: var(--muted);
  font-style: italic;
  margin-left: 5px;
}

.select-option {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.dialog-buttons {
  display: flex;
  justify-content: flex-end;
  margin-top: 10px;
}

.dialog-buttons > *:not(:last-child) {
  margin-right: 10px;
}
</style>
