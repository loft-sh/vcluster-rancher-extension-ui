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
    <div class="modal-content">
      <h4 class="modal-title">Create vCluster</h4>

      <div class="form-container">
        <div class="form-group">
          <div class="form-field">
            <label class="form-label">Select a Cluster:</label>
            <Select
              :options="clusterOptions"
              :value="selectedClusterId"
              :disabled="loading"
              :searchable="true"
              placeholder="Select a cluster"
              @update:value="onClusterSelected"
            >
              <template #option="option">
                <div class="option-content">
                  <span>{{ option.label }}</span>
                  <span v-if="option.disabled" class="text-muted"
                    >(Not ready)</span
                  >
                </div>
              </template>
            </Select>
          </div>
        </div>

        <div class="form-group">
          <div class="form-field">
            <label class="form-label">vCluster Version:</label>
            <Select
              :options="versionOptions"
              :value="selectedVersion"
              :disabled="loadingRepos"
              :searchable="true"
              placeholder="Select a version"
              @update:value="onVersionSelected"
            >
              <template #option="option">
                <div class="option-content">
                  <span>{{ option.label }}</span>
                </div>
              </template>
            </Select>
            <div v-if="loadingRepos" class="loading-message">
              Loading versions...
            </div>
          </div>
        </div>
      </div>

      <div class="modal-actions">
        <button class="btn role-secondary" @click="closeModal(false)">
          Cancel
        </button>
        <AsyncButton
          :disabled="!selectedClusterId || !selectedVersion"
          mode="create"
          class="btn-primary"
          @click="handleCreate"
        />
      </div>
    </div>
  </AppModal>
</template>

<style lang="css" scoped>
.modal-content {
  padding: 10px;
}

.modal-title {
  font-weight: bold;
  margin-bottom: 0;
}

.form-container {
  margin-top: 20px;
}

.form-group {
  margin-bottom: 10px;
}

.form-field {
  width: 100%;
}

.form-label {
  display: block;
  margin-bottom: 10px;
}

.loading-message {
  margin-top: 5px;
  color: var(--muted);
  font-style: italic;
}

.text-muted {
  color: var(--muted);
  font-style: italic;
  margin-left: 5px;
}

.option-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}

.btn-primary {
  margin-left: 10px;
}
</style>
