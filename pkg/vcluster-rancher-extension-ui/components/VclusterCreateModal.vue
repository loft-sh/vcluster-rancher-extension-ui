<script lang="ts">
import { defineComponent, PropType } from 'vue';
import Select from '@shell/components/form/Select.vue';
import AsyncButton from '@shell/components/AsyncButton.vue';
import AppModal from '@shell/components/AppModal.vue';
import { CATALOG, MANAGEMENT } from '@shell/config/types';
import { Store } from 'vuex';
import { LOFT_CHART_URL, PRODUCT_NAME } from '../constants';
import { areUrlsEquivalent, getCookie } from '../utils';


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
      installError: '',
      loadingRepos: false,
      repoVersions: [] as Array<{ version: string;[key: string]: any }>,
      selectedVersion: '',
      pollingInterval: null as number | null,
      currentPollingAttempt: 0,
      maxPollingAttempts: 10
    };
  },

  computed: {
    computedVersionOptions(): { label: string; value: string }[] {

      if (!Array.isArray(this.repoVersions) || this.repoVersions.length === 0) {
        return [];
      }

      const options = this.repoVersions
        .filter((versObj: any) => {
          if (!versObj || typeof versObj !== 'object' || !('version' in versObj)) {
            return false;
          }
          return true;
        })
        .map((versObj: any, index: number) => {
          const isLatest = index === 0;
          return {
            label: versObj.version + (isLatest ? ' (Default)' : ''),
            value: versObj.version
          };
        });

      return options;
    }
  },

  watch: {
    computedVersionOptions: {
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
      this.repoVersions = [];
      this.selectedVersion = '';

      if (value) {
        this.checkingLoftInstallation = true;
        this.isLoftInstalled = await this.isLoftChartInstalledOnCluster(value);
        this.checkingLoftInstallation = false;

        if (this.isLoftInstalled) {
          await this.loadRepoVersions(value);
        }
      } else {
        this.isLoftInstalled = false;
      }
    },

    async checkAndLoadRepoVersions(clusterId: string): Promise<boolean> {
      try {
        const allRepos = await this.$store.dispatch('management/findAll', {
          type: CATALOG.CLUSTER_REPO,
          opt: {
            url: `/k8s/clusters/${clusterId}/v1/catalog.cattle.io.clusterrepos`
          }
        });

        const loftRepo = allRepos.find((repo: any) => areUrlsEquivalent(repo.spec.url, LOFT_CHART_URL));

        if (loftRepo) {
          const indexResponse = await loftRepo.followLink('index');
          const vcluster = indexResponse.entries.vcluster;

          if (vcluster && vcluster.length > 0) {
            this.repoVersions = vcluster.filter((versObject: { version: string }) => {
              if (!versObject || !versObject.version) {
                return false;
              }

              const version = versObject.version;
              const versionParts = version.split('.');
              if (parseInt(versionParts[1]) < 19) {
                return false;
              }

              const isValid = !version.includes('rc') && !version.includes('beta') && !version.includes('alpha');
              return isValid;
            });

            if (this.repoVersions.length > 0 && this.repoVersions[0]?.version) {
              this.selectedVersion = this.repoVersions[0].version;
              this.$emit('update:selectedVersion', this.selectedVersion);
              return true;
            }
          }
        }
        return false;
      } catch (error) {
        console.error('Error checking repo versions:', error);
        return false;
      }
    },

    async loadRepoVersions(clusterId: string): Promise<void> {
      this.loadingRepos = true;

      try {
        const success = await this.checkAndLoadRepoVersions(clusterId);
        if (!success) {
          this.installError = 'No valid versions found';
        }
      } finally {
        this.loadingRepos = false;
      }
    },

    onVersionSelected(value: string): void {
      this.selectedVersion = value;
      this.$emit('update:selectedVersion', value);
    },

    closeModal(result: boolean): void {
      this.selectedVersion = '';
      this.isLoftInstalled = false;
      this.checkingLoftInstallation = false;
      this.installingLoftChart = false;
      this.installError = '';
      this.repoVersions = [];

      this.$emit('close', result);

    },

    handleCreate(callback: (ok: boolean) => void): void {
      this.$router.push({
        path: `/${PRODUCT_NAME}/c/${this.selectedClusterId}/create`,
        query: { version: this.selectedVersion }
      });
      // revert all values
      this.selectedVersion = '';
      this.isLoftInstalled = false;
      this.checkingLoftInstallation = false;
      this.installingLoftChart = false;
      this.installError = '';
      this.repoVersions = [];

      this.closeModal(true);
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
        const isLoftChartInstalled = data.data.some((repo) => areUrlsEquivalent(repo.spec.url, LOFT_CHART_URL));

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

        // Start polling for versions after successful installation
        this.startPollingForVersions(clusterId);

        return true;
      } catch (error) {
        console.error(`Error installing Loft chart on cluster ${clusterId}:`, error);
        this.installError = error instanceof Error ? error.message : 'Failed to install Loft chart';
        return false;
      } finally {
        this.installingLoftChart = false;
      }
    },

    startPollingForVersions(clusterId: string): void {
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval);
      }

      this.loadingRepos = true;
      this.currentPollingAttempt = 0;

      this.pollingInterval = window.setInterval(async () => {
        this.currentPollingAttempt++;

        if (this.currentPollingAttempt >= this.maxPollingAttempts) {
          clearInterval(this.pollingInterval!);
          this.pollingInterval = null;
          this.loadingRepos = false;
          this.installError = 'Timeout waiting for chart versions to become available';
          return;
        }

        const success = await this.checkAndLoadRepoVersions(clusterId);
        if (success) {
          clearInterval(this.pollingInterval!);
          this.pollingInterval = null;
          this.loadingRepos = false;
        }
      }, 5000); // Poll every 5 seconds
    },

    navigateToClusterRepos(clusterId: string): void {
      this.$router.push(`/c/${clusterId}/apps/catalog.cattle.io.clusterrepo`);
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
                    >(No projects associated with this cluster)</span
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
              To create a virtual cluster, the vCluster Helm chart repository
              must be added to this cluster first.
            </p>

            <div v-if="installError" class="error-message">
              {{ installError }}
            </div>

            <div class="action-buttons">
              <AsyncButton
                :disabled="installingLoftChart"
                :loading="installingLoftChart"
                :actionLabel="'Add vCluster Helm Chart Repository'"
                :waitingLabel="'Adding vCluster chart repository...'"
                mode="edit"
                class="btn btn-sm role-primary"
                @click="() => installLoftChart(selectedClusterId)"
              />

              <button
                class="btn btn-sm role-secondary"
                @click="navigateToClusterRepos(selectedClusterId)"
              >
                Add Helm Chart Repository Manually
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
            <div v-if="loadingRepos" class="loading-message">
              <span class="spinner"></span>
              <span>Loading available versions...</span>
            </div>
            <div v-if="installError" class="error-message">
              {{ installError }}
            </div>
            <Select
              v-if="!loadingRepos"
              :options="computedVersionOptions"
              :value="selectedVersion"
              :disabled="loadingRepos || computedVersionOptions.length === 0"
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
  display: flex;
  align-items: center;
  gap: 8px;
  margin-top: 5px;
  color: var(--muted);
  font-style: italic;
}

.spinner {
  display: inline-block;
  width: 16px;
  height: 16px;
  border: 2px solid var(--muted);
  border-radius: 50%;
  border-top-color: transparent;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
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
