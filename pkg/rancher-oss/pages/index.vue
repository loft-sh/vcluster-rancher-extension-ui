<script lang="ts">
import { defineComponent, PropType } from 'vue';
import { Store } from 'vuex';
import { CATALOG, MANAGEMENT } from '@shell/config/types';
import LabelValue from '@shell/components/LabelValue.vue';
import InfoBox from '@shell/components/InfoBox.vue';
import ClusterIconMenu from '@shell/components/ClusterIconMenu.vue';
import Loading from '@shell/components/Loading.vue';
import SimpleBox from '@shell/components/SimpleBox.vue';
import Select from '@shell/components/form/Select.vue';
import SortableTable from '@shell/components/SortableTable/index.vue';
import AsyncButton from '@shell/components/AsyncButton.vue';
import VClusterCreateModal from '../components/VclusterCreateModal.vue';
import BadgeState from '@shell/rancher-components/BadgeState/BadgeState.vue';
import 'vue-router';
declare module 'vue/types/vue' {
  interface Vue {
    $store: Store<any>;
    $router: any;
  }
}

interface ClusterResource {
  id: string;
  nameDisplay: string;
  isReady?: boolean;
  state?: string;
  mgmt?: boolean;
  metadata: {
    name: string;
    namespace?: string;
  };
  spec?: any;
  status?: any;
  goToCluster?: () => Promise<void>;
}

interface AppResource {
  id?: string;
  status?: any;
  spec?: any;
  metadata?: any;
  clusterId?: string;
  clusterName?: string;
  error?: string;
}

