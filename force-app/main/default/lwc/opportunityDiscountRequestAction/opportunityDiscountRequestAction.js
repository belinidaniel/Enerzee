import { LightningElement, api } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { CloseActionScreenEvent } from "lightning/actions";
import getContext from "@salesforce/apex/OpportunityDiscountRequestController.getContext";
import submitDiscountRequest from "@salesforce/apex/OpportunityDiscountRequestController.submitDiscountRequest";

const ALLOWED_STAGES_LABEL = "Elaboração de proposta ou Proposta Gerada";

export default class OpportunityDiscountRequestAction extends LightningElement {
  _recordId;

  isLoading = false;
  isContextLoaded = false;
  isSubmitting = false;
  context = {
    stageName: "-",
    originalProposalValue: null,
    hasLatestProposal: false,
    isEligibleStage: null
  };
  discountValue;
  discountPercent;
  comments = "";

  @api
  get recordId() {
    return this._recordId;
  }

  set recordId(value) {
    this._recordId = value;
    if (value && !this.isContextLoaded && !this.isLoading) {
      this.loadContext();
    }
  }

  connectedCallback() {
    if (this.recordId) {
      this.loadContext();
    }
  }

  get isStageBlocked() {
    return this.context && this.context.isEligibleStage === false;
  }

  get stageNameLabel() {
    return this.context?.stageName || "-";
  }

  get allowedStagesLabel() {
    return ALLOWED_STAGES_LABEL;
  }

  get hasLatestProposal() {
    return this.context?.hasLatestProposal === true;
  }

  get proposalStatusLabel() {
    return this.hasLatestProposal ? "Disponível" : "Não encontrada";
  }

  get canSubmit() {
    return (
      this.isContextLoaded &&
      !this.isLoading &&
      !this.isSubmitting &&
      !this.isStageBlocked &&
      this.hasLatestProposal
    );
  }

  get isSubmitDisabled() {
    return !this.canSubmit;
  }

  get submitLabel() {
    return this.isSubmitting ? "Enviando..." : "Enviar solicitação";
  }

  get hasOriginalValue() {
    return (
      this.context &&
      this.context.originalProposalValue !== null &&
      this.context.originalProposalValue !== undefined
    );
  }

  get formattedOriginalValue() {
    if (!this.hasOriginalValue) {
      return "-";
    }
    return this.formatCurrency(this.context.originalProposalValue);
  }

  get requestDiscountPreview() {
    const baseValue = this.toNumber(this.context?.originalProposalValue);
    const valueAmount = this.toNumber(this.discountValue);
    const valuePercent = this.toNumber(this.discountPercent);

    if (valueAmount !== null && valueAmount > 0) {
      return this.round(valueAmount, 2);
    }

    if (
      valuePercent !== null &&
      valuePercent > 0 &&
      baseValue !== null &&
      baseValue > 0
    ) {
      return this.round((baseValue * valuePercent) / 100, 2);
    }

    return null;
  }

  get formattedRequestDiscountPreview() {
    if (this.requestDiscountPreview === null) {
      return "-";
    }
    return this.formatCurrency(this.requestDiscountPreview);
  }

  async loadContext() {
    if (!this.recordId || this.isLoading) {
      return;
    }

    this.isLoading = true;
    try {
      const contextResponse = await getContext({
        opportunityId: this.recordId
      });
      this.context = { ...this.context, ...contextResponse };
      this.isContextLoaded = true;
    } catch (error) {
      this.isContextLoaded = false;
      this.showToast("Erro", this.reduceError(error), "error");
    } finally {
      this.isLoading = false;
    }
  }

  handleInputChange(event) {
    const field =
      event.currentTarget?.dataset?.field || event.target?.dataset?.field;
    const value = event.detail?.value ?? event.target?.value;
    const baseValue = this.toNumber(this.context?.originalProposalValue);

    if (field === "discountValue") {
      this.discountValue = value;
      if (!this.hasValue(value)) {
        this.discountPercent = "";
        return;
      }

      const valueAmount = this.toNumber(value);
      if (valueAmount === null || baseValue === null || baseValue <= 0) {
        this.discountPercent = "";
        return;
      }

      const calculatedPercent = this.round((valueAmount / baseValue) * 100, 2);
      this.discountPercent = this.toInputString(calculatedPercent, 2);
    } else if (field === "discountPercent") {
      this.discountPercent = value;
      if (!this.hasValue(value)) {
        this.discountValue = "";
        return;
      }

      const valuePercent = this.toNumber(value);
      if (valuePercent === null || baseValue === null || baseValue <= 0) {
        this.discountValue = "";
        return;
      }

      const calculatedValue = this.round((baseValue * valuePercent) / 100, 2);
      this.discountValue = this.toInputString(calculatedValue, 2);
    } else if (field === "comments") {
      this.comments = value;
    }
  }

