import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import getContext from "@salesforce/apex/OpportunityProductSelectorController.getContext";
import searchProducts from "@salesforce/apex/OpportunityProductSelectorController.searchProducts";
import addProducts from "@salesforce/apex/OpportunityProductSelectorController.addProducts";

const DEBOUNCE_DELAY = 300;
const DEFAULT_PAGE_SIZE = 20;
const REGION_OPTIONS = [
  { label: "--None--", value: "" },
  { label: "NORTE", value: "NORTE" },
  { label: "NORDESTE", value: "NORDESTE" },
  { label: "CO", value: "CO" },
  { label: "SUDESTE", value: "SUDESTE" },
  { label: "SUL", value: "SUL" }
];
const STRUCTURE_TYPE_OPTIONS = [
  { label: "--None--", value: "" },
  { label: "Ao Solo", value: "Ao Solo" },
  { label: "Cerâmico", value: "Cerâmico" },
  { label: "Carport", value: "Carport" },
  { label: "Fibrocimento (Metálico)", value: "Fibrocimento (Metálico)" },
  { label: "Fibrocimento (Madeira)", value: "Fibrocimento (Madeira)" },
  { label: "Metálico", value: "Metálico" },
  { label: "Laje", value: "Laje" },
  { label: "Zipado", value: "Zipado" },
  { label: "Shingle", value: "Shingle" },
  { label: "Car Port", value: "Car Port" }
];
const KIT_PROMOTIONAL_OPTIONS = [
  { label: "--None--", value: "" },
  { label: "KITS MONOFÁSICOS", value: "1" },
  { label: "KITS TRIFÁSICOS", value: "2" },
  { label: "KITS MICRO", value: "3" },
  { label: "CAMPANHA WEG - FAST TRACK", value: "4" },
  { label: "KITS TRIFÁSICOS PROMO WEG", value: "5" },
  { label: "KIT SOLAR + BESS", value: "6" },
  { label: "KITS MONOFÁSICOS SEM WEGHOME", value: "7" },
  { label: "KITS MICRO SEM WEGHOME", value: "8" }
];
const SALESFORCE_ID_REGEX = /^[a-zA-Z0-9]{15}(?:[a-zA-Z0-9]{3})?$/;

const TABLE_COLUMNS = [
  {
    label: "Produto",
    fieldName: "name",
    type: "text"
  },
  {
    label: "Código",
    fieldName: "productCode",
    type: "text"
  },
  {
    label: "External Id",
    fieldName: "externalId",
    type: "text"
  },
  {
    label: "Região",
    fieldName: "family",
    type: "text"
  },
  {
    label: "Preço",
    fieldName: "unitPrice",
    type: "currency",
    typeAttributes: {
      currencyCode: "BRL"
    }
  },
  {
    label: "Descrição",
    fieldName: "description",
    type: "text",
    wrapText: true
  }
];

export default class OpportunityProductSelector extends LightningElement {
  _recordId;
  debounceTimeout;
  requestSequence = 0;

  columns = TABLE_COLUMNS;
  context;
  products = [];
  feedbackItems = [];

  searchText = "";
  showAllRegions = false;
  selectedRegion = "";
  selectedStructureType = "";
  selectedKitPromotional = "";
  showSelectedOnly = false;
  currentStep = "selection";

  selectedEntriesById = {};
  selectedEntryOrder = [];
  selectedRowIds = [];

  offset = 0;
  pageSize = DEFAULT_PAGE_SIZE;
  hasMore = false;

