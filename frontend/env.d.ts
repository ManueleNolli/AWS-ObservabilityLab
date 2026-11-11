/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Optional link to Grafana shown in the header. */
  readonly VITE_GRAFANA_URL?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