export default defineComponent({
  name: 'vClusterList',

  components: {
    LabelValue: LabelValue as any,
    InfoBox: InfoBox as any,
    ClusterIconMenu: ClusterIconMenu as any,
    Loading: Loading as any,
    SimpleBox: SimpleBox as any,
    Select: Select as any,
    SortableTable: SortableTable as any,
    AsyncButton: AsyncButton as any,
    VClusterCreateModal: VClusterCreateModal as any,
    BadgeState: BadgeState as any
  },

  props: {
    $store: {
      type: Object as PropType<Store<any>>,
      required: true
    }
  },

  data() {
    return {
      originalStyles: new Map<Element, string>(),
      clusters: [] as ClusterResource[],
      failedInstallations: [] as AppResource[],
      selectedClusterId: '',
      loading: false,
      showCreateDialog: false,
      loadingRepos: false,
      repoVersions: [] as Array<{ version: string;[key: string]: any }>,
      selectedVersion: '',
      tableHeaders: [
        {
          name: 'status',
          label: this.t ? this.t('tableHeaders.state') : 'Status',
          value: 'state',
          sort: ['state', 'nameDisplay'],
          width: 100
        },
        {
          name: 'name',
          label: this.t ? this.t('tableHeaders.name') : 'Name',
          value: 'nameDisplay',
          sort: ['nameDisplay'],
          canBeVariable: true
        },
        {
          name: 'namespace',
          label: this.t ? this.t('tableHeaders.namespace') : 'Namespace',
          value: 'metadata.namespace',
          sort: ['metadata.namespace']
        },
        {
          name: 'id',
          label: this.t ? this.t('tableHeaders.id') : 'ID',
          value: 'id',
          sort: ['id'],
          width: 280
        }
      ],
      failedInstallationsTableHeaders: [
        {
          name: 'vCluster',
          label: 'vCluster',
          value: 'metadata.name'
        },
        {
          name: 'namespace',
          label: 'Namespace',
          value: 'metadata.namespace'
        },
        {
          name: 'status',
          label: 'Status',
          value: 'error'
        },
        {
          name: 'actions',
          label: 'Actions',
          value: 'actions'
        }
      ]
    };
  },

  computed: {
    selectedCluster(): ClusterResource | undefined {
      return this.clusters.find(c => c.id === this.selectedClusterId);
    },

    isNavigateDisabled(): boolean {
      return !this.selectedClusterId ||
        !this.selectedCluster ||
        this.loading ||
        (this.selectedCluster && !this.selectedCluster.isReady);
    },

    clusterOptions(): { label: string; value: string; disabled?: boolean }[] {
      return [
        {
          label: '-- Select a Cluster --',
          value: '',
        },
        ...this.clusters.map(cluster => ({
          label: `${cluster.nameDisplay} ${!cluster.isReady ? `(${this.getClusterStatusLabel(cluster)})` : ''}`,
          value: cluster.id,
          disabled: !cluster.isReady
        }))
      ];
    },

    versionOptions(): { label: string; value: string }[] {
      const options = [
        {
          label: '-- Select a Version --',
          value: '',
        }
      ];

      if (Array.isArray(this.repoVersions) && this.repoVersions.length > 0) {
        this.repoVersions.forEach((versObj: any, index: number) => {
          if (versObj && typeof versObj === 'object' && 'version' in versObj) {
            const isLatest = index === 0;
            options.push({
              label: versObj.version + (isLatest ? ' (Default)' : ''),
              value: versObj.version
            });
          }
        });
      }

      if (options.length > 1) {
        options.shift();
      }

      return options;
    }
  },

  created(): void {
    this.loadClusters();
    this.loadRepoVersions();
  },

  mounted() {
    document.body.classList.add('vcluster-page-active');

    const mainLayout = document.querySelector('.main-layout');
    if (mainLayout instanceof HTMLElement) {
      this.originalStyles.set(mainLayout, mainLayout.style.cssText);
      mainLayout.style.gridArea = 'auto';
      mainLayout.style.gridRow = '2 / 3';
      mainLayout.style.gridColumn = '1 / -1';
      mainLayout.style.width = '100%';
    }

    const nav = document.querySelector('.side-nav');
    if (nav instanceof HTMLElement) {
      this.originalStyles.set(nav, nav.style.display);
      nav.style.display = 'none';
    }

    this.loadFailedInstallations();
  },

  methods: {
    async loadFailedInstallations() {
      try {
        this.failedInstallations = await this.fetchFailedVClusterApps();
      } catch (error) {
        console.error('Failed to load installation errors:', error);
        this.failedInstallations = [];
      }
    },

    async fetchFailedVClusterApps() {
      const failedApps = [];

      try {
        const mgmtClusters = this.$store.getters['management/all'](MANAGEMENT.CLUSTER);
        const readyClusters = mgmtClusters.filter((cluster: ClusterResource) => cluster.isReady);

        for (const cluster of readyClusters) {
          try {
            if (!cluster.id) {
          console.log('Skipping cluster with no ID:', cluster);
          continue;
        }
            const apps = await this.$store.dispatch('management/findAll', {
              type: CATALOG.APP,
              opt: {
                url: `/k8s/clusters/${cluster.id}/v1/catalog.cattle.io.apps`,
                force: true
              }
            });

            console.log('apps', apps);

            const clusterFailedApps = apps.filter((app: AppResource) => {
              const isLoftApp = app.spec?.chart?.metadata?.annotations?.['catalog.cattle.io/ui-source-repo'] === 'loft';

              const isFailed = app.spec?.info?.status === 'failed';
              const isPending = app.spec?.info?.status === 'pending';


              return isLoftApp && (isFailed || isPending);
            });

            console.log('clusterFailedApps', clusterFailedApps);
            console.log('cluster', cluster);

            clusterFailedApps.forEach((app: AppResource) => {
              app.clusterId = cluster.id;
              app.clusterName = cluster.spec?.displayName || cluster.metadata?.name;
              app.error = this.getAppErrorMessage(app);

              // Ensure app has a unique id for the key-field
              if (!app.id) {
                app.id = `${cluster.id}-${app.metadata?.namespace}-${app.metadata?.name}`;
              }
            });

            failedApps.push(...clusterFailedApps);
          } catch (error) {
            console.error(`Error fetching apps for cluster ${cluster.id}:`, error);
          }
        }

        console.log('failedApps', failedApps);

        return failedApps;
      } catch (error) {
        console.error('Error fetching failed vCluster apps:', error);
        return [];
      }
    },

    getAppErrorMessage(app: AppResource) {
      // Fix the logic in this method
      if (app.spec?.info?.status === 'pending') {
        return 'Installation pending';
      } else if (app.spec?.info?.status === 'failed') {
        return 'Installation failed';
      } else {
        return 'Installation failed';
      }
    },

    navigateToApp(app: AppResource) {
      this.$router.push({
        name: 'c-cluster-apps-charts-app',
        params: {
          cluster: app.clusterId,
          appNamespace: app.metadata.namespace,
          appName: app.metadata.name
        }
      });
    },

    getStatusColor(cluster: ClusterResource): string {

      if (!cluster) {
        return 'bg-warning';
      }

      if (cluster.isReady) {
        return 'bg-success';
      } else if (cluster.state === 'Provisioning' || cluster.state === 'Updating') {
        return 'bg-info';
      } else if (cluster.state === 'Failed' || cluster.state === 'Error') {
        return 'bg-error';
      } else if (cluster.state === "unavailable") {
        return 'bg-neutral';
      } else {
        return 'bg-warning';
      }
    },

    t(key: string): string {
      const translations: { [key: string]: string } = {
        'tableHeaders.name': 'Name',
        'tableHeaders.state': 'Status',
        'tableHeaders.namespace': 'Namespace',
        'tableHeaders.id': 'ID'
      };

      return translations[key] || key;
    },

    async loadRepoVersions(): Promise<void> {
      this.loadingRepos = true;

      try {
        const response = await fetch('/v1/catalog.cattle.io.clusterrepos/loft?link=index', {
          headers: {
            'Accept': 'application/json'
          },
          credentials: 'same-origin'
        });

        if (response.ok) {
          const data = await response.json();

          const vcluster = data.entries.vcluster

          this.repoVersions = vcluster.filter((versObject: {
            version: string;
          }) => {
            const version = versObject.version;
            const versionParts = version.split('.');
            if (parseInt(versionParts[1]) < 19) {
              return false;
            }

            return !version.includes('rc') && !version.includes('beta') && !version.includes('alpha');
          });

          if (this.repoVersions.length > 0 && this.repoVersions[0]?.version) {
            this.selectedVersion = this.repoVersions[0].version;
          }
        } else {
          console.error('Failed to fetch repository data:', response.statusText);
        }
      } catch (error) {
        console.error('Failed to load repository versions:', error);
      } finally {
        this.loadingRepos = false;
      }
    },

    loadClusters(): void {
      const mgmtClusters: ClusterResource[] = this.$store.getters['management/all'](MANAGEMENT.CLUSTER);
      this.clusters = [...mgmtClusters];

      this.clusters.sort((a, b) => {
        return (a.nameDisplay || '').localeCompare(b.nameDisplay || '');
      });
    },

    onClusterSelected(value: string): void {
      this.selectedClusterId = value;
    },

    onVersionSelected(value: string): void {
      this.selectedVersion = value;
    },

    async navigateToCluster(): Promise<void> {
      if (!this.selectedCluster || this.loading) {
        return;
      }

      this.loading = true;

      try {
        if (typeof this.selectedCluster.goToCluster === 'function') {
          await this.selectedCluster.goToCluster();
        } else {
          this.$router.push({
            path: `/c/${this.selectedCluster.id}/apps/charts`
          });
        }
      } catch (error) {
        console.error('Failed to navigate to cluster:', error);
      } finally {
        this.loading = false;
      }
    },

    getClusterStatusLabel(cluster: ClusterResource): string {
      if (!cluster) {
        return '';
      }

      if (cluster.isReady) {
        return 'Ready';
      } else if (cluster.state) {
        return cluster.state;
      } else {
        return 'Unknown';
      }
    },

    openCreateDialog() {
      this.showCreateDialog = true;

      if (this.selectedVersion === '' && this.repoVersions.length > 0 && this.repoVersions[0]?.version) {
        this.selectedVersion = this.repoVersions[0].version;
      }
    },

    closeCreateDialog(result: boolean) {
      this.showCreateDialog = false;
      this.selectedVersion = '';
    },

    handleCreateDialogOkay(callback: (ok: boolean) => void) {
      const urlRoute = `/${this.$route.meta.product}/c/${this.selectedClusterId}/create?version=${this.selectedVersion}`;

      this.$router.push({
        path: urlRoute,
        query: {
          version: this.selectedVersion
        }
      });
    }
  },

  beforeUnmount() {
    document.body.classList.remove('vcluster-page-active');

    const mainLayout = document.querySelector('.main-layout');
    if (mainLayout instanceof HTMLElement && this.originalStyles.has(mainLayout)) {
      mainLayout.style.cssText = this.originalStyles.get(mainLayout) || '';
    }

    const nav = document.querySelector('.side-nav');
    if (nav instanceof HTMLElement && this.originalStyles.has(nav)) {
      nav.style.display = this.originalStyles.get(nav) || '';
    }
  },
});
</script>

