<script lang="ts">
import 'vue-router';
import { defineComponent, PropType } from 'vue';
import Loading from '@shell/components/Loading.vue';
import LabeledInput from '@shell/rancher-components/Form/LabeledInput/LabeledInput.vue';
import NameNsDescription from '@shell/components/form/NameNsDescription.vue';
import YamlEditor from '@shell/components/YamlEditor.vue';
import AsyncButton, { AsyncButtonCallback } from '@shell/components/AsyncButton.vue';
import LabeledSelect from '@shell/components/form/LabeledSelect.vue';



import { mapGetters, Store } from 'vuex';
import jsyaml from 'js-yaml';

import { CATALOG, NAMESPACE } from '@shell/config/types';
import { LOFT_CHART_URL, PRODUCT_NAME } from '../constants';

declare module 'vue/types/vue' {
  interface Vue {
    $store: Store<any>;
    $router: any;
  }
}


export default defineComponent({
  name: 'VClusterCreatePage',

  props: {
    $store: {
      type: Object as PropType<Store<any>>,
      required: true
    }
  },


  components: {
    Loading: Loading as any,
    LabeledInput: LabeledInput as any,
    NameNsDescription: NameNsDescription as any,
    YamlEditor: YamlEditor as any,
    AsyncButton: AsyncButton as any,
    LabeledSelect: LabeledSelect as any
  },

  computed: {
    ...mapGetters(['namespaces', 'allowedNamespaces']),
    allNamespaces() {
      const namespaceObjs = this.namespaces();
      return namespaceObjs
    },
    projectOpts() {
      const clusterId = this.$route.params.cluster;
      const projects = this.$store.getters['management/all']('management.cattle.io.project')

      return projects
        .filter((project: any) => project.spec.clusterName === clusterId)
        .map((project: any) => ({
          label: project.spec.displayName || project.metadata.name,
          value: project.metadata.name
        }));
    }
  },

  data() {
    return {
      originalStyles: new Map<Element, string>(),
      loading: true,
      chartInfo: null,
      error: null,
      versionParam: '',
      value: {
        metadata: {
          name: '',
          namespace: ''
        }
      },
      isNewNamespace: false,
      selectedProjectId: null,
      yamlValue: `
sync:
  toHost:
    ingresses:
      enabled: true
controlPlane:
  service:
    annotations:
      "loft.sh/uninstall-on-cluster-delete": "true"
`
    };
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
  },

  created() {
    this.versionParam = this.$route.query.version as string || '';
    this.fetchChartInfo();
  },

  methods: {
    async fetchChartInfo() {
      this.loading = true;
      this.error = null;

      try {
        if (!this.versionParam) {
          throw new Error('Version parameter is required');
        }
        const allRepos = await this.$store.dispatch('management/findAll', {
          type: CATALOG.CLUSTER_REPO
        });

        const loftRepo = allRepos.find((repo: { spec: { url: string } }) => repo.spec.url === LOFT_CHART_URL);
        const response = await fetch(`/v1/catalog.cattle.io.clusterrepos/${loftRepo.id}?link=info&chartName=vcluster&version=${this.versionParam}`, {
          headers: {
            'Accept': 'application/json'
          },
          credentials: 'same-origin'
        });

        if (!response.ok) {
          throw new Error(`Failed to fetch chart info: ${response.statusText}`);
        }

        this.chartInfo = await response.json();
      } catch (error) {
        console.error('Error fetching chart info:', error);

      } finally {
        this.loading = false;
      }
    },

    onNamespaceChange(isNew: boolean) {
      this.isNewNamespace = isNew;

      // Reset selected project when namespace changes
      if (!isNew) {
        this.selectedProjectId = null;
      }
    },

    onYamlChange(value: string) {
      this.yamlValue = value;
    },

    goBack() {
      const path = `/${PRODUCT_NAME}/c/_/dashboard`;
      this.$router.push({ path });
    },

    handleCreateVCluster(cb: AsyncButtonCallback) {
      const clusterId = this.$route.params.cluster
      const chartName = "vcluster"
      const version = this.$route.query.version
      const inStore = this.$store.getters['currentStore']();
      const loftRepo = this.$store.getters['management/all'](CATALOG.CLUSTER_REPO)?.find((repo: { spec: { url: string } }) => repo.spec.url === LOFT_CHART_URL);

      if (!loftRepo) {
        cb(false);
        this.$store.dispatch('growl/error', {
          title: 'Error',
          message: 'vCluster chart repository not found'
        });
        return;
      }

      let projectId;
      if (this.isNewNamespace) {
        projectId = this.selectedProjectId;
      } else {
        const allNamespaceObjects = this.$store.getters[`${inStore}/all`](NAMESPACE);
        const namespaceObject = allNamespaceObjects.find((namespace: any) => namespace.id === this.value.metadata.namespace);
        projectId = namespaceObject?.metadata?.labels["field.cattle.io/projectId"];
      }

      if (!projectId) {
        cb(false);
        this.$store.dispatch('growl/error', {
          title: 'Error',
          message: 'Project ID is required to create vCluster'
        });
        return;
      }

      let values = {
        global: {
          cattle: {
            clusterId: clusterId,
            clusterName: this.value.metadata.name,
            systemProjectId: projectId,
            url: window.location.origin,
          }
        }
      };
      try {
        const yamlValues = jsyaml.load(this.yamlValue);
        Object.assign(values, yamlValues);
      } catch (error) {
        console.error('Error parsing YAML:', error);
        cb(false);
        return;
      }

      const payload = {
        charts: [
          {
            chartName: chartName,
            version: version || "0.23.0",
            releaseName: this.value.metadata.name,
            annotations: {
              "catalog.cattle.io/ui-source-repo-type": "cluster",
              "catalog.cattle.io/ui-source-repo": loftRepo.id
            },
            values
          }
        ],
        noHooks: false,
        timeout: "600s",
        wait: true,
        namespace: this.value.metadata.namespace || "default",
        projectId: `${clusterId}/${projectId}`,
        disableOpenAPIValidation: false,
        skipCRDs: false
      };

      const getCookie = (name: string) => {
        const value = `; ${document.cookie}`;
        const parts = value.split(`; ${name}=`);
        if (parts.length === 2) {
          return parts.pop()?.split(';').shift() || '';
        }
        return '';
      };

      const csrfToken = getCookie('CSRF') || '';
      fetch(`/k8s/clusters/${clusterId}/v1/catalog.cattle.io.clusterrepos/${loftRepo.id}?action=install`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-api-csrf': csrfToken
        },
        credentials: 'include',
        body: JSON.stringify(payload)
      })
        .then(response => {
          if (!response.ok) {
            throw new Error(`Failed to create vCluster: ${response.statusText}`);
          }
          return response.json();
        })
        .then(data => {
          const path = `/${PRODUCT_NAME}/c/_/dashboard`;
          this.$router.push({ path });
          cb(true);
        })
        .catch(error => {
          console.error('Error creating vCluster:', error);
          cb(false);
        });
    }
  }
});
</script>

