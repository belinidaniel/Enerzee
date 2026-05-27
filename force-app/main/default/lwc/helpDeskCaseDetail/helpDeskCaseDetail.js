import { api, LightningElement, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CurrentPageReference } from "lightning/navigation";
import getCaseDetail from "@salesforce/apex/ModuloHelpDeskCaseController.getCaseDetail";
import getMessages from "@salesforce/apex/ModuloHelpDeskCaseController.getMessages";
import addMessage from "@salesforce/apex/ModuloHelpDeskCaseController.addMessage";
import uploadMessageFileExternal from "@salesforce/apex/ModuloHelpDeskCaseController.uploadMessageFileExternal";

const STATUS_COLORS = {
  Criado: "#6b7280",
  "Pendente Aprovação Gestor": "#d97706",
  "Pendente Aprovação Gerente": "#ea580c",
  Aprovado: "#0284c7",
  Trabalhando: "#7c3aed",
  Concluído: "#16a34a"
};

export default class HelpDeskCaseDetail extends LightningElement {
  _recordId;
  caseId;
  contactId;
  authorName;
  detail;
  wiredDetail;
  @track messages = [];
  @track pendingFiles = [];
  readingFiles = false;
  newComment = "";
  isSaving = false;
  pageRef;
  _refreshTimer;

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    this.caseId = value || this.caseId;
  }

  @wire(CurrentPageReference)
  wiredPageRef(ref) {
    this.pageRef = ref;
    const fromState =
      ref?.state?.recordId ||
      ref?.state?.c__recordId ||
      ref?.attributes?.recordId;
    const contactState = ref?.state?.cId || ref?.state?.c__contactId;
    const nameState = ref?.state?.authorName || ref?.state?.c__authorName;
    if (!this.caseId && fromState) {
      this.caseId = fromState;
    }
    if (!this.contactId && contactState) {
      this.contactId = contactState;
    }
    if (!this.authorName && nameState) {
      this.authorName = nameState;
    }
  }

  @wire(getCaseDetail, { caseId: "$caseId", contactId: "$contactId" })
  wiredCaseDetail(result) {
    this.wiredDetail = result;
    const { data, error } = result;
    if (data) {
      this.detail = this.normalizeDetail(data);
    } else if (error) {
      this.handleError("Erro ao carregar caso", error);
    }
  }

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
    if (!this.caseId) {
      return;
    }
    getMessages({ caseId: this.caseId, contactId: this.contactId })
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
      date: this.formatDate(msg.CreatedDate),
      initials: this.getInitials(
        msg.AuthorName__c || (msg.CreatedBy ? msg.CreatedBy.Name : "U")
      ),
      attachments,
      hasAttachments: attachments.length > 0
    };
  }

  get isOpen() {
    return this.detail && this.detail.helpDeskStatus !== "Concluído";
  }

  get isBlank() {
    return !this.newComment || !this.newComment.trim();
  }

  get isAddDisabled() {
    return this.isSaving || this.readingFiles || this.isBlank;
  }

  get hasMessages() {
    return this.messages && this.messages.length > 0;
  }

  get acceptedFormats() {
    return ".pdf,.png,.jpg,.jpeg,.doc,.docx,.xls,.xlsx,.txt";
  }

  get statusBadgeStyle() {
    if (!this.detail) {
      return "";
    }
    const color = STATUS_COLORS[this.detail.helpDeskStatus] || "#6b7280";
    return `background-color:${color};`;
  }

  handleCommentChange(event) {
    this.newComment = event.target.value;
  }

  handleFilesChange(event) {
    const files = event.target.files;
    if (!files || files.length === 0) {
      return;
    }
    this.readingFiles = true;
    const readers = [];
    Array.from(files).forEach((file) => {
      readers.push(
        new Promise((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => {
            const base64 = reader.result.split(",")[1];
            resolve({
              fileName: file.name,
              contentType: file.type,
              base64Data: base64,
              humanSize: this.formatSize(file.size),
              name: file.name
            });
          };
          reader.onerror = reject;
          reader.readAsDataURL(file);
        })
      );
    });

    Promise.all(readers)
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

  removePendingFile(event) {
    const name = event.currentTarget.dataset.name;
    this.pendingFiles = this.pendingFiles.filter((f) => f.name !== name);
  }

  handleAddComment() {
    if (this.isBlank || !this.caseId) {
      return;
    }
    this.isSaving = true;
    const body = this.newComment;
    const name = this.authorName || "Cliente";
    const filesToUpload = [...this.pendingFiles];

    addMessage({
      caseId: this.caseId,
      body,
      authorName: name,
      authorType: "Cliente",
      isPublic: true,
      contactId: this.contactId
    })
      .then((messageId) => {
        if (filesToUpload.length === 0 || !messageId) {
          return null;
        }
        const uploads = filesToUpload.map((file) =>
          uploadMessageFileExternal({
            caseId: this.caseId,
            messageId,
            fileName: file.fileName || file.name,
            base64File: file.base64Data,
            contactId: this.contactId
          }).catch(() => null)
        );
        return Promise.all(uploads);
      })
      .then(() => {
        this._loadMessages();
      })
      .catch((error) => {
        this.handleError("Não foi possível adicionar o comentário", error);
      })
      .finally(() => {
        this.isSaving = false;
        this.newComment = "";
        this.pendingFiles = [];
        this.readingFiles = false;
      });
  }

  normalizeDetail(data) {
    return {
      id: data.Id,
      caseNumber: data.CaseNumber,
      subject: data.Subject,
      status: data.Status,
      helpDeskStatus: data.HelpDesk_Status__c || "Criado",
      contactName: data.Contact ? data.Contact.Name : "",
      createdDateDisplay: this.formatDate(data.CreatedDate),
      lastModifiedDisplay: this.formatDate(data.LastModifiedDate),
      richDescription: data.Description_Rich__c || data.Description || ""
    };
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

  buildApexFilePayload() {
    return this.pendingFiles.map((file) => ({
      fileName: file.fileName || file.name || "",
      contentType: file.contentType || "",
      base64Data: file.base64Data || "",
      humanSize: file.humanSize || "",
      name: file.name || file.fileName || ""
    }));
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
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
