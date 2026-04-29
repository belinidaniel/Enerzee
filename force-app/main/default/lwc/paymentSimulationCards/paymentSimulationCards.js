import { LightningElement, api, wire } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import { RefreshEvent } from "lightning/refresh";
import { refreshApex } from "@salesforce/apex";
import { getFieldValue, getRecord } from "lightning/uiRecordApi";
import STAGE_NAME_FIELD from "@salesforce/schema/Opportunity.StageName";
import getSimulationCards from "@salesforce/apex/PaymentSimulationCardController.getSimulationCards";
import saveSimulationSelection from "@salesforce/apex/PaymentSimulationCardController.saveSimulationSelection";
import createManualSimulation from "@salesforce/apex/PaymentSimulationCardController.createManualSimulation";
import loadProposalData from "@salesforce/apex/ProposalConsoleController.loadProposalData";
import sendProposal from "@salesforce/apex/ProposalConsoleController.sendProposal";

function calculatePMT(principal, interestRatePct, anticipationRatePct, n) {
  if (!principal || !n || n <= 0) return null;
  const antecipacao = principal * ((anticipationRatePct || 0) / 100);
  const pv = principal + antecipacao;
  if (!interestRatePct || interestRatePct === 0 || n === 1) {
    return Math.round((pv / n) * 100) / 100;
  }
  const i = interestRatePct / 100;
  const factor = 1 - Math.pow(1 + i, -n);
  return Math.round(((pv * i) / factor) * 100) / 100;
}

function formatBRL(value) {
  const num = Number(value);
  if (isNaN(num)) return "R$ 0,00";
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
    minimumFractionDigits: 2
  }).format(num);
}

const OPPORTUNITY_FIELDS = [STAGE_NAME_FIELD];
const READJUSTMENT_STAGE = "Readequação de Proposta";
const CREDIT_ANALYSIS_STAGE = "Análise de Crédito";
const PAYMENT_TYPE_LABELS = {
  Financing: "Financiamento",
  Rental: "Aluguel Solar",
  Card: "Cartão de Crédito",
  Pix: "PIX Via Link",
  Boleto: "Boleto",
  Negociacao: "Negociação"
};

const FORMA_PAGAMENTO_OPTIONS = [
  { label: "Cartão de crédito", value: "REC CARTAO", paymentType: "Card" },
  {
    label: "Financiamento",
    value: "REC FINANCIAMEN",
    paymentType: "Financing"
  },
  { label: "Boleto", value: "R001", paymentType: "Boleto" },
  { label: "Transferencia PIX", value: "R0002", paymentType: "Pix" },
  { label: "Negociação", value: "Negociação", paymentType: "Negociacao" }
];

export default class PaymentSimulationCards extends LightningElement {
  @api recordId;

  _wiredResult;
  _wiredProposalData;
  cards = [];
  opportunityRecord;
  pendingSimulationId = null;
  isSaving = false;
  isSimulationModalOpen = false;
  isCreatingSimulation = false;
  baseSimulationId = null;
  draftInstallmentCount = null;
  draftInstallmentAmount = null;
  draftProposalLabel = "";
  draftPaymentType = "";
  draftInterestRate = null;
  draftAnticipationRate = null;
  draftPrincipalValue = null;
  defaultTemplateId = null;
  isManualMode = false;
  manualFormaPagamento = null;

  @wire(getRecord, { recordId: "$recordId", fields: OPPORTUNITY_FIELDS })
  wiredOpportunity({ data }) {
    this.opportunityRecord = data;
  }

  @wire(loadProposalData, { opportunityId: "$recordId" })
  wiredProposalData(result) {
    this._wiredProposalData = result;
    if (result.data) {
      this.defaultTemplateId = result.data.defaultTemplateId || null;
    } else if (result.error) {
      this.defaultTemplateId = null;
    }
  }

  @wire(getSimulationCards, { opportunityId: "$recordId" })
  wiredCards(result) {
    this._wiredResult = result;
    if (result.data) {
      this.cards = result.data;
    } else if (result.error) {
      this.dispatchEvent(
        new ShowToastEvent({
          title: "Erro ao carregar simulações",
          message: result.error.body?.message,
          variant: "error"
        })
      );
    }
  }

  get hasCards() {
    return this.cards && this.cards.length > 0;
  }

  get hasPendingSelection() {
    return !!this.pendingSimulationId;
  }

  get canSimulateProposal() {
    return (
      this.hasCards &&
      [READJUSTMENT_STAGE, CREDIT_ANALYSIS_STAGE].includes(this.stageName)
    );
  }

  get stageName() {
    return getFieldValue(this.opportunityRecord, STAGE_NAME_FIELD);
  }

  get isCardModal() {
    return this.draftPaymentType === "Card";
  }

