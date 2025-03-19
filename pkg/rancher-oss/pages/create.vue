<script lang="ts">
import 'vue-router';
import { defineComponent, PropType } from 'vue';
import Loading from '@shell/components/Loading.vue';
import LabeledInput from '@shell/rancher-components/Form/LabeledInput/LabeledInput.vue';
import NameNsDescription from '@shell/components/form/NameNsDescription.vue';
import YamlEditor from '@shell/components/YamlEditor.vue';
import AsyncButton, { AsyncButtonCallback } from '@shell/components/AsyncButton.vue';



import { mapGetters, Store } from 'vuex';
import jsyaml from 'js-yaml';

import { NAMESPACE } from '@shell/config/types';
import { PRODUCT_NAME } from '../constants';

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
    AsyncButton: AsyncButton as any
  },

  computed: {
    ...mapGetters(['namespaces', 'allowedNamespaces']),
    allNamespaces() {
      const namespaceObjs = this.namespaces();
      return namespaceObjs
    },
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
      yamlValue: `sync:
  toHost:
    ingresses:
      enabled: true
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

        const response = await fetch(`/v1/catalog.cattle.io.clusterrepos/loft?link=info&chartName=vcluster&version=${this.versionParam}`, {
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
      const allNamespaceObjects = this.$store.getters[`${inStore}/all`](NAMESPACE);
      const namespaceObject = allNamespaceObjects.find((namespace: any) => namespace.id === this.value.metadata.namespace)

      const projectId = namespaceObject.metadata.labels["field.cattle.io/projectId"]

      let values = {};
      try {
        const yamlValues = jsyaml.load(this.yamlValue);
        values = yamlValues
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
              "catalog.cattle.io/ui-source-repo": "loft"
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

      fetch('/v1/catalog.cattle.io.clusterrepos/loft?action=install', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'x-api-csrf': csrfToken
        },
        credentials: 'same-origin',
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
    <div class="header">
      <h1>vCluster Chart Information</h1>
    </div>

    <Loading v-if="loading" class="loading" />

    <div v-else class="chart-info">
      <NameNsDescription
        v-model:value="value"
        :description-hidden="true"
        mode="create"
      />

      <div class="yaml-section mt-20">
        <h3>Configuration YAML</h3>
        <YamlEditor
          class="yaml-editor"
          :value="yamlValue"
          @onInput="onYamlChange"
        />
      </div>
    </div>

    <div class="actions mt-20 flex flex-row gap-10">
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

.flex {
  display: flex;
}

.flex-row {
  flex-direction: row;
}

.gap-10 {
  gap: 10px;
}

.vcluster-create-page {
  padding: 20px;
}

.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
}

.error-container {
  background-color: var(--error-bg);
  border: 1px solid var(--error);
  border-radius: 4px;
  padding: 20px;
  margin: 20px 0;
}

.error-message {
  color: var(--error);
  font-weight: bold;
}

.chart-info {
  background-color: var(--box-bg);
  border-radius: 4px;
  padding: 20px;
}

.info-section {
  margin-bottom: 20px;
}

.info-section h3 {
  margin-bottom: 10px;
  font-weight: bold;
}

.yaml-section h3 {
  margin-bottom: 10px;
  font-weight: bold;
}

.yaml-editor {
  height: 300px;
  border: 1px solid var(--border);
  border-radius: 4px;
}

.mt-20 {
  margin-top: 20px;
}

.actions {
  display: flex;
  justify-content: flex-end;
}
</style>