  handleCancel() {
    if (!this.isSubmitting) {
      this.dispatchEvent(new CloseActionScreenEvent());
    }
  }

  async handleSubmit() {
    if (!this.validateForm() || this.isSubmitting) {
      return;
    }

    this.isSubmitting = true;
    try {
      const result = await submitDiscountRequest({
        opportunityId: this.recordId,
        discountValue: this.toNumber(this.discountValue),
        discountPercent: this.toNumber(this.discountPercent),
        comments: this.comments
      });

      this.showToast(
        "Sucesso",
        result?.message || "Solicitação enviada com sucesso.",
        "success"
      );
      this.dispatchEvent(new CloseActionScreenEvent());
    } catch (error) {
      this.showToast("Erro", this.reduceError(error), "error");
    } finally {
      this.isSubmitting = false;
    }
  }

  validateForm() {
    const discountValueInput = this.template.querySelector(
      '[data-field="discountValue"]'
    );
    const discountPercentInput = this.template.querySelector(
      '[data-field="discountPercent"]'
    );

    [discountValueInput, discountPercentInput].forEach((input) => {
      if (input) {
        input.setCustomValidity("");
      }
    });

    const valueAmount = this.toNumber(this.discountValue);
    const valuePercent = this.toNumber(this.discountPercent);
    const baseValue = this.toNumber(this.context?.originalProposalValue);
    let isValid = true;

    if (
      (valueAmount === null || valueAmount <= 0) &&
      (valuePercent === null || valuePercent <= 0)
    ) {
      const message = "Informe desconto em valor (R$) e/ou porcentagem (%).";
      if (discountValueInput) {
        discountValueInput.setCustomValidity(message);
      }
      if (discountPercentInput) {
        discountPercentInput.setCustomValidity(message);
      }
      isValid = false;
    }

    if (valueAmount !== null && valueAmount <= 0 && discountValueInput) {
      discountValueInput.setCustomValidity(
        "O desconto em valor deve ser maior que zero."
      );
      isValid = false;
    }

    if (valuePercent !== null && valuePercent <= 0 && discountPercentInput) {
      discountPercentInput.setCustomValidity(
        "O desconto em porcentagem deve ser maior que zero."
      );
      isValid = false;
    }

    if (
      this.requestDiscountPreview !== null &&
      baseValue !== null &&
      this.requestDiscountPreview > baseValue
    ) {
      const message =
        "O desconto não pode ser maior que o valor original da proposta.";
      if (discountValueInput) {
        discountValueInput.setCustomValidity(message);
      }
      if (discountPercentInput) {
        discountPercentInput.setCustomValidity(message);
      }
      isValid = false;
    }

    [discountValueInput, discountPercentInput].forEach((input) => {
      if (input) {
        input.reportValidity();
      }
    });

    return isValid;
  }

  round(value, scale) {
    const factor = 10 ** scale;
    return Number(
      (Math.round((value + Number.EPSILON) * factor) / factor).toFixed(scale)
    );
  }

  toNumber(value) {
    if (value === null || value === undefined || value === "") {
      return null;
    }

    if (typeof value === "number") {
      return Number.isNaN(value) ? null : value;
    }

    let normalizedValue = String(value).trim();
    if (normalizedValue === "") {
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
      if (commaCount > 1) {
        normalizedValue = normalizedValue.replace(/,/g, "");
      } else {
        normalizedValue = normalizedValue.replace(",", ".");
      }
    } else if (dotCount > 0) {
      if (dotCount > 1) {
        normalizedValue = normalizedValue.replace(/\./g, "");
      }
    }

    const parsed = Number(normalizedValue);
    return Number.isNaN(parsed) ? null : parsed;
  }

  hasValue(value) {
    return value !== null && value !== undefined && String(value).trim() !== "";
  }

  toInputString(value, scale) {
    if (value === null || value === undefined || Number.isNaN(value)) {
      return "";
    }

    const fixed = Number(value).toFixed(scale);
    const withoutTrailingZeros = fixed.replace(/\.?0+$/, "");
    return withoutTrailingZeros.replace(".", ",");
  }

  formatCurrency(value) {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL"
    }).format(value);
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