  get cardInstallmentOptions() {
    if (!this.isCardModal || !this.draftPrincipalValue) return [];
    const options = [];
    for (let n = 1; n <= 12; n++) {
      const pmt = calculatePMT(
        this.draftPrincipalValue,
        this.draftInterestRate,
        this.draftAnticipationRate,
        n
      );
      if (pmt == null) continue;
      options.push({
        label: `${n}x de ${formatBRL(pmt)}`,
        value: String(n)
      });
    }
    return options;
  }

  get formaPagamentoOptions() {
    return FORMA_PAGAMENTO_OPTIONS;
  }

  get simulationModalSaveDisabled() {
    if (this.isManualMode) {
      return (
        this.isCreatingSimulation ||
        !this.manualFormaPagamento ||
        !this.draftInstallmentCount ||
        !this.draftInstallmentAmount ||
        Number(this.draftInstallmentCount) <= 0 ||
        Number(this.draftInstallmentAmount) <= 0
      );
    }
    return (
      this.isCreatingSimulation ||
      !this.draftInstallmentCount ||
      !this.draftInstallmentAmount ||
      Number(this.draftInstallmentCount) <= 0 ||
      Number(this.draftInstallmentAmount) <= 0
    );
  }

  get simulationModalPrimaryLabel() {
    return this.isCreatingSimulation
      ? "Salvando..."
      : "Salvar e gerar proposta";
  }

  get draftPaymentTypeLabel() {
    return PAYMENT_TYPE_LABELS[this.draftPaymentType] || this.draftPaymentType;
  }

  get draftDisplayProposalLabel() {
    if (this.draftProposalLabel === "Simulação ajustada") {
      if (this.draftPaymentType === "Rental") {
        return "Aluguel";
      }
      if (this.draftPaymentType === "Financing") {
        return "Financiamento";
      }
      if (this.draftPaymentType === "Pix") {
        return "PIX";
      }
    }
    return this.draftProposalLabel;
  }

  handleOptionSelect(event) {
    const simulationId = event.detail.simulationId;
    const currentSelectedId = this._getCurrentSelectedSimulationId();
    if (simulationId === currentSelectedId) {
      return;
    }
    this.pendingSimulationId = simulationId;
  }

  handleCancel() {
    this.pendingSimulationId = null;
  }

