import { LightningElement, api, wire, track } from "lwc";
import { getRecord } from "lightning/uiRecordApi";

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
  wiredRecord({ error, data }) {
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

  get isSuccess() {
    return this._sucesso === true;
  }

  get isFailure() {
    return this._sucesso === false && this._statusBody != null;
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

  get hasErrorDetails() {
    return this.isFailure && !!this._statusBody;
  }

  get statusBody() {
    return this._statusBody;
  }

  _reduceError(error) {
    if (error?.body?.message) return error.body.message;
    if (Array.isArray(error?.body))
      return error.body.map((e) => e.message).join(", ");
    return "Erro ao carregar dados de integração.";
  }
}
