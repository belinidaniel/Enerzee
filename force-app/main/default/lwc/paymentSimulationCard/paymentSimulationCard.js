import { LightningElement, api } from "lwc";

const PAYMENT_TYPE_LABELS = {
  Financing: "Financiamento",
  Rental: "Aluguel Solar"
};

const BRL_FORMATTER = new Intl.NumberFormat("pt-BR", {
  style: "currency",
  currency: "BRL",
  minimumFractionDigits: 2
});

export default class PaymentSimulationCard extends LightningElement {
  @api card;
  @api pendingSimulationId;

  get cardClass() {
    const hasApiSelection = !!this.card?.selectedSimulationId;
    if (!hasApiSelection) {
      return "simulation-card";
    }
    return this.card?.hasSelected
      ? "simulation-card"
      : "simulation-card simulation-card--inactive";
  }

  get paymentTypeLabel() {
    if (!this.card?.paymentType) return "";
    return PAYMENT_TYPE_LABELS[this.card.paymentType] || this.card.paymentType;
  }

  get processedOptions() {
    if (!this.card?.options) return [];
    return this.card.options.map((opt) => {
      let optionClass = "option-btn";
      if (this.pendingSimulationId && opt.id === this.pendingSimulationId) {
        optionClass = "option-btn option-btn--pending";
      } else if (!this.pendingSimulationId && opt.selected) {
        optionClass = "option-btn option-btn--active";
      }
      return {
        id: opt.id,
        installmentCount: opt.installmentCount,
        formattedAmount: BRL_FORMATTER.format(opt.installmentAmount || 0),
        optionClass,
        tooltip: opt.name
      };
    });
  }

  handleOptionClick(event) {
    const simulationId = event.currentTarget.dataset.id;
    this.dispatchEvent(
      new CustomEvent("optionselect", {
        bubbles: true,
        composed: true,
        detail: { simulationId }
      })
    );
  }
}