  handleSave() {
    if (!this.pendingSimulationId || this.isSaving) {
      return;
    }
    this.isSaving = true;
    saveSimulationSelection({
      opportunityId: this.recordId,
      simulationId: this.pendingSimulationId
    })
      .then(() => refreshApex(this._wiredResult))
      .then(() => {
        this.pendingSimulationId = null;
        this.isSaving = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Simulação salva",
            message: "A simulação selecionada foi atualizada.",
            variant: "success"
          })
        );
      })
      .catch((err) => {
        this.isSaving = false;
        this.dispatchEvent(
          new ShowToastEvent({
            title: "Erro ao salvar simulação",
            message: err.body?.message,
            variant: "error"
          })
        );
      });
  }

  handleOpenSimulationModal() {
    const selectedOption = this._getSelectedOrFallbackOption();
    if (!selectedOption) {
      this._showToast(
        "Erro ao abrir simulador",
        "Nenhuma simulação base foi encontrada para esta oportunidade.",
        "error"
      );
      return;
    }

    this.pendingSimulationId = null;
    this.baseSimulationId = selectedOption.id;
    this.draftProposalLabel = selectedOption.proposalLabel;
    this.draftPaymentType = selectedOption.paymentType;
    this.draftInterestRate = selectedOption.interestRate || null;
    this.draftAnticipationRate = selectedOption.anticipationRate || null;
    this.draftPrincipalValue = selectedOption.principalValue || null;
    // Para cartão: pré-seleciona a opção salva; combobox usa string
    this.draftInstallmentCount =
      selectedOption.paymentType === "Card"
        ? String(selectedOption.installmentCount || 12)
        : selectedOption.installmentCount;
    this.draftInstallmentAmount = selectedOption.installmentAmount;
    this.isSimulationModalOpen = true;
  }

  handleCloseSimulationModal(forceClose = false) {
    if (this.isCreatingSimulation && !forceClose) {
      return;
    }

    this.isSimulationModalOpen = false;
    this.baseSimulationId = null;
    this.draftInstallmentCount = null;
    this.draftInstallmentAmount = null;
    this.draftProposalLabel = "";
    this.draftPaymentType = "";
    this.draftInterestRate = null;
    this.draftAnticipationRate = null;
    this.draftPrincipalValue = null;
    this.isManualMode = false;
    this.manualFormaPagamento = null;
  }

  handleToggleManualMode() {
    this.isManualMode = !this.isManualMode;
    this.draftInstallmentCount = null;
    this.draftInstallmentAmount = null;
    if (!this.isManualMode) {
      this.manualFormaPagamento = null;
    }
  }

  handleManualFormaPagamentoChange(event) {
    this.manualFormaPagamento = event.detail.value;
    const option = FORMA_PAGAMENTO_OPTIONS.find(
      (o) => o.value === this.manualFormaPagamento
    );
    if (option) {
      this.draftPaymentType = option.paymentType;
      this.draftProposalLabel = option.label;
    }
    this.draftInstallmentCount = null;
    this.draftInstallmentAmount = null;
  }

  handleCardInstallmentChange(event) {
    const n = Number(event.detail.value);
    const pmt = calculatePMT(
      this.draftPrincipalValue,
      this.draftInterestRate,
      this.draftAnticipationRate,
      n
    );
    this.draftInstallmentCount = String(n); // combobox precisa de string
    this.draftInstallmentAmount = pmt;
  }

  handleInstallmentCountChange(event) {
    this.draftInstallmentCount = event.detail.value;
  }

  handleInstallmentAmountChange(event) {
    this.draftInstallmentAmount = event.detail.value;
  }

  async handleSaveSimulationProposal() {
    if (this.simulationModalSaveDisabled) {
      return;
    }

    this.isCreatingSimulation = true;
    try {
      const saveResult = await createManualSimulation({
        opportunityId: this.recordId,
        baseSimulationId: this.baseSimulationId,
        installmentCount: Number(this.draftInstallmentCount),
        installmentAmount: Number(this.draftInstallmentAmount),
        paymentType: this.isManualMode ? this.draftPaymentType : null
      });

      let toastTitle = "Simulação atualizada";
      let toastVariant = "success";
      let toastMessage = saveResult?.createdNewSimulation
        ? "Nova simulação criada e selecionada com sucesso."
        : "A simulação existente foi mantida como selecionada.";

      if (this.defaultTemplateId) {
        try {
          const proposalResult = await sendProposal({
            opportunityId: this.recordId,
            coverId: this.defaultTemplateId
          });
          toastMessage =
            proposalResult?.message ||
            "Simulação salva e proposta gerada novamente.";
          if (proposalResult?.success === false) {
            toastTitle = "Simulação salva com alerta";
            toastVariant = "warning";
          }
        } catch (proposalError) {
          toastTitle = "Simulação salva com alerta";
          toastVariant = "warning";
          toastMessage =
            "A simulação foi salva, mas não foi possível gerar a proposta: " +
            this._reduceError(proposalError);
        }
      } else {
        toastTitle = "Simulação salva";
        toastVariant = "warning";
        toastMessage =
          "A simulação foi salva, mas nenhum modelo padrão de proposta foi encontrado para regenerar o PDF.";
      }

      this.pendingSimulationId = null;
      this.handleCloseSimulationModal(true);

      await refreshApex(this._wiredResult);

      if (this._wiredProposalData) {
        await refreshApex(this._wiredProposalData);
      }
      this.dispatchEvent(new RefreshEvent());
      this._showToast(toastTitle, toastMessage, toastVariant);
    } catch (error) {
      this._showToast(
        "Erro ao simular proposta",
        this._reduceError(error),
        "error"
      );
    } finally {
      this.isCreatingSimulation = false;
    }
  }

  _getCurrentSelectedSimulationId() {
    if (!this.cards) return null;
    for (const card of this.cards) {
      if (card.selectedSimulationId) return card.selectedSimulationId;
    }
    return null;
  }

  _getSelectedOrFallbackOption() {
    if (!this.cards?.length) {
      return null;
    }

    const currentSelectedId = this._getCurrentSelectedSimulationId();
    let fallbackOption = null;
    for (const card of this.cards) {
      for (const option of card.options || []) {
        const decoratedOption = {
          ...option,
          proposalLabel:
            card.isManual && card.paymentType === "Rental"
              ? "Aluguel"
              : card.isManual && card.paymentType === "Financing"
                ? "Financiamento"
                : card.isManual && card.paymentType === "Pix"
                  ? "PIX"
                  : card.proposalLabel,
          paymentType: card.paymentType,
          anticipationRate: card.anticipationRate,
          principalValue: card.principalValue
        };
        if (!fallbackOption) {
          fallbackOption = decoratedOption;
        }
        if (currentSelectedId && option.id === currentSelectedId) {
          return decoratedOption;
        }
      }
    }

    return fallbackOption;
  }

  _showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  _reduceError(error) {
    if (Array.isArray(error?.body)) {
      return error.body.map((item) => item.message).join(", ");
    }
    return error?.body?.message || error?.message || "Erro inesperado.";
  }
}
