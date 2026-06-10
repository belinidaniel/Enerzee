import { LightningElement, api, wire, track } from "lwc";
import { refreshApex } from "@salesforce/apex";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getCases from "@salesforce/apex/ModuloHelpDeskCaseController.getCases";

export default class HelpDeskCaseList extends LightningElement {
  @api contactId = null;
  filterOptions = [
    { label: "Meus casos abertos", value: "open" },
    { label: "Meus casos fechados", value: "closed" }
  ];
  approvalFilterOptions = [
    { label: "Todas as aprovações", value: "all" },
    { label: "Pendente", value: "Pendente" },
    { label: "Em Aprovação", value: "Em Aprovação" },
    { label: "Aprovado", value: "Aprovado" },
    { label: "Reprovado", value: "Rejeitado" }
  ];

  filterType = "open";
  approvalFilter = "all";
  executionFilter = "all";
  searchTerm = "";
  @track cases = [];
  allCases = [];
  isLoading = true;
  wiredResult;

  @wire(getCases, {
    filterType: "$filterType",
    searchTerm: "$searchTerm",
    contactId: "$contactId"
  })
  wiredCases(result) {
    this.wiredResult = result;
    const { data, error } = result;
    this.isLoading = false;

    if (data) {
      this.allCases = data.map((c) => ({
        id: c.Id,
        caseNumber: c.CaseNumber,
        subject: c.Subject,
        status: c.Status,
        approvalStatus: c.StatusAprovacao__c || "Não iniciado",
        executionStatus: c.JiraStatus__c || "Aguardando aprovação",
        lastModified: new Intl.DateTimeFormat("pt-BR", {
          year: "numeric",
          month: "short",
          day: "2-digit",
          hour: "2-digit",
          minute: "2-digit"
        }).format(new Date(c.LastModifiedDate)),
        requesterName: c.Contact?.Name || c.CreatedBy?.Name || "",
        url: this.contactId
          ? `/case/${c.Id}?cId=${this.contactId}`
          : `/lightning/n/Help_Desk?c__recordId=${c.Id}`
      }));
      this.applyStatusFilters();
    } else if (error) {
      this.allCases = [];
      this.cases = [];
      this.showToast(
        "Erro ao carregar casos",
        this.normalizeError(error),
        "error"
      );
    }
  }

  get hasCases() {
    return this.cases && this.cases.length > 0;
  }

  get caseCount() {
    return this.cases ? this.cases.length : 0;
  }

  get executionFilterOptions() {
    const defaultStatuses = [
      "Aguardando aprovação",
      "Em Análise",
      "Pendente",
      "Em Andamento",
      "Finalizado"
    ];
    const receivedStatuses = this.allCases
      .map((caseItem) => caseItem.executionStatus)
      .filter(Boolean);
    const statuses = [...new Set([...defaultStatuses, ...receivedStatuses])];
    return [
      { label: "Todas as execuções", value: "all" },
      ...statuses.map((status) => ({ label: status, value: status }))
    ];
  }

  handleFilterChange(event) {
    this.filterType = event.detail.value;
    this.isLoading = true;
  }

  handleApprovalFilterChange(event) {
    this.approvalFilter = event.detail.value;
    this.applyStatusFilters();
  }

  handleExecutionFilterChange(event) {
    this.executionFilter = event.detail.value;
    this.applyStatusFilters();
  }

  handleSearchChange(event) {
    this.searchTerm = event.target.value;
    this.isLoading = true;
  }

  applyStatusFilters() {
    this.cases = this.allCases.filter((caseItem) => {
      const matchesApproval =
        this.approvalFilter === "all" ||
        caseItem.approvalStatus === this.approvalFilter;
      const matchesExecution =
        this.executionFilter === "all" ||
        caseItem.executionStatus === this.executionFilter;
      return matchesApproval && matchesExecution;
    });
  }

  handleRefresh() {
    this.isLoading = true;
    refreshApex(this.wiredResult).finally(() => {
      this.isLoading = false;
    });
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
