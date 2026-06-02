import { api, LightningElement, wire, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { refreshApex } from "@salesforce/apex";
import { CurrentPageReference } from "lightning/navigation";
import getCaseDetail from "@salesforce/apex/ModuloHelpDeskCaseController.getCaseDetail";
import getMessages from "@salesforce/apex/ModuloHelpDeskCaseController.getMessages";
import getApprovalStatus from "@salesforce/apex/ModuloHelpDeskCaseController.getApprovalStatus";
import addMessage from "@salesforce/apex/ModuloHelpDeskCaseController.addMessage";
import getMessageAttachments from "@salesforce/apex/ModuloHelpDeskCaseController.getMessageAttachments";
import uploadMessageFileExternal from "@salesforce/apex/ModuloHelpDeskCaseController.uploadMessageFileExternal";

const IMAGE_EXTENSIONS = ["png", "jpg", "jpeg", "gif", "webp", "bmp"];

export default class HelpDeskCaseDetail extends LightningElement {
  @api recordId;
  contactId;
  detail;
  wiredDetail;
  wiredMessages;
  wiredAttachments;
  wiredApproval;
  @track messages = [];
  @track attachmentsByMessage = {};
  @track approvalInfo;
  @track pendingFiles = [];
  readingFiles = false;
  newComment = "";
  isSaving = false;
  pageRef;
  jiraStatusRefreshTimer;
  approvalCacheRefreshRequested = false;

  // Preview modal state (reusa c-attachment-preview-modal)
  previewOpen = false;
  previewUrl;
  previewTitle;

  @wire(CurrentPageReference)
  wiredPageRef(ref) {
    this.pageRef = ref;
    const fromState =
      ref?.state?.recordId ||
      ref?.state?.c__recordId ||
      ref?.attributes?.recordId;
    const contactState = ref?.state?.cId || ref?.state?.c__contactId;
    if (!this.resolvedRecordId && fromState) {
      this.resolvedRecordId = fromState;
    }
    if (!this.contactId && contactState) {
      this.contactId = contactState;
    }
  }

  @wire(getCaseDetail, { caseId: "$recordId", contactId: "$contactId" })
  wiredCaseDetail(result) {
    this.wiredDetail = result;
    const { data, error } = result;
    if (data) {
      this.detail = this.normalizeDetail(data);
    } else if (error) {
      this.handleError("Erro ao carregar caso", error);
    }
  }

  @wire(getMessageAttachments, { caseId: "$recordId", contactId: "$contactId" })
  wiredMessageAttachments(result) {
    this.wiredAttachments = result;
    const { data, error } = result;
    if (data) {
      this.attachmentsByMessage = this.groupAttachments(data);
      this.applyAttachmentsToMessages();
    } else if (error) {
      this.handleError("Erro ao carregar anexos", error);
    }
  }

  @wire(getApprovalStatus, { caseId: "$recordId", contactId: "$contactId" })
  wiredCaseApproval(result) {
    this.wiredApproval = result;
    const { data, error } = result;
    if (data) {
      this.approvalInfo = data;
    } else if (error) {
      this.handleError("Erro ao carregar aprovação", error);
    }
  }

  @wire(getMessages, { caseId: "$recordId", contactId: "$contactId" })
  wiredCaseMessages(result) {
    this.wiredMessages = result;
    const { data, error } = result;
    if (data) {
      // Ordena defensivamente do mais novo para o mais antigo (além do ORDER BY DESC do backend).
      const sorted = [...data].sort(
        (a, b) =>
          new Date(b.CreatedDate).getTime() - new Date(a.CreatedDate).getTime()
      );
      this.messages = sorted.map((item) => this.normalizeMessage(item));
      this.applyAttachmentsToMessages();
    } else if (error) {
      this.handleError("Erro ao carregar comentários", error);
    }
  }

  get isOpen() {
    return this.detail && this.detail.status !== "Fechado";
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

  get hasApprovalStatus() {
    return this.detail && !!this.detail.approvalStatus;
  }

  get showApprovalPanel() {
    return (
      this.hasApprovalStatus ||
      !!this.approvalInfo?.currentApproverName ||
      !!this.approvalInfo?.supervisorName ||
      !!this.approvalInfo?.gerenteName
    );
  }

  get approvalStatusLabel() {
    return (
      this.approvalInfo?.status || this.detail?.approvalStatus || "Não iniciado"
    );
  }

  get isApproved() {
    return this.approvalStatusLabel === "Aprovado";
  }

  get isRejected() {
    return this.approvalStatusLabel === "Rejeitado";
  }

  get approvalCardClass() {
    const base = "approval-card";
    if (this.isApproved) {
      return `${base} is-approved`;
    }
    if (this.isRejected) {
      return `${base} is-rejected`;
    }
    return base;
  }

  get approvalBadgeVariant() {
    if (this.isApproved) {
      return "success";
    }
    if (this.isRejected) {
      return "error";
    }
    return "warning";
  }

  get currentApproverLabel() {
    if (this.isApproved) {
      return "Aprovado";
    }
    if (this.isRejected) {
      return "Rejeitado";
    }
    if (this.approvalInfo?.currentApproverName) {
      return this.approvalInfo.currentApproverName;
    }
    if (
      this.approvalInfo?.supervisorName &&
      this.approvalStatusLabel === "Em Aprovação"
    ) {
      return this.approvalInfo.supervisorName;
    }
    return "Aguardando envio para aprovação";
  }

  get approvalRouteLabel() {
    const supervisor =
      this.approvalInfo?.supervisorName || "Supervisor não definido";
    const gerente = this.approvalInfo?.gerenteName || "Gerente não definido";
    return `${supervisor} -> ${gerente}`;
  }

  get hasJiraActivity() {
    return !!this.detail?.jiraIssueKey;
  }

  get jiraStatusLabel() {
    return this.detail?.jiraStatus || "Aguardando atualização";
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

  async handleAddComment() {
    if (this.isBlank || !this.recordId) {
      return;
    }
    this.isSaving = true;
    let uploadError;
    try {
      const isPortalClient = !!this.contactId;
      const messageId = await addMessage({
        caseId: this.recordId,
        body: this.newComment,
        authorName: isPortalClient ? this.detail?.contactName : null,
        authorType: isPortalClient ? "Cliente" : "Agente",
        isPublic: true,
        contactId: this.contactId
      });

      const uploadResults = await Promise.all(
        this.pendingFiles.map((file) =>
          uploadMessageFileExternal({
            caseId: this.recordId,
            messageId,
            fileName: file.fileName || file.name,
            base64File: file.base64Data,
            contactId: this.contactId
          }).catch((err) => err)
        )
      );
      uploadError = uploadResults.find(
        (result) => result instanceof Error || result?.body || result?.message
      );

      this.newComment = "";
      this.pendingFiles = [];
    } catch (error) {
      this.handleError("Não foi possível adicionar o comentário", error);
    } finally {
      // Recarrega histórico e anexos sempre, mesmo após erro parcial de upload.
      await Promise.all([
        refreshApex(this.wiredMessages),
        refreshApex(this.wiredAttachments)
      ]);
      this.isSaving = false;
      this.readingFiles = false;
      if (uploadError) {
        this.handleError(
          "Comentário salvo, mas houve falha ao anexar arquivo",
          uploadError
        );
      }
    }
  }

  handleOpenAttachment(event) {
    const url = event.currentTarget.dataset.url;
    const title = event.currentTarget.dataset.title;
    if (!url) {
      return;
    }
    this.previewUrl = url;
    this.previewTitle = title || "Anexo";
    this.previewOpen = true;
  }

  handleClosePreview() {
    this.previewOpen = false;
    this.previewUrl = undefined;
    this.previewTitle = undefined;
  }

  handleOpenInNewTab(event) {
    const url = event.currentTarget.dataset.url;
    if (url) {
      window.open(url, "_blank", "noopener,noreferrer");
    }
  }

  handleReopen() {
    this.showToast(
      "Ação futura",
      "Fluxo de reabertura pode ser adicionado aqui.",
      "info"
    );
  }

  normalizeDetail(data) {
    return {
      id: data.Id,
      caseNumber: data.CaseNumber,
      subject: data.Subject,
      status: data.Status,
      approvalStatus: data.StatusAprovacao__c || "",
      jiraIssueKey: data.JiraIssueKey__c || "",
      jiraIssueUrl: data.JiraIssueUrl__c || "",
      jiraStatus: data.JiraStatus__c || "",
      contactName: data.Contact ? data.Contact.Name : "",
      createdDateDisplay: this.formatDate(data.CreatedDate),
      lastModifiedDisplay: this.formatDate(data.LastModifiedDate),
      richDescription: data.Description_Rich__c || data.Description || ""
    };
  }

  updateJiraStatusPolling() {
    const shouldPoll = this.hasJiraActivity || !!this.detail?.approvalStatus;
    if (!shouldPoll) {
      this.stopJiraStatusPolling();
      return;
    }
    if (this.jiraStatusRefreshTimer) {
      return;
    }
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.jiraStatusRefreshTimer = window.setInterval(() => {
      if (this.wiredDetail) {
        refreshApex(this.wiredDetail);
      }
      if (this.wiredApproval) {
        refreshApex(this.wiredApproval);
      }
    }, 10000);
  }

  stopJiraStatusPolling() {
    if (this.jiraStatusRefreshTimer) {
      window.clearInterval(this.jiraStatusRefreshTimer);
      this.jiraStatusRefreshTimer = undefined;
    }
  }

  normalizeMessage(item) {
    const author =
      item.AuthorName__c || (item.CreatedBy ? item.CreatedBy.Name : "Cliente");
    return {
      id: item.Id,
      body: item.Body__c,
      date: this.formatDate(item.CreatedDate),
      author,
      authorType: item.AuthorType__c || "Cliente",
      initials: author ? this.getInitials(author) : "C",
      attachments: []
    };
  }

  groupAttachments(links) {
    const grouped = {};
    links.forEach((link) => {
      const parentId = link.SObjectId__c;
      if (!parentId) {
        return;
      }
      const url = link.AttachmentURL__c || link.InternalAttachmentURL__c;
      const fileType = (
        link.FileType__c ||
        this.extensionFromName(link.FileName__c) ||
        ""
      ).toLowerCase();
      const isImage = IMAGE_EXTENSIONS.includes(fileType);
      const attachment = {
        id: link.Id,
        url,
        title: link.FileName__c || link.AttachmentDescription__c || "Anexo",
        isImage,
        iconName: this.resolveIconName(fileType)
      };
      if (!grouped[parentId]) {
        grouped[parentId] = [];
      }
      grouped[parentId].push(attachment);
    });
    return grouped;
  }

  applyAttachmentsToMessages() {
    if (!this.messages || this.messages.length === 0) {
      return;
    }
    const byMessage = this.attachmentsByMessage || {};
    this.messages = this.messages.map((msg) => {
      const atts = byMessage[msg.id] || [];
      return { ...msg, attachments: atts, hasAttachments: atts.length > 0 };
    });
  }

  extensionFromName(name) {
    if (!name || name.indexOf(".") === -1) {
      return "";
    }
    return name.substring(name.lastIndexOf(".") + 1);
  }

  resolveIconName(fileType) {
    const type = (fileType || "").toLowerCase();
    if (IMAGE_EXTENSIONS.includes(type)) {
      return "doctype:image";
    }
    if (type === "pdf") {
      return "doctype:pdf";
    }
    if (type === "doc" || type === "docx") {
      return "doctype:word";
    }
    if (type === "xls" || type === "xlsx" || type === "csv") {
      return "doctype:excel";
    }
    if (type === "txt") {
      return "doctype:txt";
    }
    return "doctype:attachment";
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
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
