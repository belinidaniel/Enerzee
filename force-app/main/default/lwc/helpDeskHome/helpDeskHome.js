import { api, LightningElement, track, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";
import createCase from "@salesforce/apex/ModuloHelpDeskCaseController.createCase";
import getDefaultEntities from "@salesforce/apex/ModuloHelpDeskCaseController.getDefaultEntities";
import addMessage from "@salesforce/apex/ModuloHelpDeskCaseController.addMessage";
import uploadFiles from "@salesforce/apex/ModuloHelpDeskCaseController.uploadFiles";
import uploadMessageFileExternal from "@salesforce/apex/ModuloHelpDeskCaseController.uploadMessageFileExternal";
import getCaseCategoryOptions from "@salesforce/apex/ModuloHelpDeskCaseController.getCaseCategoryOptions";
import cloudLogo from "@salesforce/resourceUrl/salesforceCloudV3";
import agentAstro from "@salesforce/resourceUrl/agentforceAgentAstro";
import { formatFileSize } from "c/helpDeskAttachmentUtils";

export default class HelpDeskHome extends LightningElement {
  _contactId = null;
  @api
  get contactId() {
    return this._contactId;
  }
  set contactId(value) {
    this._contactId = value;
    if (value) {
      this.loadDefaults(value);
    }
  }
  @track showModal = false;
  @track isSaving = false;
  @track createdCaseId;
  @track selectedCaseId;
  @track defaultsLoaded = false;
  @track contactName;
  @track accountName;
  accountId;
  defaultSuppliedEmail = "";
  defaultSuppliedPhone = "";

  @track subject = "";
  @track description = "";
  @track systemValue = "";
  @track typeValue = "";
  @track suppliedEmail = "";
  @track suppliedPhone = "";
  @track pendingFiles = [];
  @track readingFiles = false;
  @track categoryOptions = [];
  @track systemOptions = [];
  @track typeOptions = [];
  cloudLogo = cloudLogo;
  agentAstro = agentAstro;
  fileSequence = 0;
  fileToReplaceKey;

  allowedTypes = [
    { label: "Acesso", value: "Acesso" },
    { label: "Melhoria", value: "Melhoria" },
    { label: "Erro", value: "Erro" },
    { label: "Dúvida", value: "Dúvida" }
  ];

  fallbackSystems = ["Salesforce", "VO", "App", "Site"];

  get disableCreate() {
    return (
      this.isSaving ||
      this.readingFiles ||
      !this.subject ||
      !this.subject.trim() ||
      !this.systemValue ||
      !this.typeValue
    );
  }

  get disableType() {
    return !this.systemValue || !this.typeOptions.length;
  }

  get hasFiles() {
    return this.pendingFiles && this.pendingFiles.length > 0;
  }

  get acceptedFormats() {
    return ".pdf,.png,.jpg,.jpeg,.doc,.docx,.xls,.xlsx,.txt";
  }

  get canCreate() {
    return this.defaultsLoaded;
  }

  get createButtonLabel() {
    return this.isSaving ? "Criando caso..." : "Criar caso";
  }

  @wire(CurrentPageReference)
  wiredPageReference(pageReference) {
    this.selectedCaseId =
      pageReference?.state?.c__recordId ||
      pageReference?.state?.recordId ||
      null;
  }

  get showHome() {
    return !this.selectedCaseId;
  }

  get showCaseDetail() {
    return !!this.selectedCaseId;
  }

  connectedCallback() {
    this.loadDefaults(this.contactId || null);
    this.loadCaseCategoryOptions();
  }

  loadDefaults(contactIdParam) {
    getDefaultEntities({ contactId: contactIdParam })
      .then((result) => {
        this.accountId = result.accountId;
        this.accountName = result.accountName;
        if (result.contactId) {
          this._contactId = result.contactId;
        }
        this.contactName = result.contactName;
        this.defaultSuppliedEmail = result.contactEmail || "";
        this.defaultSuppliedPhone = result.contactPhone || "";
        this.suppliedEmail = result.contactEmail || "";
        this.suppliedPhone = result.contactPhone || "";
        this.defaultsLoaded = true;
      })
      .catch((error) => {
        this.defaultsLoaded = true;
        this.showToast("Aviso", this.normalizeError(error), "warning");
      });
  }

  loadCaseCategoryOptions() {
    getCaseCategoryOptions()
      .then((result) => {
        const options = result && result.length ? result : [];
        this.categoryOptions = options.map((item) => ({ ...item }));
        this.refreshSystemOptions();
      })
      .catch(() => {
        this.categoryOptions = [];
        this.refreshSystemOptions();
      });
  }

  openModal() {
    this.resetForm();
    this.showModal = true;
  }

  closeModal() {
    if (this.isSaving) {
      return;
    }
    this.showModal = false;
  }

  handleInputChange(event) {
    const { name, value } = event.target;
    if (name === "systemValue") {
      this.systemValue = value;
      this.typeValue = "";
      this.refreshTypeOptions();
      return;
    }
    this[name] = value;
  }

  handleCreate() {
    if (this.disableCreate || this.createdCaseId) {
      return;
    }
    this.isSaving = true;
    let createdId;
    createCase({
      subject: this.subject,
      description: this.description,
      richDescription: null,
      systemValue: this.systemValue,
      typeValue: this.typeValue,
      suppliedEmail: this.suppliedEmail,
      suppliedPhone: this.suppliedPhone,
      contactId: this.contactId,
      accountId: this.accountId
    })
      .then((result) => {
        createdId = result;
        return this.uploadEvidence(createdId);
      })
      .then(() => {
        this.createdCaseId = createdId;
        this.showToast("Caso criado", "Caso criado com sucesso.", "success");
        this.navigateToCase(createdId);
        this.resetForm();
        this.showModal = false;
        this.template.querySelector("c-help-desk-case-list")?.handleRefresh?.();
      })
      .catch((error) => {
        this.showToast(
          "Erro ao criar caso",
          this.normalizeError(error),
          "error"
        );
      })
      .finally(() => {
        this.isSaving = false;
      });
  }

  uploadEvidence(caseId) {
    if (!this.hasFiles) {
      return Promise.resolve(null);
    }
    if (!this.contactId) {
      const files = this.pendingFiles.map((file) => ({
        fileName: file.fileName || file.name,
        contentType: file.contentType,
        base64Data: file.base64Data,
        humanSize: file.humanSize,
        name: file.name
      }));
      return uploadFiles({ caseId, files, contactId: null });
    }

    // No site, mantém o armazenamento externo vinculado à mensagem pública.
    return addMessage({
      caseId,
      body: "Evidências:",
      authorName: this.contactName || null,
      authorType: "Cliente",
      isPublic: true,
      contactId: this.contactId
    }).then((messageId) =>
      Promise.all(
        this.pendingFiles.map((file) =>
          uploadMessageFileExternal({
            caseId,
            messageId,
            fileName: file.fileName || file.name,
            base64File: file.base64Data,
            contactId: this.contactId
          })
        )
      )
    );
  }

  navigateToCase(caseId) {
    if (!caseId) return;
    const url = this.contactId
      ? `/helpdesk/case/${caseId}?cId=${this.contactId}`
      : `/lightning/n/Help_Desk?c__recordId=${caseId}`;
    window.location.assign(url);
  }

  navigateToHome() {
    window.location.assign("/lightning/n/Help_Desk");
  }

  resetForm() {
    this.isSaving = false;
    this.createdCaseId = null;
    this.subject = "";
    this.description = "";
    this.systemValue = "";
    this.typeValue = "";
    this.suppliedEmail = this.defaultSuppliedEmail || "";
    this.suppliedPhone = this.defaultSuppliedPhone || "";
    this.pendingFiles = [];
    this.readingFiles = false;
    this.fileToReplaceKey = null;
    this.refreshTypeOptions();
  }

  handleFilesChange(event) {
    const files = Array.from(event.target.files || []);
    if (!files.length) {
      return;
    }
    this.readingFiles = true;

    const readers = files.map((file) =>
      this.buildFilePayload(file, this.generateFileKey())
    );

    Promise.allSettled(readers)
      .then((results) => {
        const success = results
          .filter((r) => r.status === "fulfilled")
          .map((r) => r.value);
        const failures = results.filter((r) => r.status === "rejected");
        if (success.length) {
          this.pendingFiles = [...this.pendingFiles, ...success];
        }
        if (failures.length) {
          const firstErr = failures[0].reason;
          this.showToast(
            "Erro ao ler arquivo",
            firstErr?.message || firstErr || "Erro inesperado",
            "error"
          );
        }
      })
      .finally(() => {
        this.readingFiles = false;
      });
  }

  removeFile(event) {
    const key = event.currentTarget.dataset.key;
    this.pendingFiles = this.pendingFiles.filter((f) => f.clientKey !== key);
  }

  handleEditFile(event) {
    this.fileToReplaceKey = event.currentTarget.dataset.key;
    const input = this.template.querySelector(".replace-file-input");
    if (input) {
      input.value = null;
      input.click();
    }
  }

  handleReplaceFileChange(event) {
    const selectedFile = event.target.files && event.target.files[0];
    if (!selectedFile || !this.fileToReplaceKey) {
      return;
    }
    const replaceKey = this.fileToReplaceKey;
    this.readingFiles = true;
    this.buildFilePayload(selectedFile, replaceKey)
      .then((updatedFile) => {
        this.pendingFiles = this.pendingFiles.map((file) => {
          return file.clientKey === replaceKey ? updatedFile : file;
        });
      })
      .catch((error) => {
        this.showToast(
          "Erro ao editar arquivo",
          error?.message || error || "Erro inesperado",
          "error"
        );
      })
      .finally(() => {
        this.readingFiles = false;
        this.fileToReplaceKey = null;
        event.target.value = null;
      });
  }

  buildFilePayload(file, clientKey) {
    return new Promise((resolve, reject) => {
      try {
        const reader = new FileReader();
        reader.onload = () => {
          try {
            const base64 = reader.result.split(",")[1];
            resolve({
              fileName: file.name,
              contentType: file.type,
              base64Data: base64,
              humanSize: formatFileSize(file.size),
              name: file.name,
              clientKey
            });
          } catch (e) {
            reject(e);
          }
        };
        reader.onerror = (e) => reject(e);
        reader.readAsDataURL(file);
      } catch (e) {
        reject(e);
      }
    });
  }

  generateFileKey() {
    this.fileSequence += 1;
    return `file_${Date.now()}_${this.fileSequence}`;
  }

  refreshSystemOptions() {
    const systems = this.uniqueValues(
      this.categoryOptions.map((item) => item.systemValue)
    );
    const availableSystems = systems.length ? systems : this.fallbackSystems;
    this.systemOptions = this.toPicklistOptions(availableSystems);
    if (!availableSystems.includes(this.systemValue)) {
      this.systemValue = "";
    }
    this.refreshTypeOptions();
  }

  refreshTypeOptions() {
    this.typeOptions = this.systemValue ? [...this.allowedTypes] : [];
    const typeValues = this.allowedTypes.map((item) => item.value);
    if (!typeValues.includes(this.typeValue)) {
      this.typeValue = "";
    }
  }

  uniqueValues(values) {
    const seen = new Set();
    const unique = [];
    values.forEach((value) => {
      const normalized = (value || "").trim();
      if (!normalized || seen.has(normalized)) {
        return;
      }
      seen.add(normalized);
      unique.push(normalized);
    });
    return unique;
  }

  toPicklistOptions(values) {
    return values.map((value) => ({ label: value, value }));
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  normalizeError(error) {
    if (Array.isArray(error?.body)) {
      return error.body.map((e) => e.message).join(", ");
    }
    return error?.body?.message || error?.message || "Erro inesperado";
  }
}
