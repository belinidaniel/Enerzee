/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-14-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalContextResolver {
  public class Context {
    public Opportunity opportunity;
    public ProposalCover__c cover;
    public Boolean isPromotional;
    public String scenario;
    public String paymentType;
    public String coverKey;
  }

  public static Boolean determineIsPromotional(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return false;
    }

    return String.isNotBlank(opportunityRecord.TipoKitPromocional__c);
  }

  @TestVisible
  static Boolean shouldShowFinancingInInitial(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return false;
    }

    Decimal amount = opportunityRecord.ValorTotalProposta__c != null &&
      opportunityRecord.ValorTotalProposta__c > 0
      ? opportunityRecord.ValorTotalProposta__c
      : opportunityRecord.Amount;

    String cnpj = opportunityRecord.Account != null
      ? opportunityRecord.Account.CNPJ__c
      : null;

    Boolean eligibleByValue = PaymentSimulationBO.isRentalEligible(
      amount,
      cnpj,
      opportunityRecord.TipoKitPromocional__c
    );

    // Card de aluguel so aparece se elegivel por valor E existir simulacao RENTAL real.
    // Sem isso o PDF renderiza o card "EZEE SOLAR - ALUGUEL" vazio.
    return !(eligibleByValue && hasRentalSimulation(opportunityRecord.Id));
  }

  @TestVisible
  static Boolean hasRentalSimulation(Id opportunityId) {
    if (opportunityId == null) {
      return false;
    }

    for (
      PaymentSimulation__c simulationRecord : PaymentSimulationDAO.getByOpportunityIds(
        new Set<Id>{ opportunityId }
      )
    ) {
      if ('RENTAL'.equalsIgnoreCase(simulationRecord.PaymentType__c)) {
        return true;
      }
    }
    return false;
  }

  public static Context resolve(Id opportunityId, Id coverId) {
    if (opportunityId == null || coverId == null) {
      throw new ProposalGenerationService.ProposalGenerationException(
        'O registro da oportunidade e a capa da proposta sao obrigatorios.'
      );
    }

    Opportunity opportunityRecord = [
      SELECT
        Id,
        Name,
        CreatedDate,
        AccountId,
        Account.Name,
        Account.CNPJ__c,
        Numeroproposta__c,
        GrupoTarifario__c,
        StageName,
        RecordTypeId,
        RecordType.Name,
        RecordType.DeveloperName,
        PropostaAlterada__c,
        Parceiro__c,
        Parceiro__r.Name,
        ViabilityStudyFinished__c,
        TipoKitPromocional__c,
        DescricaoBateria__c,
        ValorTotalProposta__c,
        Amount,
        SelectedSimulation__c,
        SelectedSimulation__r.PaymentType__c,
        isPromotional__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];

    ProposalCover__c coverRecord = [
      SELECT
        Id,
        Name,
        Template__c,
        TemplateUrl__c,
        IsActive__c,
        IntegrationKey__c,
        isPromotional__c
      FROM ProposalCover__c
      WHERE Id = :coverId
      LIMIT 1
    ];

    if (coverRecord.IsActive__c != true) {
      throw new ProposalGenerationService.ProposalGenerationException(
        'A capa de proposta selecionada esta inativa.'
      );
    }

    Context context = new Context();
    context.opportunity = opportunityRecord;
    context.cover = coverRecord;
    context.coverKey = ProposalCoverRoutingService.resolveCoverKey(coverRecord);
    context.paymentType = opportunityRecord.SelectedSimulation__r != null
      ? opportunityRecord.SelectedSimulation__r.PaymentType__c
      : null;

    if (opportunityRecord.SelectedSimulation__c != null) {
      context.scenario = ProposalConfigurationService.SCENARIO_PAYMENT_SELECTED;
    } else if (shouldShowFinancingInInitial(opportunityRecord)) {
      context.scenario = ProposalConfigurationService.SCENARIO_INITIAL_FINANCING;
    } else {
      context.scenario = ProposalConfigurationService.SCENARIO_INITIAL;
    }

    context.isPromotional = determineIsPromotional(opportunityRecord);

    return context;
  }
}