<template>
  <div class="vcluster-oss-plugin">
    <div class="clusters-table-container">
      <div class="row panel">
        <div class="col span-12">
          <SortableTable
            :headers="tableHeaders"
            :rows="clusters"
            key-field="id"
            :search="true"
            class="cluster-table"
          >
            <template #header-left>
              <div class="row table-heading">
                <h2 class="mb-0">vClusters List</h2>
                <BadgeState
                  v-if="clusters.length"
                  :label="clusters.length.toString()"
                  color="role-tertiary ml-20 mr-20"
                />
              </div>
            </template>
            <template #header-middle>
              <div class="table-heading">
                <button
                  class="btn btn-sm role-primary"
                  @click="openCreateDialog"
                  data-testid="vcluster-create-button"
                >
                  Create vCluster
                </button>
              </div>
            </template>
            <template #col:name="{ row }">
              <td class="col-name">
                <div class="list-cluster-name">
                  <p class="cluster-name">
                    <router-link
                      v-if="row.isReady"
                      :to="{ path: `/c/${row.id}/apps/charts` }"
                      role="link"
                      :aria-label="row.nameDisplay"
                    >
                      {{ row.nameDisplay }}
                    </router-link>
                    <span v-else>{{ row.nameDisplay }}</span>
                  </p>
                  <p v-if="row.description" class="cluster-description">
                    {{ row.description }}
                  </p>
                </div>
              </td>
            </template>
            <template #col:status="{ row }">
              <td>
                <BadgeState
                  :color="getStatusColor(row)"
                  :label="getClusterStatusLabel(row)"
                />
              </td>
            </template>
          </SortableTable>
        </div>
      </div>
      <div class="row panel">
        <div
          v-if="failedInstallations.length > 0"
          class="failed-installations mt-20"
        >
          <h2>Failed vCluster Installations</h2>
          <table class="simple-table">
            <thead>
              <tr>
                <th>vCluster Name</th>
                <th>Namespace</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="app in failedInstallations" :key="app.id">
                <td>{{ app.metadata?.name || 'Unknown' }}</td>
                <td>{{ app.metadata?.namespace || 'Unknown' }}</td>
                <td>
                  <span class="badge-state bg-error">
                    {{ app.error || 'Unknown error' }}
                  </span>
                </td>
                <td>
                  <button
                    class="btn btn-sm role-primary"
                    @click="navigateToApp(app)"
                  >
                    View Details
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <VClusterCreateModal
      :show="showCreateDialog"
      :cluster-options="clusterOptions"
      :version-options="versionOptions"
      :selected-cluster-id="selectedClusterId"
      :selected-version="selectedVersion"
      :loading="loading"
      :loading-repos="loadingRepos"
      @update:selected-cluster-id="onClusterSelected"
      @update:selected-version="onVersionSelected"
      @close="closeCreateDialog"
      @create="handleCreateDialogOkay"
    />

    <Loading v-if="loading" />
  </div>
