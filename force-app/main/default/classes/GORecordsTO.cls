public class GORecordsTO {
    
    // - ProposalService
    public String   IdSalesForce;
    public Integer  Status;
    public Integer  SubStatus;
    public String   Obs;

    // - IntegracaoNivelloProjetos
    public String   StatusProjeto;
    public String   Category;
    public String   CodigoRegistroProjetoSF;
    public String   NumeroProjeto;
    public String   NomeProjeto;
    public String   DataInicioContrato;
    public Integer  PrazoContrato;
    public String   DataContagemdoPrazo;
    public String   DataTermino;
    public Integer  DiasFaltantes;
    public String   PotenciaDoSistema;
    public String   Projetista;
    public String   GestordaObra;
    public String   DataUltimaModificacao;

    // - Pagamento
    public String   ReceivingDate;
    public Boolean  Refused;
    public String   RefusedReason;

    // - IntegracaoNivelloAprovacaoDesconto
    public Integer  StatusDiscount;
    public String   JustifyObs;
    public String   discountReturnApprovalComments;
    public Decimal  ReturnRequestDiscount;

    // - IntegracaoNivelloContrato / SAP / IntegracaoNivelloProposta
    public Boolean  Approved;
    public string   Contract;
    public string   Adequacy;

    // - IntegracaoNivelloContrato
    public String   URL;

    // - IntegracaoNivelloDataVisitaTecnica
    public String   TechnicalVisitDate;

    // - IntegracaoNivelloAnaliseVisitaTecnica
    public String study;
    public String reason;

    // - IntegracaoNivelloProposta
    public String   UrlSimulation;

    // - ValorDaProposta
    public Decimal  Value;

    // - IntegracaoNivelloValorTotalProposta
    public Decimal  AdditionalCost;

    // - DetalhesDoProcessoFinanceiro
    public String   FinancingProcessDetail;

    public Datetime AppointmentDateTime;

}