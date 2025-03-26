<script lang="ts">
import { ClusterResource } from '../pages/index.vue';
import { PRODUCT_NAME, LOFT_CHART_URL } from '../constants';
import VClusterCreateModal from './VclusterCreateModal.vue';
import { Store } from 'vuex';
import { CATALOG } from '@shell/config/types';

export default {
  name: 'VClusterClusterCreateItem',
  components: {
    VClusterCreateModal
  },

  props: {
    $store: {
      type: Store<any>,
      required: true
    }
  },

  computed: {
    isCreatePage(): boolean {
      return this.$route.path.includes('/create');
    }
  },

  data() {
    return {
      showModal: false,
      clusterOptions: [],
      versionOptions: [] as { label: string, value: string }[],
      selectedClusterId: '',
      selectedVersion: '',
      loading: false,
      loadingRepos: false
    };
  },

  methods: {
    openVClusterModal() {
      this.showModal = true;
      this.fetchClusters();
      this.fetchVersions();
    },

    closeModal() {
      this.showModal = false;
    },

    onClusterSelected(clusterId: string) {
      this.selectedClusterId = clusterId;
    },

    onVersionSelected(version: string) {
      this.selectedVersion = version;
    },

    async fetchClusters() {
      this.loading = true;
      try {
        const inStore = this.$store.getters['currentStore']();
        const clusters = this.$store.getters[`${inStore}/all`]('management.cattle.io.cluster');

        this.clusterOptions = clusters
          .filter((cluster: ClusterResource) => cluster.isReady)
          .map((cluster: ClusterResource) => ({
            label: cluster.nameDisplay,
            value: cluster.id,
            disabled: !cluster.isReady
          }));
      } catch (error) {
        console.error('Error fetching clusters:', error);
      } finally {
        this.loading = false;
      }
    },

    async fetchVersions() {
      this.loadingRepos = true;

      const allRepos = await this.$store.dispatch('management/findAll', {
        type: CATALOG.CLUSTER_REPO
      });

      const loftRepo = allRepos.find((repo: { spec: { url: string } }) => repo.spec.url === LOFT_CHART_URL);

      if (loftRepo) {
        const indexResponse = await loftRepo.followLink('index');
        const vcluster = indexResponse.entries.vcluster || [];

        const filteredVersions = vcluster.filter((entry: { version: string }) => {
          const version = entry.version;
          const versionParts = version.split('.');

          if (parseInt(versionParts[1]) < 19) {
            return false;
          }

          return !version.includes('rc') && !version.includes('beta') && !version.includes('alpha');
        });

        this.versionOptions = filteredVersions.map((entry: { version: string }, index: number) => ({
          label: `${entry.version} ${index === 0 ? '(default)' : ''}`,
          value: entry.version
        })).sort((a: { value: string }, b: { value: string }) => {
          return b.value.localeCompare(a.value, undefined, { numeric: true });
        })

        if (this.versionOptions.length > 0) {
          this.selectedVersion = this.versionOptions[0].value;
        }

        this.loadingRepos = false;
      }
    },

    handleCreate(callback: (success: boolean) => void) {
      if (!this.selectedClusterId || !this.selectedVersion) {
        callback(false);
        return;
      }
      const path = `/${PRODUCT_NAME}/c/${this.selectedClusterId}/create?version=${this.selectedVersion}`;


      this.$router.push({
        path,
        query: { version: this.selectedVersion }
      });

      this.closeModal();
      callback(true);
    }
  }
};
</script>

<template>
  <div v-if="isCreatePage" class="my-tab-component">
    <h4 class="title">Create a vCluster in a Rancher Cluster</h4>

    <div class="provider-cards">
      <div class="provider-card item color2" @click="openVClusterModal">
        <div class="side-label"></div>
        <div class="provider-logo">
          <img src="../assets/vclusterLogo.svg" alt="Amazon EKS" />
        </div>
        <div class="provider-name">vCluster</div>
      </div>
    </div>

    <VClusterCreateModal
      :$store="$store"
      v-if="showModal"
      :show="showModal"
      :cluster-options="clusterOptions"
      :version-options="versionOptions"
      :selected-cluster-id="selectedClusterId"
      :selected-version="selectedVersion"
      :loading="loading"
      :loading-repos="loadingRepos"
      @close="closeModal"
      @update:selectedClusterId="onClusterSelected"
      @update:selectedVersion="onVersionSelected"
      @create="handleCreate"
    />
  </div>
</template>

<style lang="scss" scoped>
body.theme-light {
  .provider-card {
    background-color: white;

    &:hover {
      background-color: white;
      box-shadow: 0 0 10px 0 rgba(0, 0, 0, 0.1);
    }
  }

  .provider-name {
    color: black;
  }
}

.my-tab-component {
  padding-top: 24px;

  .title {
    margin-bottom: 16px;
  }

  .side-label {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 4px;
    background-color: #f27405;
  }

  .provider-cards {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 20px;
    margin-bottom: 30px;

    @media (max-width: 1282px) {
      grid-template-columns: repeat(3, 1fr);
    }

    @media (max-width: 982px) {
      grid-template-columns: repeat(2, 1fr);
    }

    @media (max-width: 764px) {
      grid-template-columns: repeat(1, 1fr);
    }
  }

  .provider-card {
    align-self: flex-start;
    background-color: #1b1b1d;
    border: 1px solid var(--border);
    height: 135px;

    padding: 10px;
    position: relative;
    padding: 20px;
    display: flex;
    align-items: center;
    cursor: pointer;
    transition: all 0.2s;

    &:hover {
      background-color: #252529;
      border: 1px solid #f27405;
    }
  }

  .provider-logo {
    width: 60px;
    height: 60px;
    margin-right: 15px;
    display: flex;
    align-items: center;
    justify-content: center;

    img {
      max-width: 100%;
      max-height: 100%;
      width: 60px;
      height: 60px;
    }
  }

  .provider-name {
    font-size: 16px;
    font-weight: 500;
    color: white;
  }

  .card {
    background-color: black;
    border-radius: 4px;
    box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
    margin-bottom: 20px;

    .card-title {
      border-bottom: 1px solid #eee;
      padding: 15px 20px;

      h2 {
        margin: 0;
        font-size: 18px;
        font-weight: 600;
      }
    }

    .card-content {
      padding: 20px;
    }
  }

  .mb-20 {
    margin-bottom: 20px;
  }

  .row {
    display: flex;
    flex-wrap: wrap;
    margin: 0 -10px;
  }

  .col {
    padding: 0 10px;
  }

  .span-6 {
    width: 50%;
  }

  .span-12 {
    width: 100%;
  }
}
</style>
