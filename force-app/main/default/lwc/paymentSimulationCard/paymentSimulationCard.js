import { LightningElement, api } from "lwc";

const PAYMENT_TYPE_LABELS = {
  Financing: "Financiamento",
  Rental: "Aluguel Solar",
  Card: "Cartão de Crédito",
  Pix: "PIX Via Link"
};

function formatBRL(value) {
  const num = Number(value);
  if (isNaN(num)) return "R$ 0,00";
  try {
    return new Intl.NumberFormat("pt-BR", {
      style: "currency",
      currency: "BRL",
      minimumFractionDigits: 2
    }).format(num);
  } catch {
    return (
      "R$ " +
      num
        .toFixed(2)
        .replace(".", ",")
        .replace(/\B(?=(\d{3})+(?!\d))/g, ".")
    );
  }
}

export default class PaymentSimulationCard extends LightningElement {
  @api card;
  @api pendingSimulationId;

  get cardTitle() {
    if (this.isManualCard) {
      if (this.card?.paymentType === "Rental") {
        return "ALUGUEL";
      }
      if (this.card?.paymentType === "Financing") {
        return "FINANCIAMENTO";
      }
      if (this.card?.paymentType === "Pix") {
        return "PIX";
      }
    }
    return this.card?.proposalLabel || "";
  }

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

  get isManualRentalCard() {
    return this.isManualCard && this.card?.paymentType === "Rental";
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

    return `${selectedOption.installmentCount}x ${formatBRL(
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
        formattedAmount: formatBRL(opt.installmentAmount || 0),
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
