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
    const classes = ["simulation-card"];
    if (this.isManualCard) {
      classes.push("simulation-card--manual");
    }
    const hasApiSelection = !!this.card?.selectedSimulationId;
    if (hasApiSelection && !this.card?.hasSelected) {
      classes.push("simulation-card--inactive");
    }
    return classes.join(" ");
  }

  get isManualCard() {
    return this.card?.isManual === true;
  }

  get paymentTypeLabel() {
    if (!this.card?.paymentType) return "";
    return PAYMENT_TYPE_LABELS[this.card.paymentType] || this.card.paymentType;
  }

  get hasSelectedOptionSummary() {
    return !!this.selectedOptionSummary;
  }

  get selectedOptionSummary() {
    const selectedOption = (this.card?.options || []).find(
      (option) =>
        option.id === this.card?.selectedSimulationId ||
        option.selected === true
    );
    if (!selectedOption) {
      return "";
    }

    return `${selectedOption.installmentCount}x ${BRL_FORMATTER.format(
      selectedOption.installmentAmount || 0
    )}`;
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
