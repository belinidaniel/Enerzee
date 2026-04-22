import { LightningElement, api, wire, track } from "lwc";
import { getRecord } from "lightning/uiRecordApi";
import retryIntegration from "@salesforce/apex/SapIntegrationRetryController.retryIntegration";

const FIELD_SUCESSO = "SucessoIntegracaoSAP__c";
const FIELD_STATUS_BODY = "StatusBodyIntegracaoSAP__c";

export default class SapIntegrationStatus extends LightningElement {
  @api recordId;

  @track _objectApiName;
  @track _fields = [];

  isLoading = true;
  hasError = false;
  errorMessage;

  _sucesso = null;
  _statusBody = null;
  _wiredResult;

  isRetrying = false;
  isModalOpen = false;
  modalResult = null;

  @api
  get objectApiName() {
    return this._objectApiName;
  }

  set objectApiName(value) {
    this._objectApiName = value;
    if (value) {
      this._fields = [
        `${value}.${FIELD_SUCESSO}`,
        `${value}.${FIELD_STATUS_BODY}`
      ];
    }
  }

  @wire(getRecord, { recordId: "$recordId", fields: "$_fields" })
  wiredRecord(result) {
    this._wiredResult = result;
    const { error, data } = result;
    if (data) {
      this._sucesso = data.fields[FIELD_SUCESSO]?.value ?? null;
      this._statusBody = data.fields[FIELD_STATUS_BODY]?.value ?? null;
      this.hasError = false;
      this.isLoading = false;
    } else if (error) {
      this.hasError = true;
      this.errorMessage = this._reduceError(error);
      this.isLoading = false;
    }
  }

  // ── Visibilidade ──────────────────────────────────────────────

  get hasIntegrationAttempt() {
    return this._sucesso === true || !!this._statusBody;
  }

  // ── Status ────────────────────────────────────────────────────

  get isSuccess() {
    return this._sucesso === true;
  }

  get isFailure() {
    return this._sucesso === false;
  }

  get isPending() {
    return this._sucesso === null || this._sucesso === undefined;
  }

  get statusLabel() {
    if (this.isSuccess) return "Integrado ao SAP";
    if (this.isFailure) return "Falha na integração";
    return "Não integrado";
  }

  get statusSubtitle() {
    if (this.isSuccess) return "Registro sincronizado com sucesso no SAP.";
    if (this.isFailure)
      return "Ocorreu um erro na última tentativa de integração.";
    return "Este registro ainda não foi enviado ao SAP.";
  }

  get bannerClass() {
    let state = "pending";
    if (this.isSuccess) state = "success";
    else if (this.isFailure) state = "error";
    return `sap-banner sap-banner_${state}`;
  }

  get statusIconName() {
    if (this.isSuccess) return "utility:check";
    if (this.isFailure) return "utility:error";
    return "utility:clock";
  }

  get badgeClass() {
    let mod = "inverse";
    if (this.isSuccess) mod = "success";
    else if (this.isFailure) mod = "error";
    return `slds-badge slds-badge_${mod} status-badge`;
  }

  get badgeText() {
    if (this.isSuccess) return "OK";
    if (this.isFailure) return "ERRO";
    return "PENDENTE";
  }

  // ── Error details ─────────────────────────────────────────────

  get hasErrorDetails() {
    return this.isFailure && !!this._statusBody;
  }

  get parsedError() {
    return this._parseStatusBody(this._statusBody);
  }

  // ── Modal ─────────────────────────────────────────────────────

  get modalIsSuccess() {
    return this.modalResult?.success === true;
  }

  get modalTitle() {
    if (!this.modalResult) return "";
    return this.modalResult.success
      ? "Integração bem-sucedida"
      : "Falha na integração";
  }

  get modalIconName() {
    if (!this.modalResult) return "utility:info";
    return this.modalResult.success ? "utility:success" : "utility:error";
  }

  get modalHeaderClass() {
    const base = "slds-modal__header";
    if (!this.modalResult) return base;
    return this.modalResult.success
      ? `${base} modal-header_success`
      : `${base} modal-header_error`;
  }

  get modalParsedError() {
    if (!this.modalResult || this.modalResult.success) return null;
    return this._parseStatusBody(this.modalResult.statusBody);
  }

  // ── Retry handler ─────────────────────────────────────────────

  async handleRetry() {
    this.isRetrying = true;
    try {
      const result = await retryIntegration({
        recordId: this.recordId,
        objectApiName: this._objectApiName
      });
      this.modalResult = result;
      this.isModalOpen = true;
      // await refreshApex(this._wiredResult);
    } catch (e) {
      this.modalResult = {
        success: false,
        statusBody: this._reduceError(e)
      };
      this.isModalOpen = true;
    } finally {
      this.isRetrying = false;
    }
  }

  closeModal() {
    this.isModalOpen = false;
    this.modalResult = null;
  }

  // ── Helpers ───────────────────────────────────────────────────

  // Formato esperado: "404 {"codigoHttp":404,"mensagem":"...","resultado":null} OK"
  _parseStatusBody(raw) {
    if (!raw) return { codigoHttp: null, mensagem: "", resultado: null };
    try {
      const jsonStart = raw.indexOf("{");
      const jsonEnd = raw.lastIndexOf("}");
      if (jsonStart !== -1 && jsonEnd !== -1) {
        const parsed = JSON.parse(raw.substring(jsonStart, jsonEnd + 1));
        return {
          codigoHttp: parsed.codigoHttp ?? null,
          mensagem: parsed.mensagem ?? raw,
          resultado: parsed.resultado != null ? String(parsed.resultado) : null
        };
      }
    } catch {
      // fallback para raw string
    }
    return { codigoHttp: null, mensagem: raw, resultado: null };
  }

  _reduceError(error) {
    if (typeof error === "string" && error.trim()) return error;
    if (error?.message) return error.message;
    if (error?.body?.message) return error.body.message;
    if (Array.isArray(error?.body))
      return error.body.map((e) => e.message).join(", ");
    if (typeof error?.body === "string" && error.body.trim()) return error.body;
    return "Erro ao carregar dados de integração.";
  }
}
