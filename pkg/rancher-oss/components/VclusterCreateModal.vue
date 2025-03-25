<script lang="ts">
import { defineComponent, PropType } from 'vue';
import Select from '@shell/components/form/Select.vue';
import AsyncButton from '@shell/components/AsyncButton.vue';
import AppModal from '@shell/components/AppModal.vue';
import { CATALOG, MANAGEMENT } from '@shell/config/types';
import { Store } from 'vuex';
import { LOFT_CHART_URL } from '../constants';
import { getCookie } from '../utils';


declare module 'vue/types/vue' {
  interface Vue {
    $store: Store<any>;
    $router: any;
  }
}

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
    $store: {
      type: Object as PropType<Store<any>>,
      required: true
    },
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

  data() {
    return {
      isLoftInstalled: false,
      checkingLoftInstallation: false,
      installingLoftChart: false,
      installError: ''
    };
  },

  watch: {
    versionOptions: {
      handler(newOptions) {
        // Auto-select the latest version when options become available
        if (this.isLoftInstalled && newOptions.length > 0 && !this.selectedVersion && !this.loadingRepos) {
          this.onVersionSelected(newOptions[0].value);
        }
      },
      immediate: true
    }
  },

  methods: {
    async onClusterSelected(value: string): Promise<void> {
      this.$emit('update:selectedClusterId', value);
      this.$emit('update:selectedVersion', '');
      this.installError = '';

      if (value) {
        this.checkingLoftInstallation = true;
        this.isLoftInstalled = await this.isLoftChartInstalledOnCluster(value);
        this.checkingLoftInstallation = false;

        // Auto-select the latest version if versionOptions are available
        if (this.isLoftInstalled && this.versionOptions.length > 0 && !this.loadingRepos) {
          // Assuming the first option is the latest version
          this.onVersionSelected(this.versionOptions[0].value);
        }
      } else {
        this.isLoftInstalled = false;
      }
    },

    onVersionSelected(value: string): void {
      this.$emit('update:selectedVersion', value);
    },

    closeModal(result: boolean): void {
      this.$emit('close', result);
    },

    handleCreate(callback: (ok: boolean) => void): void {
      this.$emit('create', callback);
    },


    async isLoftChartInstalledOnCluster(clusterId: string): Promise<boolean> {
      try {
        const response = await fetch(`/k8s/clusters/${clusterId}/v1/catalog.cattle.io.clusterrepos?exclude=metadata.managedFields`, {
          headers: {
            'Accept': 'application/json'
          },
          credentials: 'same-origin'
        });

        if (!response.ok) {
          throw new Error(`Failed to fetch cluster repos: ${response.statusText}`);
        }

        const data = await response.json() as {
          data: {
            spec: {
              url: string;
            }
          }[]
        };
        const isLoftChartInstalled = data.data.some((repo) => repo.spec.url === LOFT_CHART_URL);

        return isLoftChartInstalled;
      } catch (error) {
        console.error(`Error checking if Loft is installed on cluster ${clusterId}:`, error);
        return false;
      }
    },

    async installLoftChart(clusterId: string): Promise<boolean> {
      try {
        this.installingLoftChart = true;
        this.installError = '';

        const postData = {
          type: "catalog.cattle.io.clusterrepo",
          metadata: {
            name: "loft"
          },
          spec: {
            clientSecret: null,
            url: LOFT_CHART_URL
          }
        };

        const csrfToken = getCookie('CSRF') || '';

        const response = await fetch(`/k8s/clusters/${clusterId}/v1/catalog.cattle.io.clusterrepos`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'x-api-csrf': csrfToken
          },
          credentials: 'same-origin',
          body: JSON.stringify(postData)
        });

        if (!response.ok) {
          const errorData = await response.json();
          throw new Error(errorData.message || `Failed to install Loft chart: ${response.statusText}`);
        }
        this.isLoftInstalled = true;
        return true;
      } catch (error) {
        console.error(`Error installing Loft chart on cluster ${clusterId}:`, error);
        this.installError = error instanceof Error ? error.message : 'Failed to install Loft chart';
        return false;
      } finally {
        this.installingLoftChart = false;
      }
    },

    navigateToClusterRepos(clusterId: string): void {
      // Navigate to the cluster repos page
      this.$router.push(`/c/${clusterId}/apps/repositories`);
      this.closeModal(false);
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
      <h4 class="modal-title">Create Virtual Cluster</h4>

      <div class="form-container">
        <div class="form-group">
          <div class="form-field">
            <label class="form-label">Host Cluster</label>
            <Select
              :options="clusterOptions"
              :value="selectedClusterId"
              :disabled="loading"
              :searchable="true"
              placeholder="-- Select a cluster --"
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
            <div class="form-field-description text-muted">
              <p>The cluster where the virtual cluster will run.</p>
            </div>
          </div>
        </div>

        <div
          v-if="selectedClusterId && checkingLoftInstallation"
          class="form-group"
        >
          <div class="loading-message">
            Checking vCluster chart repository installation status...
          </div>
        </div>

        <div
          v-if="selectedClusterId && !checkingLoftInstallation && !isLoftInstalled"
          class="form-group"
        >
          <div class="message-box">
            <p>
              To create a virtual cluster, the vCluster chart repository must be
              installed on the host cluster.
            </p>

            <div v-if="installError" class="error-message">
              {{ installError }}
            </div>

            <div class="action-buttons">
              <AsyncButton
                :disabled="installingLoftChart"
                :loading="installingLoftChart"
                :actionLabel="'Install vCluster chart'"
                :waitingLabel="'Installing vCluster chart...'"
                mode="edit"
                class="btn btn-sm role-primary"
                @click="() => installLoftChart(selectedClusterId)"
              >
                Install Automatically
              </AsyncButton>

              <button
                class="btn btn-sm role-secondary"
                @click="navigateToClusterRepos(selectedClusterId)"
              >
                Install Manually
              </button>
            </div>
          </div>
        </div>

        <div
          v-if="selectedClusterId && !checkingLoftInstallation && isLoftInstalled"
          class="form-group"
        >
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
          :disabled="!selectedClusterId || checkingLoftInstallation || !isLoftInstalled || !selectedVersion"
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
  margin-bottom: 12px;
  margin-top: 12px;
}

.form-field {
  width: 100%;
  display: flex;
  flex-direction: column;

  .form-field-description {
    margin-top: 2px;
  }
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

.error-message {
  margin-top: 5px;
  color: var(--error);
  font-weight: bold;
}

.message-box {
  background-color: var(--info-bg);
  border: 1px solid var(--info-border);
  border-radius: 4px;
  padding: 15px;
  margin-bottom: 15px;
}

.action-buttons {
  display: flex;
  gap: 10px;
  margin-top: 10px;
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
