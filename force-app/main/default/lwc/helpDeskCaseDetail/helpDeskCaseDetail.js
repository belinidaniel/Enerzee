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
import {
  formatFileSize,
  groupMessageAttachments,
  initialsFromName
} from "c/helpDeskAttachmentUtils";

export default class HelpDeskCaseDetail extends LightningElement {
  // Em Record Page nativa o recordId é injetado pela plataforma; numa página
  // custom da Experience Cloud (rota /helpdesk/case/:id) ele NÃO é, então
  // resolvemos via CurrentPageReference. Os @wire observam resolvedRecordId,
  // que é alimentado tanto pelo @api recordId quanto pela rota.
  @api
  get recordId() {
    return this.resolvedRecordId;
  }
  set recordId(value) {
    if (value) {
      this.resolvedRecordId = value;
    }
  }
  @track resolvedRecordId = null;
  contactId = null;
  detail;
  isLoading = true;
  loadError;
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
      ref?.attributes?.recordId ||
      this.recordIdFromUrl();
    const contactState = ref?.state?.cId || ref?.state?.c__contactId;
    if (!this.resolvedRecordId && fromState) {
      this.resolvedRecordId = fromState;
    }
    if (!this.contactId && contactState) {
      this.contactId = contactState;
    }
  }

  @wire(getCaseDetail, { caseId: "$resolvedRecordId", contactId: "$contactId" })
  wiredCaseDetail(result) {
    this.wiredDetail = result;
    const { data, error } = result;
    if (data) {
      this.detail = this.normalizeDetail(data);
      this.loadError = null;
      this.isLoading = false;
    } else if (error) {
      this.detail = null;
      this.loadError = this.normalizeError(error);
      this.isLoading = false;
      this.handleError("Erro ao carregar caso", error);
    }
  }

  @wire(getMessageAttachments, {
    caseId: "$resolvedRecordId",
    contactId: "$contactId"
  })
  wiredMessageAttachments(result) {
    this.wiredAttachments = result;
    const { data, error } = result;
    if (data) {
      this.attachmentsByMessage = groupMessageAttachments(data);
    } else if (error) {
      this.handleError("Erro ao carregar anexos", error);
    }
  }

  @wire(getApprovalStatus, {
    caseId: "$resolvedRecordId",
    contactId: "$contactId"
  })
  wiredCaseApproval(result) {
    this.wiredApproval = result;
    const { data, error } = result;
    if (data) {
      this.approvalInfo = data;
    } else if (error) {
      this.handleError("Erro ao carregar aprovação", error);
    }
  }

  @wire(getMessages, { caseId: "$resolvedRecordId", contactId: "$contactId" })
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
    } else if (error) {
      this.handleError("Erro ao carregar comentários", error);
    }
  }

  // Combina mensagens + anexos no momento do render, evitando race condition
  // entre os dois @wire (mensagens e anexos chegam de forma assíncrona/independente).
  get displayMessages() {
    const byMessage = this.attachmentsByMessage || {};
    return (this.messages || []).map((msg) => {
      const atts = byMessage[msg.id] || [];
      return { ...msg, attachments: atts, hasAttachments: atts.length > 0 };
    });
  }

  get isOpen() {
    return this.detail && this.detail.status !== "Fechado";
  }

  get showLoading() {
    return this.isLoading && !this.detail;
  }

  get hasLoadError() {
    return !this.isLoading && !this.detail && !!this.loadError;
  }

  handleRetry() {
    if (!this.wiredDetail) {
      return;
    }
    this.isLoading = true;
    this.loadError = null;
    refreshApex(this.wiredDetail).catch((error) => {
      this.loadError = this.normalizeError(error);
      this.isLoading = false;
    });
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

  get hasDescription() {
    return !!(this.detail?.richDescription || this.detail?.plainDescription);
  }

  get hasApprovalStatus() {
    return this.detail && !!this.detail.approvalStatus;
  }

  get showApprovalPanel() {
    return !!this.detail;
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

  get hasJiraActivity() {
    return !!this.detail?.jiraIssueKey;
  }

  get jiraStatusLabel() {
    if (!this.isApproved && !this.detail?.jiraStatus) {
      return "Aguardando aprovação";
    }
    return this.detail?.jiraStatus || "Aguardando atualização do Jira";
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
              humanSize: formatFileSize(file.size),
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

  normalizeDetail(data) {
    const hasRich = !!data.Description_Rich__c;
    return {
      id: data.Id,
      caseNumber: data.CaseNumber,
      subject: data.Subject,
      status: data.Status,
      approvalStatus: data.StatusAprovacao__c || "",
      jiraIssueKey: data.JiraIssueKey__c || "",
      jiraIssueUrl: data.JiraIssueUrl__c || "",
      jiraStatus: data.JiraStatus__c || "",
      system: data.HelpDesk_Sistema__c || "",
      contactName: data.Contact?.Name || data.CreatedBy?.Name || "",
      createdDateDisplay: this.formatDate(data.CreatedDate),
      lastModifiedDisplay: this.formatDate(data.LastModifiedDate),
      // Rich text vai como HTML; o fallback (Description em texto puro) é
      // exibido preservando as quebras de linha (CSS white-space: pre-wrap),
      // sem o prefixo técnico "Sistema:" que é montado no backend.
      richDescription: hasRich ? data.Description_Rich__c : "",
      plainDescription: hasRich
        ? ""
        : this.stripSistemaPrefix(
            data.Description || "",
            data.HelpDesk_Sistema__c || ""
          )
    };
  }

  // Remove somente o prefixo técnico correspondente ao sistema do próprio Case.
  // O fallback sem systemValue preserva a visualização de casos legados.
  stripSistemaPrefix(text, systemValue) {
    if (!text) {
      return "";
    }
    const lines = text.split(/\r?\n/);
    const firstLine = lines[0]?.trim() || "";
    const expectedPrefix = systemValue ? `Sistema: ${systemValue}` : null;
    if (
      firstLine === expectedPrefix ||
      (!expectedPrefix && /^Sistema:.*$/.test(firstLine))
    ) {
      return lines.slice(1).join("\n").trim();
    }
    return text.trim();
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
      initials: initialsFromName(author, "C"),
      attachments: []
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

  handleError(title, error) {
    this.showToast(title, this.normalizeError(error), "error");
  }

  // Fallback: extrai o Id do Case direto do path (/helpdesk/case/{id}) quando
  // o CurrentPageReference não traz recordId em state nem attributes — depende
  // de como a rota path-based está mapeada no Experience Builder.
  recordIdFromUrl() {
    const path = window.location.pathname || "";
    const match = path.match(/\/case\/(500[A-Za-z0-9]{12,15})(?:\/|$)/);
    return match ? match[1] : null;
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