</template>

<style lang="css">
.option img[src*="vclusterLogo"] {
  filter: none !important;
}

.bg-neutral {
  background-color: var(--muted) !important;
}

.badge-state {
  text-transform: capitalize;
}

.vcluster-oss-plugin {
  width: 100%;
  padding: 20px;
}

.clusters-table-container {
  margin-top: 20px;
}

.clusters-title {
  margin-bottom: 10px;
}

.create-button-container {
  margin-top: 20px;
  margin-bottom: 10px;
}

.block {
  display: block;
}

.cluster-selector {
  padding: 20px;
}

.text-muted {
  color: var(--muted);
  font-style: italic;
  margin-left: 5px;
}

.cluster-info-row {
  display: flex;
  align-items: center;
}

.select-option {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.modal-dialog {
  padding: 10px;
}

.modal-dialog h4 {
  font-weight: bold;
}

.dialog-buttons {
  display: flex;
  justify-content: flex-end;
  margin-top: 10px;
}

.dialog-buttons>*:not(:last-child) {
  margin-right: 10px;
}

.table-heading {
  align-items: center;
  display: flex;
  height: 39px;

  &>button {
    margin-left: 10px;
  }

  h2 {
    font-size: 16px;
    margin-bottom: 0;
  }
}

.col-name {
  max-width: 280px;
}

.list-cluster-name {
  .cluster-name {
    display: flex;
    align-items: center;
  }

  .cluster-description {
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    color: var(--muted);
  }
}

.simple-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 10px;
}

.simple-table th {
  text-align: left;
  padding: 10px;
  border-bottom: 2px solid var(--border);
  font-weight: bold;
  background-color: var(--header-bg);
}

.simple-table td {
  padding: 10px;
  border-bottom: 1px solid var(--border);
}
</style>