<template>
  <div class="vcluster-create-page">
    <div class="vcluster-header">
      <h1>vCluster Chart Information</h1>
    </div>

    <Loading v-if="loading" class="vcluster-loading" />

    <div v-else class="vcluster-chart-info">
      <NameNsDescription
        v-model:value="value"
        :description-hidden="true"
        mode="create"
        @isNamespaceNew="onNamespaceChange"
      />

      <div v-if="isNewNamespace" class="vcluster-project-selector">
        <LabeledSelect
          v-model:value="selectedProjectId"
          :options="projectOpts"
          label="Project"
          placeholder="Select a project for this namespace"
          :searchable="true"
          :required="true"
        />
        <p class="vcluster-help-text">
          Select the project to which this new namespace will belong
        </p>
      </div>

      <div class="vcluster-yaml-section">
        <h3 class="vcluster-section-title">Configuration YAML</h3>
        <YamlEditor
          class="vcluster-yaml-editor"
          :value="yamlValue"
          @onInput="onYamlChange"
        />
      </div>
    </div>

    <div class="vcluster-actions">
      <button class="btn role-secondary" @click="goBack">
        Back to Dashboard
      </button>
      <AsyncButton
        :disabled="!value.metadata.name || !value.metadata.namespace"
        :actionLabel="'Create vCluster'"
        :waitingLabel="'Creating vCluster...'"
        class="btn role-primary vcluster-create-btn"
        @click="handleCreateVCluster"
      >
        Create vCluster
      </AsyncButton>
    </div>
  </div>
</template>

<style lang="css" scoped>
.vcluster-create-page {
  padding: 20px;
}

.vcluster-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.vcluster-chart-info {
  background-color: var(--box-bg);
  border-radius: 4px;
  padding: 20px;
  margin-bottom: 20px;
}

.vcluster-project-selector {
  max-width: clamp(300px, 50%, 636px);
}


.vcluster-help-text {
  color: var(--text-muted);
  font-size: 12px;
  margin-top: 5px;
}

.vcluster-yaml-section {
  margin-top: 20px;
}

.vcluster-section-title {
  font-weight: bold;
  margin-bottom: 10px;
}

.vcluster-yaml-editor {
  height: 300px;
  border: 1px solid var(--border);
  border-radius: 4px;
}

.vcluster-actions {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
  margin-top: 20px;
}

.vcluster-loading {
  display: flex;
  justify-content: center;
  padding: 20px;
}

.vcluster-create-btn {
  min-width: 120px;
}
</style>