  isLoadingContext = false;
  isLoadingProducts = false;
  isSubmitting = false;

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    if (value) {
      this.initialize();
    }
  }

  connectedCallback() {
    if (this.recordId) {
      this.initialize();
    }
  }

  disconnectedCallback() {
    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout);
      this.debounceTimeout = null;
    }
  }

  get hasContext() {
    return !!this.context;
  }

  get estadoInstalacaoLabel() {
    return this.context?.estadoInstalacao || "-";
  }

  get regiaoInstalacaoLabel() {
    return this.context?.regiaoInstalacao || "-";
  }

  get isBlocked() {
    return this.hasContext && this.context.canAddProducts === false;
  }

  get blockingMessage() {
    return this.context?.blockingMessage;
  }

  get disableSearch() {
    return (
      this.isBlocked ||
      this.isLoadingContext ||
      this.currentStep !== "selection"
    );
  }

  get disableRegionFilter() {
    return this.disableSearch || this.showAllRegions;
  }

  get regionOptions() {
    return REGION_OPTIONS;
  }

  get structureTypeOptions() {
    return STRUCTURE_TYPE_OPTIONS;
  }

  get kitPromotionalOptions() {
    return KIT_PROMOTIONAL_OPTIONS;
  }

  get isSelectionStep() {
    return this.currentStep === "selection";
  }

  get isQuantityStep() {
    return this.currentStep === "quantity";
  }

  get selectedCount() {
    return this.selectedEntryOrder.length;
  }

  get canToggleSelected() {
    return this.selectedCount > 0;
  }

  get selectedToggleLabel() {
    return this.showSelectedOnly
      ? "Voltar aos resultados"
      : `Mostrar selecionados (${this.selectedCount})`;
  }

  get selectedEntriesList() {
    return this.selectedEntryOrder
      .map((entryId) => this.selectedEntriesById[entryId])
      .filter(Boolean);
  }

  get filteredSelectedEntries() {
    const normalizedSearch = this.normalizeSearchText(this.searchText);
    if (!normalizedSearch) {
      return this.selectedEntriesList;
    }

    return this.selectedEntriesList.filter((entry) =>
      this.matchesSearch(entry, normalizedSearch)
    );
  }

  get displayedProducts() {
    return this.showSelectedOnly ? this.filteredSelectedEntries : this.products;
  }

  get hasProducts() {
    return this.displayedProducts.length > 0;
  }

  get showPagination() {
    return this.isSelectionStep && !this.showSelectedOnly;
  }

  get hasSelectedProducts() {
    return this.selectedCount > 0;
  }

  get isPreviousDisabled() {
    return this.isLoadingProducts || this.offset <= 0 || this.showSelectedOnly;
  }

  get isNextDisabled() {
    return this.isLoadingProducts || !this.hasMore || this.showSelectedOnly;
  }

  get currentPageLabel() {
    const currentPage = Math.floor(this.offset / this.pageSize) + 1;
    return `Página ${currentPage}`;
  }

  get isNextStepDisabled() {
    return (
      this.isBlocked ||
      this.isLoadingProducts ||
      this.isSubmitting ||
      !this.hasSelectedProducts
    );
  }

  get selectedProductsForEdit() {
    return this.selectedEntriesList.map((entry, index) => ({
      ...entry,
      rowNumber: index + 1
    }));
  }

  get hasSelectedProductsForEdit() {
    return this.selectedProductsForEdit.length > 0;
  }

  get hasInvalidEditorValues() {
    return this.selectedProductsForEdit.some((entry) => {
      const quantity = this.parseDecimal(entry.quantity);
      return quantity === null || quantity <= 0;
    });
  }

  get isAddDisabled() {
    return (
      this.isBlocked ||
      this.isSubmitting ||
      !this.hasSelectedProductsForEdit ||
      this.hasInvalidEditorValues
    );
  }

  get addButtonLabel() {
    return this.isSubmitting ? "Incluindo..." : "Incluir Selecionados";
  }

  get hasFeedback() {
    return this.feedbackItems.length > 0;
  }

  async initialize() {
    if (!this.recordId || this.isLoadingContext) {
      return;
    }

    this.resetUiState();

    let shouldLoadProducts = false;
    this.isLoadingContext = true;
    try {
      this.context = await getContext({ opportunityId: this.recordId });
      this.selectedRegion = this.context?.regiaoInstalacao || "";
      this.selectedStructureType = this.context?.tipoTelhadoEstrutura || "";
      this.selectedKitPromotional = this.context?.tipoKitPromocional || "";
      if (!this.isBlocked) {
        shouldLoadProducts = true;
      }
    } catch (error) {
      this.showToast("Erro", this.reduceError(error), "error");
    } finally {
      this.isLoadingContext = false;
    }

    if (shouldLoadProducts) {
      await this.fetchProducts(true);
    }
  }

  resetUiState() {
    this.feedbackItems = [];
    this.products = [];
    this.selectedRegion = "";
    this.selectedStructureType = "";
    this.selectedKitPromotional = "";
    this.selectedEntriesById = {};
    this.selectedEntryOrder = [];
    this.selectedRowIds = [];
    this.showSelectedOnly = false;
    this.currentStep = "selection";
    this.offset = 0;
    this.hasMore = false;
  }

  handleSearchInput(event) {
    this.feedbackItems = [];
    this.searchText = event.detail?.value ?? event.target?.value ?? "";

    if (this.showSelectedOnly) {
      this.syncSelectedRowsForTable();
      return;
    }

    this.scheduleSearch();
  }

  handleShowAllRegionsChange(event) {
    this.feedbackItems = [];
    this.showAllRegions = event.target.checked;
    this.fetchProducts(true);
  }

  handleRegionFilterChange(event) {
    this.feedbackItems = [];
    this.selectedRegion = event.detail?.value ?? "";
    this.fetchProducts(true);
  }

  handleStructureTypeFilterChange(event) {
    this.feedbackItems = [];
    this.selectedStructureType = event.detail?.value ?? "";
    this.fetchProducts(true);
  }

  handleKitPromotionalFilterChange(event) {
    this.feedbackItems = [];
    this.selectedKitPromotional = event.detail?.value ?? "";
    this.fetchProducts(true);
  }

  async handleToggleShowSelected() {
    if (!this.canToggleSelected) {
      return;
    }

    this.showSelectedOnly = !this.showSelectedOnly;

    if (!this.showSelectedOnly) {
      await this.fetchProducts(true);
      return;
    }

    this.syncSelectedRowsForTable();
  }

  scheduleSearch() {
    if (!this.isSelectionStep) {
      return;
    }

    if (this.debounceTimeout) {
      clearTimeout(this.debounceTimeout);
    }

    // Debounce de busca incremental da tela.
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.debounceTimeout = setTimeout(() => {
      this.fetchProducts(true);
    }, DEBOUNCE_DELAY);
  }

  async fetchProducts(resetOffset = false, explicitOffset) {
    if (this.disableSearch || this.showSelectedOnly) {
      this.syncSelectedRowsForTable();
      return;
    }

    const requestId = ++this.requestSequence;
    const targetOffset = resetOffset
      ? 0
      : explicitOffset !== undefined
        ? explicitOffset
        : this.offset;

    this.isLoadingProducts = true;
    try {
      const response = await searchProducts({
        opportunityId: this.recordId,
        searchText: this.searchText,
        showAllRegions: this.showAllRegions,
        structureTypeFilter: this.selectedStructureType || null,
        regionFilter: this.selectedRegion || null,
        kitPromotionalFilter: this.selectedKitPromotional || null,
        pageSize: this.pageSize,
        offset: targetOffset
      });

      if (requestId !== this.requestSequence) {
        return;
      }

      this.pageSize = response?.pageSize || this.pageSize;
      this.offset = targetOffset;
      this.hasMore = response?.hasMore === true;
      this.products = (response?.items || [])
        .map((item) => this.normalizeProductRow(item))
        .filter((item) => !!item?.pricebookEntryId);
      this.syncSelectedRowsForTable();
    } catch (error) {
      this.showToast("Erro", this.reduceError(error), "error");
    } finally {
      if (requestId === this.requestSequence) {
        this.isLoadingProducts = false;
      }
    }
  }

  handlePreviousPage() {
    if (this.isPreviousDisabled) {
      return;
    }

    const previousOffset = Math.max(this.offset - this.pageSize, 0);
    this.fetchProducts(false, previousOffset);
  }

  handleNextPage() {
    if (this.isNextDisabled) {
      return;
    }

    this.fetchProducts(false, this.offset + this.pageSize);
  }

  handleRowSelection(event) {
    this.feedbackItems = [];
    const selectedRows = event.detail.selectedRows || [];
    const action = event.detail?.config?.action;
    const affectedEntryId = this.normalizeEntryId(event.detail?.config?.value);

    if (action === "rowSelect") {
      const selectedRow = selectedRows.find(
        (row) => this.resolveEntryId(row) === affectedEntryId
      );
      if (selectedRow) {
        this.upsertSelectedEntry(selectedRow);
      }
      return;
    }

    if (action === "rowDeselect") {
      this.removeSelectedEntry(affectedEntryId);
      return;
    }

    if (action === "selectAllRows") {
      this.displayedProducts.forEach((row) => {
        this.upsertSelectedEntry(row);
      });
      return;
    }

    if (action === "deselectAllRows") {
      this.displayedProducts.forEach((row) => {
        this.removeSelectedEntry(row.pricebookEntryId, true);
      });
      this.syncSelectedRowsForTable();
      return;
    }

    // Fallback para versões/eventos sem config explícita.
    this.mergeSelectionWithDisplayedRows(selectedRows);
  }

  mergeSelectionWithDisplayedRows(selectedRows) {
    const normalizedSelectedRows = selectedRows
      .map((product) => this.normalizeProductRow(product))
      .filter((product) => !!product.pricebookEntryId);
    const displayedById = new Map(
      this.displayedProducts
        .map((product) => this.normalizeProductRow(product))
        .filter((product) => !!product.pricebookEntryId)
        .map((product) => [product.pricebookEntryId, product])
    );
    const selectedRowsById = new Map(
      normalizedSelectedRows.map((product) => [
        product.pricebookEntryId,
        product
      ])
    );

    const nextSelectionById = { ...this.selectedEntriesById };
    const nextSelectionOrder = [...this.selectedEntryOrder];

    displayedById.forEach((_, entryId) => {
      if (!selectedRowsById.has(entryId) && nextSelectionById[entryId]) {
        delete nextSelectionById[entryId];
        const orderIndex = nextSelectionOrder.indexOf(entryId);
        if (orderIndex >= 0) {
          nextSelectionOrder.splice(orderIndex, 1);
        }
      }
    });

    selectedRowsById.forEach((row, entryId) => {
      nextSelectionById[entryId] = this.buildSelectedEntry(
        row,
        nextSelectionById[entryId]
      );
      if (!nextSelectionOrder.includes(entryId)) {
        nextSelectionOrder.push(entryId);
      }
    });

    this.selectedEntriesById = nextSelectionById;
    this.selectedEntryOrder = nextSelectionOrder;
    this.pruneInvalidSelection();

    if (this.showSelectedOnly && this.selectedCount === 0) {
      this.showSelectedOnly = false;
    }

    this.syncSelectedRowsForTable();
  }

  upsertSelectedEntry(row) {
    const entryId = this.resolveEntryId(row);
    if (!entryId) {
      return;
    }

    const nextSelectionById = { ...this.selectedEntriesById };
    const nextSelectionOrder = [...this.selectedEntryOrder];

    nextSelectionById[entryId] = this.buildSelectedEntry(
      row,
      nextSelectionById[entryId]
    );

    if (!nextSelectionOrder.includes(entryId)) {
      nextSelectionOrder.push(entryId);
    }

    this.selectedEntriesById = nextSelectionById;
    this.selectedEntryOrder = nextSelectionOrder;
    this.pruneInvalidSelection();
    this.syncSelectedRowsForTable();
  }

  buildSelectedEntry(row, existingEntry) {
    const entryId = this.resolveEntryId(row);
    if (!entryId) {
      return null;
    }
    const quantityValue = existingEntry?.quantity ?? "1,00";
    const quantityNumber = this.parseDecimal(quantityValue) ?? 1;
    const baseUnitPrice = row.unitPrice;
    const lineTotal = this.calculateLineTotal(baseUnitPrice, quantityNumber);

    return {
      ...existingEntry,
      pricebookEntryId: entryId,
      product2Id: row.product2Id,
      name: row.name,
      productCode: row.productCode,
      externalId: row.externalId,
      family: row.family,
      description: row.description,
      unitPrice: baseUnitPrice,
      quantity: quantityValue,
      salesPrice: this.formatDecimalInput(lineTotal, 2),
      serviceDate: existingEntry?.serviceDate ?? "",
      lineDescription: existingEntry?.lineDescription ?? row.description ?? ""
    };
  }

  syncSelectedRowsForTable() {
    const displayedIds = this.displayedProducts.map((product) =>
      this.resolveEntryId(product)
    );
    const validDisplayedIds = displayedIds.filter(Boolean);

    if (this.showSelectedOnly) {
      this.selectedRowIds = validDisplayedIds;
      return;
    }

    const selectedIds = new Set(this.selectedEntryOrder);
    this.selectedRowIds = validDisplayedIds.filter((entryId) =>
      selectedIds.has(entryId)
    );
  }

  handleNextStep() {
    if (!this.hasSelectedProducts) {
      this.showToast("Aviso", "Selecione ao menos um produto.", "warning");
      return;
    }

    this.currentStep = "quantity";
  }

  handleBackStep() {
    this.currentStep = "selection";
  }

  handleEditorInputChange(event) {
    const entryId = event.target.dataset.entryId;
    const fieldName = event.target.dataset.field;
    const value = event.detail?.value ?? event.target?.value ?? "";

    if (!entryId || !fieldName || !this.selectedEntriesById[entryId]) {
      return;
    }

    const nextSelectionById = { ...this.selectedEntriesById };
    const nextEntry = {
      ...nextSelectionById[entryId],
      [fieldName]: value
    };

    if (fieldName === "quantity") {
      const quantity = this.parseDecimal(value);
      const baseUnitPrice = nextEntry.unitPrice;
      const lineTotal = this.calculateLineTotal(baseUnitPrice, quantity);
      nextEntry.salesPrice = this.formatDecimalInput(lineTotal, 2);
    }

    nextSelectionById[entryId] = nextEntry;

    this.selectedEntriesById = nextSelectionById;
  }

  handleRemoveSelectedItem(event) {
    const entryId = event.currentTarget?.dataset?.entryId;
    if (!entryId) {
      return;
    }

    this.removeSelectedEntry(entryId);
  }

  removeSelectedEntry(entryId, skipSync = false) {
    if (!this.selectedEntriesById[entryId]) {
      return;
    }

    const nextSelectionById = { ...this.selectedEntriesById };
    delete nextSelectionById[entryId];

    const nextSelectionOrder = this.selectedEntryOrder.filter(
      (id) => id !== entryId
    );

    this.selectedEntriesById = nextSelectionById;
    this.selectedEntryOrder = nextSelectionOrder;
    this.pruneInvalidSelection();

    if (this.selectedCount === 0) {
      this.showSelectedOnly = false;
      this.currentStep = "selection";
    }

    if (!skipSync) {
      this.syncSelectedRowsForTable();
    }
  }

  async handleAddProducts() {
    if (this.isAddDisabled) {
      return;
    }

    this.pruneInvalidSelection();

    const validEntries = this.selectedEntriesList.filter(
      (entry) => !!this.resolveEntryId(entry)
    );
    if (validEntries.length === 0) {
      this.showToast(
        "Aviso",
        "Selecione ao menos um produto válido.",
        "warning"
      );
      return;
    }

    const validationError = this.validateBeforeSave();
    if (validationError) {
      this.showToast("Aviso", validationError, "warning");
      return;
    }

    const selectedItems = validEntries.reduce((items, entry) => {
      const entryId = this.resolveEntryId(entry);
      if (!entryId) {
        return items;
      }

      items.push({
        pricebookEntryId: entryId,
        quantity: this.parseDecimal(entry.quantity),
        unitPrice: entry.unitPrice,
        serviceDate: entry.serviceDate || null,
        lineDescription: entry.lineDescription || null
      });
      return items;
    }, []);

    this.isSubmitting = true;
    try {
      const results = await addProducts({
        opportunityId: this.recordId,
        selectedItems
      });

      this.feedbackItems = (results || []).map((result) => ({
        ...result,
        rowClass: result.success
          ? "feedback-item success"
          : "feedback-item error",
        iconName: result.success ? "utility:success" : "utility:error"
      }));

      const successCount = this.feedbackItems.filter(
        (item) => item.success
      ).length;
      const errorCount = this.feedbackItems.length - successCount;

      const summaryMessage =
        errorCount > 0
          ? `${successCount} item(ns) incluído(s) e ${errorCount} com erro.`
          : `${successCount} item(ns) incluído(s) com sucesso.`;

      this.showToast(
        errorCount > 0 ? "Concluído com ressalvas" : "Sucesso",
        summaryMessage,
        errorCount > 0 ? "warning" : "success"
      );

      const successEntryIds = new Set(
        this.feedbackItems
          .filter((item) => item.success && item.pricebookEntryId)
          .map((item) => item.pricebookEntryId)
      );
      if (!successEntryIds.isEmpty()) {
        this.removeEntriesById(successEntryIds);
      }

      if (this.selectedCount === 0) {
        this.currentStep = "selection";
      } else {
        this.currentStep = "quantity";
      }

      this.dispatchEvent(
        new CustomEvent("added", {
          detail: {
            successCount,
            errorCount
          }
        })
      );

      if (successCount > 0) {
        await this.fetchProducts(false, this.offset);
      }
    } catch (error) {
      this.showToast("Erro", this.reduceError(error), "error");
    } finally {
      this.isSubmitting = false;
    }
  }

  validateBeforeSave() {
    for (const entry of this.selectedEntriesList) {
      const quantity = this.parseDecimal(entry.quantity);
      if (quantity === null || quantity <= 0) {
        return `Quantidade inválida para o produto ${entry.name}.`;
      }
    }

    return null;
  }

  handleCancel() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  clearSelection() {
    this.selectedEntriesById = {};
    this.selectedEntryOrder = [];
    this.selectedRowIds = [];
    this.showSelectedOnly = false;
  }

  removeEntriesById(entryIds) {
    if (!entryIds || entryIds.size === 0) {
      return;
    }

    const nextSelectionById = {};
    const nextSelectionOrder = [];

    this.selectedEntryOrder.forEach((entryId) => {
      const entry = this.selectedEntriesById[entryId];
      if (!entry || entryIds.has(entryId)) {
        return;
      }
      nextSelectionById[entryId] = entry;
      nextSelectionOrder.push(entryId);
    });

    this.selectedEntriesById = nextSelectionById;
    this.selectedEntryOrder = nextSelectionOrder;
    this.pruneInvalidSelection();
    this.syncSelectedRowsForTable();
  }

  pruneInvalidSelection() {
    const nextSelectionById = {};
    const nextSelectionOrder = [];

    this.selectedEntryOrder.forEach((entryId) => {
      if (!entryId) {
        return;
      }
      const entry = this.selectedEntriesById[entryId];
      if (!entry || !this.isSalesforceId(entry.pricebookEntryId)) {
        return;
      }
      nextSelectionById[entryId] = entry;
      nextSelectionOrder.push(entryId);
    });

    this.selectedEntriesById = nextSelectionById;
    this.selectedEntryOrder = nextSelectionOrder;
  }

  resolveEntryId(row) {
    if (!row) {
      return null;
    }
    return this.normalizeEntryId(row.pricebookEntryId || row.Id || row.id);
  }

  normalizeEntryId(entryId) {
    if (!entryId) {
      return null;
    }
    const normalizedId = String(entryId).trim();
    return this.isSalesforceId(normalizedId) ? normalizedId : null;
  }

  isSalesforceId(value) {
    return !!value && SALESFORCE_ID_REGEX.test(String(value).trim());
  }

  normalizeProductRow(item) {
    if (!item) {
      return item;
    }
    const normalizedEntryId = this.normalizeEntryId(
      item.pricebookEntryId || item.Id || item.id
    );
    return {
      ...item,
      pricebookEntryId: normalizedEntryId
    };
  }

  normalizeSearchText(rawValue) {
    if (!rawValue) {
      return "";
    }
    return String(rawValue).trim().toLowerCase();
  }

  matchesSearch(product, normalizedSearch) {
    const searchTargets = [
      product?.name,
      product?.productCode,
      product?.externalId,
      product?.description
    ];

    return searchTargets.some((value) =>
      String(value || "")
        .toLowerCase()
        .includes(normalizedSearch)
    );
  }

  parseDecimal(rawValue) {
    if (rawValue === null || rawValue === undefined || rawValue === "") {
      return null;
    }

    if (typeof rawValue === "number") {
      return Number.isNaN(rawValue) ? null : rawValue;
    }

    let normalizedValue = String(rawValue).trim();
    if (!normalizedValue) {
      return null;
    }

    normalizedValue = normalizedValue.replace(/\s/g, "");
    const commaCount = (normalizedValue.match(/,/g) || []).length;
    const dotCount = (normalizedValue.match(/\./g) || []).length;

    if (commaCount > 0 && dotCount > 0) {
      const lastComma = normalizedValue.lastIndexOf(",");
      const lastDot = normalizedValue.lastIndexOf(".");
      const decimalSeparator = lastComma > lastDot ? "," : ".";
      const decimalIndex = normalizedValue.lastIndexOf(decimalSeparator);
      const integerPart = normalizedValue
        .substring(0, decimalIndex)
        .replace(/[.,]/g, "");
      const fractionalPart = normalizedValue
        .substring(decimalIndex + 1)
        .replace(/[.,]/g, "");
      normalizedValue = `${integerPart}.${fractionalPart}`;
    } else if (commaCount > 0) {
      normalizedValue =
        commaCount > 1
          ? normalizedValue.replace(/,/g, "")
          : normalizedValue.replace(",", ".");
    } else if (dotCount > 1) {
      normalizedValue = normalizedValue.replace(/\./g, "");
    }

    const parsedValue = Number(normalizedValue);
    return Number.isNaN(parsedValue) ? null : parsedValue;
  }

  formatDecimalInput(rawValue, scale) {
    const parsedValue = this.parseDecimal(rawValue);
    if (parsedValue === null) {
      return "";
    }

    return new Intl.NumberFormat("pt-BR", {
      minimumFractionDigits: scale,
      maximumFractionDigits: scale
    }).format(parsedValue);
  }

  calculateLineTotal(baseUnitPrice, quantity) {
    if (
      baseUnitPrice === null ||
      baseUnitPrice === undefined ||
      quantity === null ||
      quantity === undefined ||
      quantity <= 0
    ) {
      return null;
    }

    return baseUnitPrice * quantity;
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

  reduceError(error) {
    if (!error) {
      return "Erro inesperado.";
    }
    if (Array.isArray(error.body)) {
      return error.body.map((item) => item.message).join(", ");
    }
    if (error.body?.message) {
      return error.body.message;
    }
    return error.message || "Erro inesperado.";
  }
}
