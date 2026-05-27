import { api, LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getAllMessages from "@salesforce/apex/ModuloHelpDeskCaseController.getAllMessages";
import addAgentMessage from "@salesforce/apex/ModuloHelpDeskCaseController.addAgentMessage";
import uploadMessageFileExternal from "@salesforce/apex/ModuloHelpDeskCaseController.uploadMessageFileExternal";

export default class HelpDeskCaseFeed extends LightningElement {
  @api recordId;

  @track messages = [];
  @track pendingFiles = [];
  newBody = "";
  isPublic = true;
  isSaving = false;
  readingFiles = false;
  _refreshTimer;

  connectedCallback() {
    this._loadMessages();
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this._refreshTimer = setInterval(() => this._loadMessages(), 15000);
  }

  disconnectedCallback() {
    if (this._refreshTimer) {
      clearInterval(this._refreshTimer);
    }
  }

  _loadMessages() {
    if (!this.recordId) {
      return;
    }
    getAllMessages({ caseId: this.recordId })
      .then((data) => {
        this.messages = data.map((msg) => this.normalizeMessage(msg));
      })
      .catch((error) => {
        this.handleError("Erro ao carregar mensagens", error);
      });
  }

  normalizeMessage(msg) {
    const attachments = (msg.ContentDocumentLinks || []).map((link) => ({
      id: link.Id,
      title: link.ContentDocument ? link.ContentDocument.Title : "Arquivo",
      extension: link.ContentDocument ? link.ContentDocument.FileExtension : "",
      size: link.ContentDocument
        ? this.formatSize(link.ContentDocument.ContentSize)
        : "",
      versionId: link.ContentDocument
        ? link.ContentDocument.LatestPublishedVersionId
        : null,
      downloadUrl:
        link.ContentDocument && link.ContentDocument.LatestPublishedVersionId
          ? `/sfc/servlet.shepherd/version/download/${link.ContentDocument.LatestPublishedVersionId}`
          : null
    }));
    return {
      id: msg.Id,
      body: msg.Body__c,
      authorName:
        msg.AuthorName__c || (msg.CreatedBy ? msg.CreatedBy.Name : "Usuário"),
      authorType: msg.AuthorType__c || "Cliente",
      isAgent: msg.AuthorType__c === "Agente",
      isPrivate: msg.IsPublic__c === false,
      date: this.formatDate(msg.CreatedDate),
      initials: this.getInitials(
        msg.AuthorName__c || (msg.CreatedBy ? msg.CreatedBy.Name : "U")
      ),
      attachments,
      hasAttachments: attachments.length > 0
    };
  }

  get hasMessages() {
    return this.messages && this.messages.length > 0;
  }

  get isSendDisabled() {
    return (
      this.isSaving ||
      this.readingFiles ||
      !this.newBody ||
      !this.newBody.trim()
    );
  }

  get acceptedFormats() {
    return ".pdf,.png,.jpg,.jpeg,.doc,.docx,.xls,.xlsx,.txt";
  }

  handleBodyChange(event) {
    this.newBody = event.target.value;
  }

  handleVisibilityChange(event) {
    this.isPublic = event.target.checked;
  }

  handleFilesChange(event) {
    const files = Array.from(event.target.files || []);
    if (!files.length) {
      return;
    }
    this.readingFiles = true;
    Promise.all(files.map((file) => this.readFile(file)))
      .then((results) => {
        this.pendingFiles = [...this.pendingFiles, ...results];
      })
      .catch((error) => {
        this.showToast(
          "Erro ao ler arquivo",
          error?.message || "Erro inesperado",
          "error"
        );
      })
      .finally(() => {
        this.readingFiles = false;
      });
  }

  readFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const base64Body = reader.result.split(",")[1];
        const prefix = file.type
          ? `data:${file.type};base64,`
          : "data:application/octet-stream;base64,";
        resolve({
          fileName: file.name,
          name: file.name,
          base64: prefix + base64Body,
          humanSize: this.formatSize(file.size)
        });
      };
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(file);
    });
  }

  removePendingFile(event) {
    const name = event.currentTarget.dataset.name;
    this.pendingFiles = this.pendingFiles.filter((f) => f.name !== name);
  }

  handleSend() {
    if (!this.newBody || !this.newBody.trim() || !this.recordId) {
      return;
    }
    this.isSaving = true;
    const body = this.newBody;
    const isPublic = this.isPublic;
    const filesToUpload = [...this.pendingFiles];

    addAgentMessage({
      caseId: this.recordId,
      body,
      authorName: null,
      isPublic
    })
      .then((messageId) => {
        if (!messageId || filesToUpload.length === 0) {
          return null;
        }
        return Promise.all(
          filesToUpload.map((file) =>
            uploadMessageFileExternal({
              caseId: this.recordId,
              messageId,
              fileName: file.fileName || file.name,
              base64File: file.base64,
              contactId: null
            })
          )
        );
      })
      .then(() => {
        this._loadMessages();
        this.showToast("Mensagem enviada", "", "success");
      })
      .catch((error) => {
        this.handleError("Erro ao enviar mensagem", error);
      })
      .finally(() => {
        this.isSaving = false;
        this.newBody = "";
        this.pendingFiles = [];
        this.readingFiles = false;
      });
  }

  formatDate(dateValue) {
    return new Intl.DateTimeFormat("pt-BR", {
      year: "numeric",
      month: "short",
      day: "2-digit",
      hour: "2-digit",
      minute: "2-digit"
    }).format(new Date(dateValue));
  }

  formatSize(bytes) {
    if (!bytes && bytes !== 0) {
      return "";
    }
    const sizes = ["B", "KB", "MB", "GB"];
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return `${(bytes / Math.pow(1024, i)).toFixed(1)} ${sizes[i]}`;
  }

  getInitials(name) {
    if (!name) return "U";
    return name
      .split(" ")
      .map((n) => n.charAt(0))
      .join("")
      .substring(0, 2)
      .toUpperCase();
  }

  handleError(title, error) {
    this.showToast(title, this.normalizeError(error), "error");
  }

  normalizeError(error) {
    if (Array.isArray(error?.body)) {
      return error.body.map((e) => e.message).join(", ");
    }
    return error?.body?.message || error?.message || "Erro inesperado";
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }
}
